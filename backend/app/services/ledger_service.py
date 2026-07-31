"""Append-only ledger — the single source of truth for a project's balance.

`Project.raised_amount` is a projection, maintained here with an atomic SQL
UPDATE inside the same transaction as the ledger insert. Nothing else in
the codebase should ever write to `raised_amount` directly — see FIN-02 in
docs/Changa_Engineering_audit.md.
"""
from decimal import Decimal
from uuid import UUID

from sqlalchemy import update, select, func, case
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session

from app.core.types import ZERO
from app.models.models import Contribution, ContributionStatus, LedgerEntry, LedgerDirection, Project


def credit_contribution(db: Session, contribution: Contribution, receipt: str | None, completed_at) -> bool:
    """Credit a successful contribution to its project. Idempotent.

    Safe to call twice (or concurrently) for the same contribution: the
    unique constraint on (contribution_id, direction) makes the second
    ledger insert a no-op, and the projection update only runs once as a
    result. Returns True if this call actually applied the credit, False
    if it was already applied (a replayed or duplicated callback).
    """
    inserted = db.execute(
        pg_insert(LedgerEntry)
        .values(
            project_id=contribution.project_id,
            contribution_id=contribution.id,
            direction=LedgerDirection.CREDIT,
            amount=contribution.amount,
            currency=contribution.currency,
        )
        .on_conflict_do_nothing(constraint="uq_ledger_contribution_direction")
        .returning(LedgerEntry.id)
    ).scalar_one_or_none()

    if inserted is None:
        return False  # already credited — a replayed callback, not an error

    # Atomic SQL update, never a Python-side `project.raised_amount += x`:
    # concurrency is resolved by the database, not by hoping two callbacks
    # never interleave.
    db.execute(
        update(Project)
        .where(Project.id == contribution.project_id)
        .values(raised_amount=Project.raised_amount + contribution.amount)
    )
    db.execute(
        update(Contribution)
        .where(Contribution.id == contribution.id,
               Contribution.status.in_([ContributionStatus.PENDING, ContributionStatus.FAILED]))
        .values(status=ContributionStatus.SUCCESS,
                provider_reference=receipt,
                completed_at=completed_at)
    )
    return True


def find_ledger_divergence(db: Session) -> list[dict]:
    """Recompute every project's total from the ledger and return mismatches.

    Run this periodically (see PAY-03 for the worker tier this belongs in)
    and alert on any row returned — a non-empty result means
    `raised_amount` has drifted from the immutable trail it is supposed to
    be a projection of, which should never happen but must be detectable
    if it does.
    """
    derived = (
        select(
            Project.id,
            Project.raised_amount.label("projected"),
            func.coalesce(
                func.sum(
                    LedgerEntry.amount
                    * case((LedgerEntry.direction == LedgerDirection.REVERSAL, -1), else_=1)
                ),
                ZERO,
            ).label("derived"),
        )
        .select_from(Project)
        .outerjoin(LedgerEntry, LedgerEntry.project_id == Project.id)
        .group_by(Project.id, Project.raised_amount)
    )
    rows = db.execute(derived).all()
    return [
        {"project_id": r.id, "projected": r.projected, "derived": r.derived}
        for r in rows
        if r.projected != r.derived
    ]
