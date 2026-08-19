# Changa — Full-Stack Engineering Audit & Production-Grade Remediation Plan

*Principal Engineering Review · Production Readiness — Confidential, internal. njogubless/changa @ 5771d5c · reviewed 31 Jul 2026.*

A Flutter + FastAPI group-contribution platform moving real money over M-Pesa and Airtel Money. Assessed against the standard applied to a regulated payments platform at scale: 100k+ registered users, 5k concurrent, 50k+ payment initiations per day, peak bursts at month-end and during fundraising events.

**Verdict** — Not production-ready. Must not process live funds in current state.  
**Findings** — 28 total (11 blocking (P0) · 12 high (P1) · 5 medium (P2)).  
**Est. remediation** — 9–13 weeks (2 backend, 1 mobile, 0.5 platform engineer).

## 1. Executive summary

The codebase is a competent, well-organised prototype. Feature-first foldering on the Flutter side is clean, Riverpod is used idiomatically in places (`ref.watch(...select(...))`, `RepaintBoundary`, sliver lists, skeleton/empty/error states), the FastAPI layout separates routers, schemas, models and services, and the auth flow already implements refresh-token rotation. That is a real head start.

It is also, structurally, a prototype that has not yet been engineered for money. The audit found four categories of defect that are individually sufficient to block launch:

1. **Financial correctness.** Every monetary amount in the system is a binary `Float`. Project totals are a mutable counter incremented with an unlocked read-modify-write. There is no ledger, so no balance in the system can be independently recomputed or proved.

2. **Payment integrity.** The M-Pesa and Airtel callbacks are unauthenticated, unsigned and non-idempotent. Any party on the internet who can reach the callback URL can mint successful contributions; a legitimate provider retry double-credits.

3. **Schema truth.** `create_tables()` runs at startup while the single Alembic migration describes a schema that no longer exists (it still has `teams` and `project_members`, and none of `chamas`, `budgets`). There is no auditable schema history, and no safe path to the next deploy.

4. **Contract drift.** The mobile app calls `GET /projects`, `POST /projects`, `/projects/{id}/teams` and `/members` — none of which exist on the server. The test suite exercises the same dead endpoints, so CI would not catch it. Nothing enforces the contract.

Beyond correctness, the system has no observability at all (Sentry is a dependency but is never initialised; there are no request IDs, no metrics, no payment-funnel alerting), no rate limiting on any endpoint including login and STK-push initiation, no audit trail, and an ORM access pattern that hydrates entire relationship collections into Python to compute sums — which is survivable at 100 contributions and fatal at 100,000.

**Recommendation:** treat the payments path as a rewrite, not a patch. Sections 4 and 5 below give the exact refactor: money as `NUMERIC(14,2)`, an append-only ledger as the single source of truth, signed and idempotent callbacks, an outbox for provider calls with a reconciliation worker, and full async I/O. Everything else can proceed incrementally on top.

## 2. Scorecard against stated goals

| Goal | Now | Binding constraint |
|---|---|---|
| Maintainability | 6 / 10 | Good foldering; no domain layer, no service layer on the backend, business rules inline in routers and notifiers. |
| Scalability | 2 / 10 | Blocking sync ORM inside `async def`; collection-hydrating aggregates; unbounded lists. |
| High availability | 1 / 10 | Single replica, `--reload` in the compose file, no readiness probe, no migration gate, no PgBouncer. |
| Performance | 3 / 10 | N+1 on every list; in-Python sums; no cache; client-side fan-out aggregation across chamas. |
| Reliability | 2 / 10 | Non-transactional provider calls, no outbox, no reconciliation, stranded PENDING contributions. |
| Security | 2 / 10 | Unauthenticated money-moving callbacks; plaintext refresh tokens; no rate limits; cleartext HTTP. |
| Observability | 0 / 10 | No structured logging, no correlation IDs, no metrics, no traces; Sentry imported but never initialised. |
| Testability | 2 / 10 | Two backend test files targeting removed endpoints; SQLite standing in for Postgres; no CI; no widget tests. |
| Clean architecture | 5 / 10 | Layer names present, dependency rule not enforced: repositories return transport DTOs straight to the UI. |
| Regulatory readiness | 0 / 10 | No ledger, no audit log, no KYC/AML fields, no retention policy, floating-point money. |
| Fault tolerance | 2 / 10 | No retries, no circuit breaker, no dead-letter path; a provider outage strands transactions permanently. |

## 3. Finding index

| ID | Sev | Finding | Domain |
|---|---|---|---|
| FIN-01 | P0 | Money stored as binary floating point | Data model |
| FIN-02 | P0 | No ledger; balances are mutable counters with lost updates | Data model |
| PAY-01 | P0 | Payment callbacks are unauthenticated and forgeable | Payments |
| PAY-02 | P0 | Callbacks are non-idempotent; replay double-credits | Payments |
| PAY-03 | P0 | Provider call outside the transaction; no outbox, no reconciliation | Payments |
| DB-01 | P0 | Schema drift: `create_tables()` at startup vs. stale migration | Database |
| API-01 | P0 | Client calls endpoints that do not exist; tests cover dead routes | API contract |
| SEC-01 | P0 | Refresh tokens persisted in plaintext | Security |
| SEC-02 | P0 | Access tokens cannot be revoked; logout is cosmetic | Security |
| SEC-03 | P0 | No rate limiting on login, registration or payment initiation | Security |
| OBS-01 | P0 | No observability: no structured logs, correlation IDs, metrics or traces | Observability |
| PERF-01 | P1 | Blocking sync ORM inside `async def` handlers | Performance |
| PERF-02 | P1 | Aggregates computed by hydrating whole collections into Python | Performance |
| PERF-03 | P1 | Missing composite indexes, CHECK constraints and FK cascade rules | Database |
| PERF-04 | P1 | Unbounded list endpoints; offset pagination where used | API |
| PERF-05 | P1 | No cache tier and no background worker | Performance |
| SEC-04 | P1 | Wildcard CORS and no security middleware | Security |
| SEC-05 | P1 | Cleartext HTTP base URL hardcoded to a LAN IP; no pinning | Mobile security |
| SEC-06 | P1 | Mass assignment via blind `setattr` in update handlers | Security |
| SEC-07 | P1 | Session-state `print()` logging; no device integrity, biometrics or screen protection | Mobile security |
| SEC-08 | P1 | Weak password policy, no lockout, no MFA path | Auth |
| REL-01 | P1 | Deployment topology cannot be highly available | Platform |
| REL-02 | P1 | No retries, timeouts budget or circuit breaker around providers | Fault tolerance |
| MOB-01 | P1 | Refresh stampede in the Dio interceptor causes random logouts | Mobile network |
| MOB-02 | P1 | Server-side aggregation done client-side with an N-provider fan-out | Mobile state |
| MOB-03 | P1 | Raw `e.toString()` surfaced as user-facing error text | Mobile UX |
| TEST-01 | P1 | No CI; SQLite substituted for Postgres; no contract or load tests | Testability |
| REG-01 | P0 | No audit trail, KYC/AML fields or retention policy | Regulatory |
| ARCH-01 | P2 | No domain layer or service layer; business rules live in routers | Architecture |
| ARCH-02 | P2 | Inconsistent authorization semantics and no RBAC primitive | Architecture |
| MOB-04 | P2 | Uncached `Image.network` in scrolling lists; no list keys | UI performance |
| MOB-05 | P2 | Router rebuilt on every auth transition; async disk read in redirect | Mobile nav |
| MOB-06 | P2 | No offline state, no optimistic updates, no localisation | Mobile UX |
| OPS-01 | P2 | Destructive `reset_db.py` shipped; pgAdmin with default credentials | Ops hygiene |

**Severity key.** P0 — blocks processing live money; fix before any production traffic. P1 — will cause incidents, data loss or breach at the stated traffic volumes; fix within the first release train. P2 — technical debt with material cost; schedule deliberately.

## 4. Blocking findings (P0)

Each finding follows the same structure: current implementation, problem, risk, recommended refactor, code changes, expected benefits.

### FIN-01 — Money is stored as binary floating point

`P0 · BLOCKING`

backend/app/models/models.py · schemas/projects.py · schemas/budgets.py

**Current implementation**

Every monetary column in the schema is `Float`, which maps to PostgreSQL `DOUBLE PRECISION`: `Project.target_amount`, `Project.raised_amount`, `Contribution.amount`, `Budget.total_income`, `BudgetCategory.allocated_amount`, `spent_amount`, `BudgetExpense.amount`. Derived values are computed in Python floats and rounded at the edge (`round((raised/target)*100, 2)`). The M-Pesa service then truncates with `"Amount": int(amount)`.

**Problem**

IEEE-754 doubles cannot represent most decimal fractions. Accumulating thousands of contributions into `raised_amount += amount` compounds representation error, so the stored total drifts from the sum of its parts and the drift is not reproducible across summation orders. Separately, `int(amount)` silently discards cents: a user who authorises KES 100.75 has 100 requested from M-Pesa but 100.75 recorded locally, so the ledger and the mobile-money statement disagree by construction on every non-integer contribution.

**Risk**

Unreconcilable books. At 50k transactions/day the cent-level divergence between Changa's records and Safaricom's settlement report becomes a daily manual investigation queue, then a dispute liability, then a finding in any audit. Floating-point money is an automatic disqualifier in a CBK/PSP due-diligence review, and it makes the platform unable to answer the only question that matters in a dispute: "what exactly did this member contribute?"

**Recommended refactor**

Represent money as exact decimal end to end: `NUMERIC(14,2)` in Postgres, `Decimal` in Python, string-serialised over JSON, and a `Money` value object in Dart that stores minor units as `int`. Introduce a shared `MoneyAmount` annotated type so the rule is declared once. Never round except when presenting, and never send a truncated amount to a provider — reject sub-unit precision at the schema boundary instead.

**Code changes**

```
# app/core/types.py  (new)
from decimal import Decimal
from typing import Annotated
from sqlalchemy import Numeric
from pydantic import Field, PlainSerializer

MoneyColumn = Numeric(14, 2)   # exact, up to 999,999,999,999.99

MoneyAmount = Annotated[
    Decimal,
    Field(gt=Decimal("0"), max_digits=14, decimal_places=2),
    PlainSerializer(lambda v: f"{v:.2f}", return_type=str),
]
```

```
# app/models/models.py — before
target_amount = Column(Float, nullable=False)
raised_amount = Column(Float, default=0.0)
amount        = Column(Float, nullable=False)

# after
from app.core.types import MoneyColumn
target_amount = Column(MoneyColumn, nullable=False)
amount        = Column(MoneyColumn, nullable=False)
# raised_amount is removed entirely — see FIN-02
```

```
# app/services/mpesa.py — before
"Amount": int(amount),

# after: Daraja accepts whole KES only, so refuse sub-unit precision
# at the API boundary rather than silently truncating here.
if amount != amount.to_integral_value():
    raise ProviderPrecisionError(
        "M-Pesa STK Push accepts whole shillings only"
    )
"Amount": int(amount),
```

```
// mobile: lib/core/money/money.dart  (new)
class Money implements Comparable<Money> {
  final int minor;           // cents — never a double
  final String currency;
  const Money(this.minor, [this.currency = 'KES']);

  factory Money.parse(String v, [String c = 'KES']) {
    final parts = v.split('.');
    final cents = parts.length == 2
        ? int.parse(parts[1].padRight(2, '0').substring(0, 2))
        : 0;
    return Money(int.parse(parts[0]) * 100 + cents, c);
  }

  String toJson() => '${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}';
  Money operator +(Money o) => Money(minor + o.minor, currency);
  @override int compareTo(Money o) => minor.compareTo(o.minor);
}
```

Migration: add `NUMERIC` columns, backfill with `ROUND(old::numeric, 2)`, verify row-by-row against the source ledger, then drop the float columns in a later release. Do not do it in one step.

**Expected benefits**

Correctness: eliminates an entire class of unreconcilable-balance incident. Reliability: totals become deterministic and independent of summation order. Regulatory: satisfies the exact-arithmetic expectation of any payments audit. Cost: removes the manual reconciliation queue that floating-point drift would otherwise create at 50k transactions/day.

### FIN-02 — No ledger: balances are mutable counters updated with an unlocked read-modify-write

`P0 · BLOCKING`

backend/app/routers/payments.py · models/models.py

**Current implementation**

A project's funding total is a column, `projects.raised_amount`, mutated from the payment callback:

```
contribution.status = ContributionStatus.SUCCESS
contribution.provider_reference = result.get("receipt")
contribution.completed_at = datetime.now(timezone.utc)
contribution.project.raised_amount += contribution.amount
db.commit()
```

The same pattern appears in the budget module: `category.spent_amount += payload.amount` on expense creation, and `max(0.0, spent_amount - expense.amount)` on deletion.

**Problem**

This is a read-modify-write in application code with no row lock and no atomic SQL update. Under the default `READ COMMITTED` isolation, two callbacks for the same project that interleave both read the same starting value and the second overwrites the first — a classic lost update. M-Pesa callbacks for a popular project arrive in bursts, so this is not a theoretical race. Worse, `raised_amount` is the only record of the total: there is no append-only ledger from which it could be recomputed, so once it is wrong there is no way to detect it, let alone repair it. The `max(0.0,...)` clamp in the budget path is the same bug wearing a disguise — it hides negative drift instead of preventing it.

Silent, permanent understatement of how much a group has raised. A chama that has collected KES 480,000 shows 460,000; members who paid are told they did not; the platform cannot prove otherwise. This is the single most trust-destroying defect a contribution platform can have, and because it is a lost update rather than an error, nothing logs it and no alert fires.

**Recommended refactor**

Make an append-only ledger the single source of truth, and treat every displayed balance as a projection of it. Three parts:

1. **Ledger entries are immutable.** A successful contribution appends one row; corrections append a reversing row. Nothing is ever updated in place.

2. **Balances are derived.** Either compute on read from an indexed partial aggregate, or maintain a projection updated by an atomic SQL `UPDATE... SET x = x +:n` inside the same transaction as the ledger insert — never a Python-side `+=`.

3. **A nightly job re-derives every projection from the ledger and alerts on any divergence.** This is the control that makes the system auditable.

**Code changes**

```
# app/models/ledger.py  (new) — append-only, no UPDATE ever issued
class LedgerEntry(Base):
    __tablename__ = "ledger_entries"

    id            = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    project_id    = Column(UUID(as_uuid=True), ForeignKey("projects.id"), nullable=False)
    contribution_id = Column(UUID(as_uuid=True), ForeignKey("contributions.id"),
                             nullable=False)
    direction     = Column(SAEnum(LedgerDirection), nullable=False)  # CREDIT | REVERSAL
    amount        = Column(MoneyColumn, nullable=False)
    currency      = Column(String(3), nullable=False, server_default="KES")
    reverses_id   = Column(UUID(as_uuid=True), ForeignKey("ledger_entries.id"),
                           nullable=True)
    created_at    = Column(DateTime(timezone=True), nullable=False, server_default=func.now())

    __table_args__ = (
        # one ledger row per contribution per direction — the DB enforces
        # single-crediting even if application logic is wrong
        UniqueConstraint("contribution_id", "direction",
                         name="uq_ledger_contribution_direction"),
        CheckConstraint("amount > 0", name="ck_ledger_amount_positive"),
        Index("ix_ledger_project_created", "project_id", "created_at"),
    )
```

```
# app/services/ledger_service.py  (new)
async def credit_contribution(
    session: AsyncSession, contribution: Contribution, receipt: str
) -> None:
    """Idempotent, atomic. Safe to call twice; the second call is a no-op."""
    inserted = await session.execute(
        insert(LedgerEntry)
        .values(
            project_id=contribution.project_id,
            contribution_id=contribution.id,
            direction=LedgerDirection.CREDIT,
            amount=contribution.amount,
            currency=contribution.currency,
        )
        .on_conflict_do_nothing(constraint="uq_ledger_contribution_direction")
        .returning(LedgerEntry.id)
    )
    if inserted.scalar_one_or_none() is None:
        return                      # already credited — replayed callback

    # projection maintained atomically in SQL, never read-modify-write
    await session.execute(
        update(Project)
        .where(Project.id == contribution.project_id)
        .values(raised_amount=Project.raised_amount + contribution.amount)
    )
    await session.execute(
        update(Contribution)
        .where(Contribution.id == contribution.id,
               Contribution.status == ContributionStatus.PENDING)
        .values(status=ContributionStatus.SUCCESS,
                provider_reference=receipt,
                completed_at=func.now())
    )
```

```
-- reconciliation control, run nightly; alert on any row returned
SELECT p.id,
       p.raised_amount                                   AS projected,
       COALESCE(SUM(CASE WHEN l.direction = 'credit'   THEN  l.amount
                         WHEN l.direction = 'reversal' THEN -l.amount END), 0)
                                                         AS derived
FROM projects p
LEFT JOIN ledger_entries l ON l.project_id = p.id
GROUP BY p.id, p.raised_amount
HAVING p.raised_amount <> COALESCE(SUM(...), 0);
```

Apply the identical pattern to `BudgetCategory.spent_amount`: expenses become the ledger, `spent_amount` becomes a projection maintained in SQL, and the `max(0.0,...)` clamp is deleted rather than kept.

**Expected benefits**

Reliability: lost updates become structurally impossible — concurrency is resolved by the database, not by luck. Regulatory: every balance becomes provable from an immutable trail, which is the precondition for an audit opinion. Performance: the atomic `UPDATE` removes a full row load per callback. Operationally: the nightly control turns a silent class of bug into a page.

### PAY-01 — Payment callbacks are unauthenticated and forgeable by anyone on the internet

`P0 · BLOCKING`

backend/app/routers/payments.py — POST /payments/mpesa/callback, POST /payments/airtel/callback

**Current implementation**

Both callbacks are plain public routes with no dependency on `get_current_user`, no signature verification, no source-IP allowlist and no shared secret in the path. The handler trusts the request body completely: it looks up the contribution by the attacker-supplied `AccountReference`, and if `ResultCode == 0` it marks the contribution successful and credits the project. It does not compare the callback's amount to the amount the user actually authorised.

**Problem**

The only thing standing between an attacker and free money is knowledge of a reference string — and references are returned to the client in the `201` response of `/contributions/mpesa`, so the payer already has it. The attack is: initiate a KES 1 contribution, read the reference from the response, cancel the STK prompt, then `curl` the callback with a success body. The contribution is marked `SUCCESS` and the project is credited. Because the handler never validates the amount against the initiated amount, and `_generate_reference` uses only 4 bytes of entropy (`secrets.token_hex(4)` — 4.3 billion values, brute-forceable in bulk against an unthrottled endpoint), references of *other* users are reachable too. Both handlers also return `{"ResultCode": 0}` on every path including unknown references, which is correct for Safaricom but means a scanner gets no negative signal and the server logs nothing.

**Risk**

Direct, unbounded financial fraud with no audit trail. A single script can inflate any project's balance arbitrarily. When the chama withdraws against a fabricated balance, the loss is real and it lands on the operator. This is the finding that most clearly makes the current build unsafe to point at production Daraja credentials.

**Recommended refactor**

Defence in depth, four independent layers, none of which is sufficient alone:

1. **Network.** Restrict the callback path to Safaricom's published egress ranges at the load balancer or WAF, and additionally in middleware.

2. **Unguessable path secret.** Register the callback URL as `/payments/mpesa/callback/{opaque_token}` with a 32-byte token, compared in constant time.

3. **Never trust the body for money.** Treat the callback purely as a *signal to verify*: on receipt, call Daraja's `stkpushquery` (or Airtel's transaction-status endpoint) server-to-server and act only on that authenticated response. This single change neutralises body forgery entirely.

4. **Amount and state invariants.** Assert the verified amount equals the initiated amount and the contribution is still `PENDING`; on mismatch, quarantine for manual review instead of crediting.

Persist every raw callback body before processing, so forged attempts are forensically visible.

**Code changes**

```
# app/routers/payments.py — replace both callback handlers
import hmac, ipaddress
from app.core.config import settings

def _verify_callback_origin(request: Request, token: str) -> None:
    if not hmac.compare_digest(token, settings.MPESA_CALLBACK_TOKEN):
        raise HTTPException(404)                       # indistinguishable from a bad path
    client = ipaddress.ip_address(request.headers.get("x-forwarded-for",
                                                      request.client.host).split(",")[0].strip())
    if not any(client in net for net in settings.MPESA_EGRESS_NETS):
        raise HTTPException(404)

@router.post("/payments/mpesa/callback/{token}")
async def mpesa_callback(
    token: str,
    request: Request,
    session: AsyncSession = Depends(get_session),
):
    _verify_callback_origin(request, token)
    raw = await request.body()

    # 1. persist the raw payload first — forensics before logic
    event = await record_provider_event(
        session, provider="mpesa", raw=raw,
        signature=request.headers.get("x-signature"),
    )
    await session.commit()

    # 2. hand off; never process money on the request path
    await enqueue(process_provider_callback, event_id=event.id)
    return {"ResultCode": 0, "ResultDesc": "Accepted"}
```

```
# app/workers/callbacks.py  (new) — the body is a hint, Daraja is the truth
async def process_provider_callback(event_id: UUID) -> None:
    async with session_scope() as session:
        event = await session.get(ProviderEvent, event_id)
        hint = json.loads(event.raw)
        reference = extract_reference(hint)

        contribution = await session.scalar(
            select(Contribution)
            .where(Contribution.reference == reference)
            .with_for_update()                      # serialise concurrent callbacks
        )
        if contribution is None:
            log.warning("callback.unknown_reference", reference=reference)
            return

        # authoritative, server-to-server confirmation
        verified = await mpesa.query_stk_status(contribution.checkout_request_id)

        if not verified.success:
            await mark_failed(session, contribution, verified.failure_reason)
        elif verified.amount != contribution.amount:
            await quarantine(session, contribution, verified,
                             reason="amount_mismatch")     # never auto-credit
        else:
            await credit_contribution(session, contribution, verified.receipt)
        await session.commit()
```

**Expected benefits**

Security: closes a direct financial-fraud path; forging a callback no longer changes any balance because balances only move on authenticated provider confirmations. Reliability: moving processing off the request path means a slow Daraja query never times out the callback, so the provider stops retrying. Observability: every callback, including rejected ones, becomes a queryable event.

### PAY-02 — Callbacks are non-idempotent — a normal provider retry double-credits

`P0 · BLOCKING`

backend/app/routers/payments.py

**Current implementation**

The handler applies the credit unconditionally. There is no check that the contribution is still `PENDING`, no unique constraint linking a provider receipt to a single credit, and no idempotency key.

**Problem**

Payment providers guarantee at-least-once delivery, not exactly-once. Safaricom retries when a callback is slow or returns a non-2xx, and in production duplicate callbacks are routine, not exceptional. Every duplicate runs `raised_amount += amount` again. Combined with FIN-02, the system has no mechanism — application-level or database-level — that could stop it.

**Risk**

Overstated balances, this time without malice — which makes it more likely and harder to explain. A project appears funded on money that was never received; the chama disburses; the shortfall surfaces at settlement. Expected frequency at 50k initiations/day with even a 0.5% retry rate is roughly 250 double-credits per day.

**Recommended refactor**

Enforce idempotency in the database, not in application logic — the constraint must hold even when the code is wrong. Two constraints do it: `UNIQUE (contribution_id, direction)` on the ledger (see FIN-02), and `UNIQUE (provider, provider_reference)` on contributions so one M-Pesa receipt can only ever settle one contribution. Then make the state transition conditional so a second attempt affects zero rows.

**Code changes**

```
# app/models/models.py — Contribution.__table_args__
__table_args__ = (
    UniqueConstraint("provider", "provider_reference",
                     name="uq_contribution_provider_receipt"),
    CheckConstraint("amount > 0", name="ck_contribution_amount_positive"),
    Index("ix_contributions_project_status", "project_id", "status"),
    Index("ix_contributions_pending_initiated", "initiated_at",
          postgresql_where=text("status = 'pending'")),   # reconciliation sweep
)
```

```
# conditional transition — the WHERE clause is the idempotency guard
result = await session.execute(
    update(Contribution)
    .where(Contribution.id == contribution.id,
           Contribution.status == ContributionStatus.PENDING)   # ← guard
    .values(status=ContributionStatus.SUCCESS,
            provider_reference=verified.receipt,
            completed_at=func.now())
)
if result.rowcount == 0:
    log.info("callback.duplicate_ignored", reference=contribution.reference)
    return              # already settled — nothing to do, and nothing credited
```

**Expected benefits**

Reliability: duplicate delivery becomes a no-op rather than a financial error, and the guarantee lives in the schema where it cannot be refactored away. Maintainability: retry-safety stops being something every future handler must remember.

### PAY-03 — Provider call sits outside the transaction; no outbox, no reconciliation, no recovery

`P0 · BLOCKING`

backend/app/routers/payments.py · services/mpesa.py · mobile payments_provider.dart

**Current implementation**

```
db.add(contribution); db.commit(); db.refresh(contribution)
try:
    await mpesa.stk_push(...)                  # network call, after commit
except Exception as e:
    contribution.status = ContributionStatus.FAILED
    contribution.failure_reason = str(e)       # raw exception into the DB
    db.commit()
    raise HTTPException(502, detail=f"M-Pesa request failed: {str(e)}")
```

The mobile client then polls `/contributions/status/{reference}` every 3 seconds up to 40 times and gives up after two minutes. Nothing on the server ever revisits a `PENDING` contribution.

**Problem**

Three distinct failure modes, all unhandled. *First*, the STK push is a side effect with no transactional relationship to the row that records it: if the worker is killed, redeployed or OOM-killed between the commit and the push, the contribution is `PENDING` forever and no prompt was ever sent. *Second*, if the push actually succeeded but the response was lost (timeout, connection reset), the code marks the contribution `FAILED` while the customer's phone is showing a live PIN prompt — the user pays and the platform has recorded a failure. *Third*, since nothing reconciles, the only actor that ever checks on a payment is a mobile client that stops after 120 seconds; a user whose network drops mid-flow has no path back to the truth. Additionally, `str(e)` is written to the database and returned to the client, leaking internal detail (see SEC-07), and `checkout_request_id` is never persisted — so there is no handle with which to query Daraja later even if someone wanted to.

Money taken from customers with no corresponding record — the worst possible direction for the error, because the customer knows and the platform does not. Each occurrence is a support ticket, a chargeback conversation and a trust loss. At 50k initiations/day, even a 0.1% rate of lost-response pushes is 50 paid-but-recorded-failed transactions daily.

**Recommended refactor**

Transactional outbox plus a reconciliation sweeper. The request handler does one thing: commit the contribution and an outbox row in a single transaction, then return. A worker drains the outbox, performs the STK push with a provider idempotency key, and records the `checkout_request_id`. A timeout is never treated as a failure — it is treated as *unknown*, and unknown is resolved by querying the provider, never by guessing. A separate periodic sweeper queries every contribution still `PENDING` after 90 seconds and settles it from the provider's authoritative status, escalating to a manual queue after N attempts.

**Code changes**

```
# app/routers/payments.py — handler becomes purely transactional
@router.post("/v1/contributions", response_model=ContributionResponse, status_code=202)
async def initiate_contribution(
    payload: ContributeRequest,
    idempotency_key: str = Header(..., alias="Idempotency-Key"),
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
):
    # client-supplied key makes double-taps safe
    existing = await session.scalar(
        select(Contribution).where(Contribution.idempotency_key == idempotency_key)
    )
    if existing:
        return ContributionResponse.model_validate(existing)

    project = await get_active_project(session, payload.project_id)
    await assert_can_contribute(session, user, project)

    contribution = Contribution(
        project_id=project.id, user_id=user.id, amount=payload.amount,
        provider=payload.provider, phone=payload.phone,
        reference=generate_reference(payload.provider),      # 16 bytes, not 4
        idempotency_key=idempotency_key,
        status=ContributionStatus.PENDING,
    )
    session.add(contribution)
    session.add(OutboxMessage(                                # same transaction
        topic="payment.initiate",
        payload={"contribution_id": str(contribution.id)},
    ))
    await session.commit()          # atomic: either both rows exist, or neither
    return ContributionResponse.model_validate(contribution)
```

```
# app/workers/payment_initiator.py  (new)
async def handle(contribution_id: UUID) -> None:
    async with session_scope() as session:
        c = await session.scalar(
            select(Contribution).where(Contribution.id == contribution_id).with_for_update()
        )
        if c.status is not ContributionStatus.PENDING or c.checkout_request_id:
            return                                    # already pushed

        try:
            res = await mpesa.stk_push(phone=c.phone, amount=c.amount,
                                       reference=c.reference)
            c.checkout_request_id = res.checkout_request_id     # the query handle
            c.pushed_at = utcnow()
        except ProviderTimeout:
            # UNKNOWN, not failed. Leave PENDING; the sweeper resolves it.
            c.push_attempts += 1
            log.warning("stk.timeout", reference=c.reference, attempts=c.push_attempts)
        except ProviderRejected as e:
            c.status = ContributionStatus.FAILED
            c.failure_code = e.code                   # a code, never str(e)
        await session.commit()
```

```
# app/workers/reconciler.py  (new) — runs every 60s; the safety net
async def sweep() -> None:
    cutoff = utcnow() - timedelta(seconds=90)
    stale = await session.scalars(
        select(Contribution)
        .where(Contribution.status == ContributionStatus.PENDING,
               Contribution.initiated_at < cutoff,
               Contribution.reconcile_attempts < 10)
        .limit(500)                                    # bounded batch
    )
    for c in stale:
        verified = await provider_for(c).query_status(c)
        if   verified.settled:  await credit_contribution(session, c, verified.receipt)
        elif verified.rejected: await mark_failed(session, c, verified.failure_code)
        else:
            c.reconcile_attempts += 1
            if c.reconcile_attempts >= 10:
                await escalate_to_manual_review(session, c)   # never silently abandoned
```

**Expected benefits**

Reliability: no transaction can be stranded by a process death, and "paid but recorded failed" is eliminated because a timeout is never interpreted as a failure. Performance: the request returns in a few milliseconds instead of blocking on Daraja for up to 15 seconds, cutting p99 initiation latency by an order of magnitude and removing the largest source of held connections. Fault tolerance: a full Daraja outage degrades to queued initiations that drain on recovery, instead of user-visible failures.

### DB-01 — Schema drift: tables are created implicitly at startup while the migration history describes a schema that no longer exists

`P0 · BLOCKING`

backend/app/main.py · database.py · alembic/versions/001_initial_schema.py

**Current implementation**

The FastAPI lifespan hook calls `create_tables()`, i.e. `Base.metadata.create_all()`, on every boot. Alembic is also configured, with exactly one revision. That revision creates `users`, `projects`, `project_members`, `teams`, `team_members`, `contributions` and `refresh_tokens`, with a `projectvisibility` enum on `projects`.

The ORM models describe a different database: `project_members`, `teams`, `team_members` and `visibility` are gone; `chamas`, `chama_members`, `budgets`, `budget_categories` and `budget_expenses` exist only in the models; and `projects` has gained six columns (`chama_id`, `payment_type`, `payment_number`, `payment_name`, `account_reference`, `cover_image_url`) that no migration ever adds. A `reset_db.py` script sits at the backend root.

**Problem**

The migration history is fiction. Running `alembic upgrade head` on a fresh database produces a schema the application cannot use; the application only works because `create_all` quietly fills the gap. And `create_all` only ever *creates*: it will not add a column, change a type, add a constraint or drop anything. So the moment a model changes on an existing database — which is every release — production and code diverge silently and the first symptom is a runtime `UndefinedColumn` error under live traffic. Two replicas booting concurrently can also race inside `create_all`, which is one reason the current topology cannot scale horizontally.

**Risk**

No safe deploy path and no rollback. There is no way to reason about what production's schema is, no way to review a schema change before it ships, and no way to reverse one. For a regulated platform this is also a documentation failure in its own right: schema history is audit evidence, and here it does not exist.

**Recommended refactor**

Delete `create_tables()` and make Alembic the only mechanism that touches DDL. Squash to a truthful baseline generated from the current models, add a CI check that fails when models and migrations disagree, and run migrations as a deploy gate — a separate job that must succeed before new pods accept traffic — never from application startup.

**Code changes**

```
# app/main.py — before
@asynccontextmanager
async def lifespan(app: FastAPI):
    import os
    if os.environ.get("PYTEST_RUNNING") != "1":
        create_tables()                       # ← delete
    yield

# after: startup verifies, never mutates
@asynccontextmanager
async def lifespan(app: FastAPI):
    configure_observability(app)              # see OBS-01
    await verify_schema_at_head()             # refuse to serve on a stale schema
    app.state.redis = await create_redis_pool(settings.REDIS_URL)
    yield
    await app.state.redis.close()
    await engine.dispose()                    # graceful shutdown
```

```
# CI gate — fails the build if models drift from migrations
alembic upgrade head
alembic check          # exits non-zero if autogenerate would emit operations

# Dockerfile: migrations are a deploy step, not an app step
# (Kubernetes: an initContainer or a pre-deploy Job)
CMD ["gunicorn", "app.main:app", \
     "-k", "uvicorn.workers.UvicornWorker", \
     "-w", "4", "-b", "0.0.0.0:8000", \
     "--graceful-timeout", "30", "--timeout", "60"]
```

Also: delete `reset_db.py` from the repository, or move it under a `scripts/dev/` path excluded from the production image.

**Expected benefits**

Reliability: schema changes become reviewable, reversible and verified before traffic reaches them. Scalability: removes the concurrent-`create_all` race that blocks running more than one replica. Regulatory: produces the schema-change audit trail an assessor will ask for.

### API-01 — The mobile app calls endpoints that do not exist, and the test suite covers the same dead routes

`P0 · BLOCKING`

mobile/.../api_constants.dart · project_repository.dart · backend/app/routers/projects.py · backend/tests/conftest.py

**Current implementation**

The server's projects router defines only `GET/PUT/DELETE /projects/{project_id}` and `GET /projects/{project_id}/contributors`. Project creation and listing were moved under `/chamas/{chama_id}/projects`. The Flutter `ProjectsRepository` still calls `GET /projects?page=1&page_size=20&search=…` and `POST /projects`, and `ApiConstants` additionally declares `/projects/{id}/members`, `/projects/{id}/teams` and a team-join route. None exist. `tests/conftest.py`'s `sample_project` fixture posts to `/projects` with a `visibility` field that the current schema does not accept.

**Problem**

`GET /projects?page=1` does not 404 — it matches `GET /projects/{project_id}` with an empty path segment or fails UUID coercion, returning `422`, which the client maps to `ValidationFailure` and surfaces as a generic error. So the failure presents as a confusing UI bug rather than a missing route. The deeper problem is that nothing enforces the contract: there is no generated client, no schema check in CI, and the tests that would have caught it were written against the old API and now fail for the same reason — meaning the suite is red, so its signal has already been abandoned. The app compensates by aggregating projects client-side (see MOB-02), which is why the breakage is not immediately obvious.

**Risk**

Shipping a build whose primary browse and create flows are broken, with a test suite that cannot tell you. More structurally: every future backend change is a coin flip, because the client's expectations are expressed only as string constants that no tool verifies.

**Recommended refactor**

Make the OpenAPI document the contract and generate the Dart client from it, so drift becomes a compile error rather than a runtime 422. Concretely: version the API under `/v1`; add the missing `GET /v1/projects` cross-chama feed the app actually needs (with server-side filter, sort, search and keyset pagination); delete the dead `teams`/`members` constants; and commit the OpenAPI snapshot so any unintended change shows up in review.

**Code changes**

```
# app/routers/projects.py — the endpoint the client already expects
@router.get("", response_model=CursorPage[ProjectResponse])
async def list_projects(
    q: ProjectQuery = Depends(),          # search, status, chama_id, sort
    cursor: str | None = None,
    limit: int = Query(20, le=100),
    session: AsyncSession = Depends(get_session),
    user: User = Depends(get_current_user),
):
    """Projects across every chama the caller belongs to. Keyset paginated."""
    stmt = (
        select(Project)
        .join(ChamaMember, ChamaMember.chama_id == Project.chama_id)
        .where(ChamaMember.user_id == user.id)
        .options(selectinload(Project.chama))          # no N+1
        .order_by(Project.created_at.desc(), Project.id.desc())
        .limit(limit + 1)
    )
    if q.search:
        stmt = stmt.where(Project.search_vector.match(q.search))   # GIN index
    if q.status:
        stmt = stmt.where(Project.status == q.status)
    if cursor:
        created, pid = decode_cursor(cursor)
        stmt = stmt.where(tuple_(Project.created_at, Project.id) < (created, pid))
    return CursorPage.build(await session.scalars(stmt), limit)
```

```
# CI: contract is generated and diffed, never hand-maintained
python -m app.tools.dump_openapi > openapi.json
git diff --exit-code openapi.json || { echo "API contract changed — review"; exit 1; }

# mobile: generate, don't hand-write
dart run build_runner build            # openapi_generator → lib/core/api/generated/
# then delete the hand-rolled string constants in api_constants.dart
```

**Expected benefits**

Reliability: a whole class of production-only failure moves to build time. Performance: the cross-chama feed becomes one indexed query instead of the current N-request client fan-out (MOB-02) — for a user in 8 chamas, 8 round trips become 1. Maintainability: renaming a field stops being a coordination problem across two repositories.

### SEC-01 — Refresh tokens are stored in plaintext; access tokens cannot be revoked

`P0 · BLOCKING`

backend/app/models/models.py · core/security.py · routers/auth.py

**Current implementation**

The full refresh JWT is written verbatim into `refresh_tokens.token String(500)` with a unique index. Access tokens carry only `sub`, `exp` and `type` — no `jti`, `iat`, `aud` or `iss`. `get_current_user` imports `RefreshToken` but never consults it. `/auth/logout` flips `is_revoked` on one refresh row. `/auth/refresh` rotates correctly but does not check `expires_at` against the clock, and treats presenting an already-revoked token as an ordinary failure. `change_password` does not revoke any session.

**Problem**

Four compounding defects. *(a)* Plaintext storage means read access to one table — a backup, a replica, a logged query, a SQL injection anywhere in the app — is immediate, silent account takeover for every user with an active session. Refresh tokens are credentials and must be stored like passwords. *(b)* With no `jti` and no deny-list, an access token is valid for its full 30 minutes no matter what: logout does not end a session, and neither does password change or an admin disabling the account. *(c)* Reuse of a revoked refresh token is the canonical signal that a token has been stolen and replayed; here it returns 401 and nothing else happens, so the attacker's stolen-but-still-valid sibling token keeps working. *(d)* Because `expires_at` is never compared, an old row's expiry is decorative — only the JWT's own `exp` applies, and revoked rows accumulate forever with no cleanup.

**Risk**

Mass account takeover from a single read-only data exposure, with no containment: there is no mechanism to invalidate sessions in bulk, so the only response to a suspected breach is to rotate `SECRET_KEY` and sign every user out globally. On a money platform this is a reportable incident and, in Kenya, a Data Protection Act notification.

**Recommended refactor**

Store only a SHA-256 digest of an opaque high-entropy refresh secret (not a JWT — a refresh token needs no claims). Give access tokens a `jti` and a short life (10 minutes), and check a Redis deny-list keyed by `jti` plus a per-user `sessions_valid_after` epoch so bulk invalidation is one write. Group refresh tokens into *families* per device: reuse of a consumed token revokes the entire family and raises a security event. Revoke all families on password change. Add a device record (name, platform, last-seen IP) so users can see and end sessions — the foundation MFA and login-history will build on (SEC-08).

**Code changes**

```
# app/models/auth.py — before
token      = Column(String(500), unique=True, nullable=False)   # plaintext JWT

# after
token_hash = Column(String(64), unique=True, nullable=False, index=True)  # sha256 hex
family_id  = Column(UUID(as_uuid=True), nullable=False, index=True)       # per device
device_id  = Column(UUID(as_uuid=True), ForeignKey("devices.id"), nullable=False)
consumed_at = Column(DateTime(timezone=True), nullable=True)
revoked_at  = Column(DateTime(timezone=True), nullable=True)
revoked_reason = Column(String(40), nullable=True)   # logout | reuse | password_change
```

```
# app/core/security.py
import hashlib, secrets, uuid

def issue_refresh_token() -> tuple[str, str]:
    raw = secrets.token_urlsafe(48)                      # opaque, 384 bits
    return raw, hashlib.sha256(raw.encode()).hexdigest() # store the digest only

def create_access_token(user_id: str, session_id: str) -> str:
    now = datetime.now(timezone.utc)
    return jwt.encode({
        "sub": user_id, "sid": session_id,
        "jti": str(uuid.uuid4()),                        # revocable
        "iat": now, "nbf": now,
        "exp": now + timedelta(minutes=10),              # was 30
        "iss": settings.JWT_ISSUER, "aud": settings.JWT_AUDIENCE,
        "type": "access",
    }, settings.SECRET_KEY, algorithm="HS256")
```

```
# app/routers/auth.py — refresh with reuse detection
row = await session.scalar(
    select(RefreshToken)
    .where(RefreshToken.token_hash == sha256(payload.refresh_token))
    .with_for_update()
)
if row is None:
    raise HTTPException(401, "Invalid refresh token")

if row.consumed_at is not None or row.revoked_at is not None:
    # replay of a spent token ⇒ assume theft; kill the whole device family
    await revoke_family(session, row.family_id, reason="reuse")
    await session.commit()
    log.warning("auth.refresh_reuse", user_id=str(row.user_id),
                family_id=str(row.family_id))
    raise HTTPException(401, "Session invalidated. Please sign in again.")

if row.expires_at <= datetime.now(timezone.utc):        # actually enforced now
    raise HTTPException(401, "Refresh token expired")

row.consumed_at = func.now()
raw, digest = issue_refresh_token()                      # rotate within the family
```

```
# app/core/security.py — access tokens become revocable
async def get_current_user(creds=Depends(bearer_scheme), redis=Depends(get_redis),
                          session=Depends(get_session)) -> User:
    payload = decode_token(creds.credentials,
                           audience=settings.JWT_AUDIENCE,
                           issuer=settings.JWT_ISSUER)
    if await redis.exists(f"jti:revoked:{payload['jti']}"):
        raise HTTPException(401, "Token revoked")

    # one key per user invalidates every outstanding access token at once
    cutoff = await redis.get(f"user:{payload['sub']}:valid_after")
    if cutoff and payload["iat"] < float(cutoff):
        raise HTTPException(401, "Session expired")
    ...
```

**Expected benefits**

Security: a stolen database no longer yields usable sessions; logout, password change and admin lockout become effective within seconds; stolen-token replay is detected and contained automatically rather than going unnoticed. Latency cost is one Redis lookup (sub-millisecond) per request. Regulatory: satisfies session-management and device-visibility expectations, and produces the security-event stream an incident response needs.

### SEC-03 — No rate limiting anywhere, including login and payment initiation

`P0 · BLOCKING`

backend/app/main.py — no limiter middleware on any route

**Current implementation**

The only middleware registered is CORS. Every endpoint accepts unlimited requests from any source: `/auth/login`, `/auth/register`, `/auth/refresh`, `/chamas/join`, `/contributions/mpesa` and both callbacks.

**Problem**

Four separate abuse paths. *Credential stuffing:* `/auth/login` with no attempt counter and no lockout, against a user base that will reuse passwords. *Cost amplification:* `/contributions/mpesa` triggers a real STK push, so an attacker can send unlimited PIN prompts to arbitrary Kenyan phone numbers — the platform pays per request in provider fees and reputational damage, and Safaricom will suspend the shortcode. *Invite-code enumeration:* `/chamas/join` against `generate_invite_code()`, which is `CHNG-` plus `secrets.token_hex(2)` — only **65,536** possible codes, exhaustively enumerable in minutes, letting an attacker join arbitrary private chamas and read their projects and members. *Reference enumeration:* the 4-byte contribution reference discussed in PAY-01. Every one of these is unthrottled because there is no limiter at all.

**Risk**

Account takeover at scale, direct provider costs, shortcode suspension (which is a full outage of the product's core function), and privacy breach of every private chama in the system. The invite-code entropy issue alone is a reportable data exposure.

**Recommended refactor**

Redis-backed sliding-window limits applied per route class, keyed by the most specific identity available (user ID when authenticated, then device ID, then IP), plus progressive lockout on repeated auth failure and a hard per-user daily cap on payment initiations. Raise invite-code entropy to 8 bytes and rate-limit lookups per IP regardless. Limits belong in middleware, not sprinkled through handlers, and must also be enforced at the edge (WAF) so a flood never reaches the application.

**Code changes**

```
# app/core/ratelimit.py  (new) — atomic sliding window in one round trip
WINDOW = """
local n = redis.call('INCR', KEYS[1])
if n == 1 then redis.call('EXPIRE', KEYS[1], ARGV[1]) end
return n
"""

LIMITS = {                       # requests : seconds
    "auth:login":        (5,   300),    # 5 attempts / 5 min / identity
    "auth:register":     (3,  3600),
    "auth:refresh":      (30,  300),
    "chama:join":        (10, 3600),    # kills invite-code enumeration
    "payment:initiate":  (5,   300),    # + a 20/day per-user cap below
    "default":           (300,  60),
}

async def enforce(redis, bucket: str, identity: str) -> None:
    limit, window = LIMITS.get(bucket, LIMITS["default"])
    n = await redis.eval(WINDOW, 1, f"rl:{bucket}:{identity}", window)
    if n > limit:
        raise HTTPException(429, "Too many requests",
                            headers={"Retry-After": str(window)})
```

```
# app/models/models.py — invite codes: 65,536 → 4.3 billion
def generate_invite_code() -> str:
    return f"CHNG-{secrets.token_hex(2).upper()}"     # before: 16 bits

def generate_invite_code() -> str:
    # Crockford base32, ambiguous characters removed, 40 bits of entropy
    alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
    return "CHNG-" + "".join(secrets.choice(alphabet) for _ in range(8))
```

```
# app/routers/auth.py — progressive lockout, constant-time failure
@router.post("/login", dependencies=[Depends(rate_limit("auth:login"))])
async def login(payload: LoginRequest, request: Request, ...):
    user = await session.scalar(select(User).where(User.email == payload.email))

    if await is_locked(redis, payload.email):
        raise HTTPException(423, "Account temporarily locked. Try again later.")

    # always run a hash comparison so timing does not reveal account existence
    ok = verify_password(payload.password,
                         user.hashed_password if user else DUMMY_HASH)
    if not user or not ok or not user.is_active:
        await register_failure(redis, payload.email)      # 5 → 15min, 10 → 1h
        await record_login_attempt(session, payload.email, request, success=False)
        raise HTTPException(401, "Invalid email or password")

    await clear_failures(redis, payload.email)
    await record_login_attempt(session, payload.email, request, success=True)
```

**Expected benefits**

Security: closes credential stuffing, invite-code enumeration and STK-push abuse. Cost: eliminates an unbounded provider-fee exposure. Availability: protects the database from application-layer floods, and keeps the shortcode in good standing. The login handler also stops leaking account existence through response timing.

### OBS-01 — The system is unobservable: no structured logs, correlation IDs, metrics or traces

`P0 · BLOCKING`

backend/app/main.py · requirements.txt · mobile auth_provider.dart

**Current implementation**

There is no logging configuration in the codebase — not a single `logging.getLogger` call. `sentry-sdk==2.19.2` is pinned in `requirements.txt` but `sentry_sdk.init()` is never called, so it does nothing. `/health` returns a static payload without checking the database. Uvicorn's default access log is the only output. On the mobile side, session state is traced with raw `print()` calls in `AuthNotifier._checkSession`.

**Problem**

Nobody can answer basic operational questions. There is no way to trace one user's failed contribution across the API, the provider call and the callback, because no request ID exists to correlate them. There is no payment funnel instrumentation, so a 40% drop in STK success — the single most important business signal — is invisible until users complain. Exceptions vanish into stdout. No metric exists on which to base an alert, an SLO, or an autoscaling decision. And the `/health` endpoint reports healthy while the database is unreachable, so an orchestrator will happily keep routing traffic to a broken pod.

**Risk**

Mean-time-to-detection equals the time for a user to complain, and mean-time-to-resolution is unbounded because there is no evidence to debug from. For a payments platform this converts every incident into a financial-integrity incident: without a correlated trail you cannot prove what happened to a given shilling. It is also the reason several findings in this audit are invisible in production today rather than already known.

**Recommended refactor**

Three pillars, wired once in middleware. **Logs:** `structlog` emitting JSON, with a request-scoped context holding `request_id`, `user_id`, route and latency, and a redaction processor so PII and secrets can never be logged by accident. **Metrics:** Prometheus with RED metrics per route plus explicit business counters for the payment funnel. **Traces:** OpenTelemetry auto-instrumentation for FastAPI, SQLAlchemy and httpx, so a slow request shows exactly which query or provider call caused it. Propagate the request ID to the mobile client and back so a support ticket carries a trace handle. Split `/health` (liveness, static) from `/ready` (checks DB and Redis). Replace all `print()` in Dart with a logger that is a no-op in release builds.

**Code changes**

```
# app/core/observability.py  (new)
import structlog, sentry_sdk
from prometheus_client import Counter, Histogram
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

REDACT = {"password", "hashed_password", "access_token", "refresh_token",
          "token", "phone", "MPESA_PASSKEY", "MPESA_CONSUMER_SECRET"}

def _redact(_, __, event: dict) -> dict:
    for k in list(event):
        if k in REDACT:
            event[k] = "[redacted]"
    if "phone" in event:                      # keep last 3 for support triage
        event["phone"] = f"***{str(event['phone'])[-3:]}"
    return event

payment_initiated = Counter("changa_payment_initiated_total", "", ["provider"])
payment_settled   = Counter("changa_payment_settled_total",   "", ["provider", "outcome"])
callback_rejected = Counter("changa_callback_rejected_total", "", ["provider", "reason"])
settle_latency    = Histogram("changa_payment_settle_seconds", "", ["provider"],
                              buckets=(1, 3, 5, 10, 20, 40, 90, 180))

def configure_observability(app) -> None:
    structlog.configure(processors=[
        structlog.contextvars.merge_contextvars,   # request_id flows automatically
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        _redact,
        structlog.processors.JSONRenderer(),
    ])
    sentry_sdk.init(dsn=settings.SENTRY_DSN,        # was declared, never called
                    environment=settings.ENVIRONMENT,
                    traces_sample_rate=0.1,
                    send_default_pii=False)
    FastAPIInstrumentor.instrument_app(app)
    SQLAlchemyInstrumentor().instrument(engine=engine.sync_engine)
    HTTPXClientInstrumentor().instrument()
```

```
# app/middleware/request_context.py  (new)
class RequestContextMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request_id = request.headers.get("x-request-id") or str(uuid.uuid4())
        structlog.contextvars.bind_contextvars(
            request_id=request_id,
            route=request.url.path,
            method=request.method,
        )
        started = time.perf_counter()
        try:
            response = await call_next(request)
        except Exception:
            log.exception("request.unhandled")     # nothing disappears silently
            raise
        finally:
            structlog.contextvars.clear_contextvars()
        response.headers["x-request-id"] = request_id   # client can quote it in support
        log.info("request.completed", status=response.status_code,
                 duration_ms=round((time.perf_counter() - started) * 1000, 2))
        return response
```

```
# app/main.py — liveness vs readiness
@app.get("/health", include_in_schema=False)          # liveness: am I running?
async def health():
    return {"status": "ok"}

@app.get("/ready", include_in_schema=False)           # readiness: can I serve?
async def ready(session: AsyncSession = Depends(get_session), redis=Depends(get_redis)):
    checks = {}
    try:
        await session.execute(text("SELECT 1")); checks["db"] = "ok"
    except Exception:
        checks["db"] = "fail"
    try:
        await redis.ping(); checks["redis"] = "ok"
    except Exception:
        checks["redis"] = "fail"
    ok = all(v == "ok" for v in checks.values())
    return JSONResponse(checks, status_code=200 if ok else 503)
```

```
// mobile: lib/core/logging/log.dart  (new)
// replaces every print() — silent in release, structured in debug
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

void logD(String event, [Map<String, Object?> fields = const {}]) {
  if (kReleaseMode) return;                 // never ships
  dev.log('$event ${fields.isEmpty ? '' : fields}', name: 'changa');
}

// auth_provider.dart — before
print('>>> IS LOGGED IN: $isLoggedIn');
// after
logD('auth.session_checked', {'logged_in': isLoggedIn});
```

**Alerts to define on day one:** STK settle rate below 85% over 15 min; `callback_rejected_total` above zero (indicates forgery attempts); any row returned by the FIN-02 reconciliation query; contributions still `PENDING` older than 10 minutes; p99 request latency above 1s; connection-pool saturation above 80%.

**Expected benefits**

Observability: from zero to full RED metrics, distributed traces and correlated logs. Reliability: MTTD drops from "when a user complains" to under a minute for every alert above; MTTR typically improves 5–10× because a trace identifies the failing span directly. Security: redaction-by-default plus a security-event stream. Availability: a correct readiness probe lets the orchestrator stop sending traffic to a pod that cannot reach its database.

### REG-01 — No audit trail, KYC/AML surface or data-retention policy

`P0 · BLOCKING`

whole backend — no audit, consent, KYC or retention model exists

**Current implementation**

State changes are in-place mutations with no record of actor, time or previous value: `update_project` and `update_chama` loop `setattr` over the payload, `remove_member` hard-deletes the row, `regenerate_invite_code` overwrites in place. `User.is_verified` exists but nothing ever sets it, and there are no identity fields (national ID, date of birth, verification status or evidence). The mobile app has a `policy_view_screen` and a `consent_checkbox`, but consent is never recorded server-side. Nothing anywhere sets a retention period or supports erasure.

**Problem**

The platform aggregates member funds and moves them through mobile money, which places it squarely in the space regulators treat as payment/deposit-taking activity. Four obligations are entirely unimplemented: *(1) auditability* — who changed a project's target, who removed a member, who regenerated an invite code, is unknowable; *(2) customer identification* — no KYC data, so no ability to apply thresholds, tiering or sanctions screening; *(3) suspicious-activity monitoring* — no velocity rules, no structuring detection, no reporting path; *(4) data protection* — the Kenyan Data Protection Act requires a lawful-basis record, a retention schedule and a mechanism for erasure and portability, and the app collects consent in the UI without persisting the evidence, which is arguably worse than not asking.

**Risk**

Regulatory action, inability to obtain or keep a PSP partnership, and — practically before either of those — inability to answer a member dispute or a law-enforcement request. Retrofitting an audit trail after launch is materially harder than building it now, because the history that matters is the history you did not record.

**Recommended refactor**

Four additions, all schema-first so they cannot be bypassed by application code. An append-only `audit_events` table written by a SQLAlchemy session hook rather than by each handler; a `kyc_profiles` table with tiered verification and contribution limits per tier; a `consent_records` table capturing policy version, timestamp, IP and user agent; and soft deletion plus a documented retention schedule (financial records retained 7 years, security logs 1 year, everything else deleted or anonymised on account closure).

**Code changes**

```
# app/models/audit.py  (new) — append-only; REVOKE UPDATE, DELETE from the app role
class AuditEvent(Base):
    __tablename__ = "audit_events"

    id          = Column(BigInteger, primary_key=True, autoincrement=True)
    occurred_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    actor_id    = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    actor_ip    = Column(INET, nullable=True)
    request_id  = Column(String(36), nullable=True)      # joins to the log stream
    action      = Column(String(64), nullable=False)      # project.target_changed
    entity_type = Column(String(40), nullable=False)
    entity_id   = Column(UUID(as_uuid=True), nullable=False)
    before      = Column(JSONB, nullable=True)
    after       = Column(JSONB, nullable=True)

    __table_args__ = (
        Index("ix_audit_entity", "entity_type", "entity_id", "occurred_at"),
        Index("ix_audit_actor",  "actor_id", "occurred_at"),
    )
```

```
# app/core/audit.py  (new) — automatic, so no handler can forget
AUDITED = {Project, Chama, ChamaMember, Contribution, User, Budget}

@event.listens_for(Session, "before_flush")
def capture_changes(session, flush_context, instances):
    ctx = request_context.get()          # actor_id, ip, request_id from middleware
    for obj in session.dirty:
        if type(obj) not in AUDITED or not session.is_modified(obj):
            continue
        state = inspect(obj)
        before, after = {}, {}
        for attr in state.attrs:
            hist = attr.load_history()
            if hist.has_changes():
                before[attr.key] = _safe(hist.deleted[0] if hist.deleted else None)
                after[attr.key]  = _safe(hist.added[0] if hist.added else None)
        if after:
            session.add(AuditEvent(
                actor_id=ctx.user_id, actor_ip=ctx.ip, request_id=ctx.request_id,
                action=f"{obj.__tablename__}.updated",
                entity_type=obj.__tablename__, entity_id=obj.id,
                before=before, after=after,
            ))
```

```
# app/models/compliance.py  (new)
class KycProfile(Base):
    __tablename__ = "kyc_profiles"
    user_id        = Column(UUID(as_uuid=True), ForeignKey("users.id"), primary_key=True)
    tier           = Column(SAEnum(KycTier), nullable=False, default=KycTier.TIER0)
    id_type        = Column(SAEnum(IdDocumentType), nullable=True)
    id_number_hash = Column(String(64), nullable=True, index=True)   # hashed, not stored raw
    date_of_birth  = Column(Date, nullable=True)
    verified_at    = Column(DateTime(timezone=True), nullable=True)
    verified_by    = Column(String(40), nullable=True)               # provider name
    screening_status = Column(SAEnum(ScreeningStatus), nullable=False,
                              default=ScreeningStatus.PENDING)

# tier limits, enforced in the contribution path
TIER_LIMITS = {                    # (per transaction, per rolling 24h) in KES
    KycTier.TIER0: (Decimal("5000"),   Decimal("20000")),
    KycTier.TIER1: (Decimal("70000"),  Decimal("150000")),
    KycTier.TIER2: (Decimal("300000"), Decimal("1000000")),
}

class ConsentRecord(Base):
    __tablename__ = "consent_records"
    id             = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id        = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    policy         = Column(String(40), nullable=False)   # terms | privacy | data_sharing
    policy_version = Column(String(20), nullable=False)   # what they actually agreed to
    granted        = Column(Boolean, nullable=False)
    ip             = Column(INET, nullable=True)
    user_agent     = Column(String(255), nullable=True)
    recorded_at    = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
```

**Expected benefits**

Regulatory: moves from "cannot begin a licensing conversation" to a defensible baseline — auditable history, tiered customer identification, provable consent and a stated retention schedule. Security: the audit stream is also the detection surface for insider misuse. Support: member disputes become answerable from data rather than from memory. Because it is implemented as a session hook, coverage does not depend on developers remembering.

## 5. High-severity findings (P1)

### PERF-01 — Blocking synchronous ORM calls inside `async def` handlers

`P1 · HIGH`

backend/app/database.py · routers/payments.py

**Current implementation**

The engine is the synchronous `create_engine` with `psycopg2`, `pool_size=10, max_overflow=20`. Most handlers are correctly declared `def`, which FastAPI runs in a threadpool — but the two payment handlers and both callbacks are `async def` and call `db.query(...)`, `db.commit()` and `db.refresh()` directly.

**Problem**

A blocking socket read inside a coroutine stalls the entire event loop — not just that request. The single worst instance is `contribute_mpesa`: it blocks the loop on three DB round trips, then awaits an STK push that can take 15 seconds. During that await other coroutines do proceed, but each of their DB calls re-blocks the loop. The effective concurrency of the whole process collapses toward serial execution precisely on the hottest path. The mixed model is also a correctness hazard: 10 pool connections shared by a threadpool of 40 means requests silently queue on connection checkout under load.

**Risk**

Throughput far below what the hardware can deliver, and a latency profile that degrades non-linearly: at a few hundred concurrent payment initiations, p99 goes to tens of seconds and the mobile client's 3-second poll interval turns one user's stall into sustained extra load. This is the primary reason the service cannot meet the stated 5k-concurrent target.

**Recommended refactor**

Move to fully async I/O: `asyncpg` + `AsyncSession`, one shared `httpx.AsyncClient` instead of constructing one per call, and a lint rule forbidding sync sessions in async functions. Pool sizing must be computed from replica count against the Postgres connection ceiling, with PgBouncer in transaction mode in front.

**Code changes**

```
# app/database.py — before
engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True,
                       pool_size=10, max_overflow=20)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# after
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker

engine = create_async_engine(
    settings.DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://"),
    pool_pre_ping=True,
    pool_size=20, max_overflow=10,        # 30 max × 8 replicas = 240 < PgBouncer pool
    pool_recycle=1800,
    pool_timeout=5,                       # fail fast rather than queue forever
    connect_args={"server_settings": {"jit": "off",
                                      "application_name": "changa-api"},
                  "command_timeout": 10},
)
SessionLocal = async_sessionmaker(engine, expire_on_commit=False, autoflush=False)

async def get_session() -> AsyncIterator[AsyncSession]:
    async with SessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
```

```
# app/services/http.py  (new) — one pooled client, not one per request
_client: httpx.AsyncClient | None = None

def get_http_client() -> httpx.AsyncClient:
    global _client
    if _client is None:
        _client = httpx.AsyncClient(
            timeout=httpx.Timeout(connect=3.0, read=10.0, write=5.0, pool=2.0),
            limits=httpx.Limits(max_connections=100, max_keepalive_connections=20),
            http2=True,
        )
    return _client
# before: `async with httpx.AsyncClient() as client:` inside every call —
# a fresh TCP+TLS handshake per request, ~150ms of avoidable latency each.
```

**Expected benefits**

Performance: 5–10× throughput per worker on I/O-bound endpoints, and elimination of the event-loop stalls that cause tail-latency spikes. Removing per-call client construction saves roughly 100–150 ms of TLS handshake on every provider call. Scalability: connection budgeting becomes explicit, which is the precondition for horizontal scaling.

### PERF-02 — Aggregates are computed by hydrating entire relationship collections into Python

`P1 · HIGH`

models/models.py properties · routers/projects.py · routers/chamas.py · routers/budgets.py

**Current implementation**

Model properties compute sums and counts by iterating lazily-loaded collections. Every one is a hidden query that runs during response serialisation:

```
Chama.member_count           → len(self.members)              # loads all members
Chama.active_project_count   → sum(1 for p in self.projects…)  # loads all projects
Project.contributor_count    → len(set(c.user_id for c in self.contributions…))
Budget.total_allocated       → sum(c.allocated_amount for c in self.categories)
BudgetCategory.progress      → touches every expense row

# routers/chamas.py::list_my_chamas — N+1 by construction
memberships = db.query(ChamaMember).filter(...).all()
chamas = [m.chama for m in memberships if m.chama.is_active]   # 1 query per row

# routers/payments.py::my_contributions — unbounded, sorted in Python
sorted(current_user.contributions, key=lambda x: x.initiated_at, reverse=True)

# routers/projects.py::get_contributors — loads every contribution AND every user
for c in successful: contributors[uid]["full_name"] = c.user.full_name
```

**Problem**

These are O(rows) in both queries and memory where the answer is a single scalar the database could compute in an index scan. The cost is invisible in development and catastrophic at volume: a successful project with 100,000 contributions makes `GET /projects/{id}` load 100,000 ORM objects to produce one integer, and `/projects/{id}/contributors` additionally issues one query per contributor for the user's name. `list_my_chamas` executes 1 + 2N queries for N memberships. `my_contributions` has no pagination at all, so a heavy user's request grows without bound.

**Risk**

Worker OOM and database saturation triggered by the platform's own success — the more popular a project, the more likely its detail page takes the service down. Because Python-side serialisation holds every object at once, a handful of concurrent requests to a large project is enough to exhaust a container's memory limit.

**Recommended refactor**

Delete the collection-walking properties. Compute aggregates in SQL as correlated subqueries or explicit joins, load them onto the response schema rather than the model, and use `selectinload`/`joinedload` for genuine collection needs. Set `lazy="raise"` on every relationship so an accidental lazy load fails loudly in tests instead of silently in production.

**Code changes**

```
# app/models/models.py — make accidental lazy loads impossible
members  = relationship("ChamaMember", back_populates="chama", lazy="raise")
projects = relationship("Project",     back_populates="chama", lazy="raise")
# and delete member_count / active_project_count / contributor_count /
# total_allocated / total_spent / progress — every one of them.
```

```
# app/repositories/chama_repository.py  (new) — 1 query, not 1 + 2N
async def list_for_user(session: AsyncSession, user_id: UUID) -> list[ChamaSummary]:
    member_count = (
        select(func.count()).select_from(ChamaMember)
        .where(ChamaMember.chama_id == Chama.id)
        .correlate(Chama).scalar_subquery()
    )
    active_projects = (
        select(func.count()).select_from(Project)
        .where(Project.chama_id == Chama.id,
               Project.status == ProjectStatus.ACTIVE)
        .correlate(Chama).scalar_subquery()
    )
    rows = await session.execute(
        select(Chama, member_count.label("member_count"),
                      active_projects.label("active_project_count"))
        .join(ChamaMember, ChamaMember.chama_id == Chama.id)
        .where(ChamaMember.user_id == user_id, Chama.is_active.is_(True))
        .order_by(Chama.created_at.desc())
    )
    return [ChamaSummary.from_row(r) for r in rows]
```

```
# contributors: one grouped query instead of N+1 over users
async def contributor_breakdown(session, project_id: UUID, anonymous: bool):
    total = select(func.sum(Contribution.amount)).where(
        Contribution.project_id == project_id,
        Contribution.status == ContributionStatus.SUCCESS,
    ).scalar_subquery()

    stmt = (
        select(
            Contribution.user_id,
            User.full_name if not anonymous else literal(None).label("full_name"),
            func.sum(Contribution.amount).label("total"),
            func.count().label("contributions"),
            (func.sum(Contribution.amount) * 100 / func.nullif(total, 0))
                .label("percentage"),
        )
        .join(User, User.id == Contribution.user_id)
        .where(Contribution.project_id == project_id,
               Contribution.status == ContributionStatus.SUCCESS)
        .group_by(Contribution.user_id, User.full_name)
        .order_by(func.sum(Contribution.amount).desc())
        .limit(100)                                  # bounded response
    )
    return (await session.execute(stmt)).all()
```

**Expected benefits**

Performance: project-detail and chama-list responses become O(1) in query count and constant in memory regardless of history size — for a project with 100k contributions this is the difference between a multi-second, several-hundred-megabyte response and a sub-10 ms index scan. Reliability: removes the most likely cause of worker OOM. Maintainability: `lazy="raise"` converts a category of latent performance bug into a test failure.

### PERF-03 — Missing composite indexes, CHECK constraints and cascade rules; a delete path that will 500

`P1 · HIGH`

backend/app/models/models.py · routers/projects.py::delete_project · routers/chamas.py::join_chama

**Current implementation**

Every foreign key has a single-column index, which is good, but there are no composite indexes for the actual access patterns, no unique constraint on `(chama_id, user_id)` in `chama_members`, no `CHECK` constraints on any amount, and no `ondelete` on most FKs. `Project.contributions` has no cascade while `delete_project` calls `db.delete(project)`. `join_chama` checks for existing membership with a SELECT then INSERTs.

**Problem**

Four concrete defects. *(1)* `DELETE /projects/{id}` raises `IntegrityError` → unhandled 500 as soon as the project has a single contribution, because SQLAlchemy will attempt to null a non-nullable FK. A project that has taken money must not be deletable anyway — it should be cancelled. *(2)* The check-then-insert in `join_chama` is a TOCTOU race: two simultaneous joins both pass the check and create duplicate memberships, which then double-count `member_count` and grant two votes' worth of access. Only a unique constraint fixes this. *(3)* No `CHECK (amount > 0)` means a bug or a crafted payload can insert a zero or negative contribution and reduce a project's total. *(4)* Every real query filters on two columns — `(project_id, status)`, `(chama_id, status)`, `(user_id, initiated_at)` — and gets a bitmap-and of two single-column indexes plus a sort instead of one ordered index scan.

**Risk**

A guaranteed 500 on a normal user action; duplicate memberships that corrupt governance and counts; unbounded query cost growth as tables grow. Constraints are also the last line of defence for financial invariants — without them, every future bug can reach the balance sheet.

**Recommended refactor**

Declare the invariants in the schema, index for the real access paths, and replace hard deletion of financial entities with a status transition plus soft delete.

**Code changes**

```
# alembic/versions/00X_constraints_and_indexes.py  (new)
def upgrade() -> None:
    # one membership per (chama, user) — closes the join race
    op.create_unique_constraint("uq_chama_member", "chama_members",
                               ["chama_id", "user_id"])

    # financial invariants the database itself enforces
    op.create_check_constraint("ck_contribution_amount_positive",
                               "contributions", "amount > 0")
    op.create_check_constraint("ck_project_target_positive",
                               "projects", "target_amount > 0")
    op.create_check_constraint("ck_project_raised_non_negative",
                               "projects", "raised_amount >= 0")
    op.create_check_constraint("ck_category_allocated_non_negative",
                               "budget_categories", "allocated_amount >= 0")

    # composite indexes matching the actual predicates
    op.create_index("ix_contributions_project_status",
                    "contributions", ["project_id", "status"])
    op.create_index("ix_contributions_user_initiated",
                    "contributions", ["user_id", sa.text("initiated_at DESC")])
    op.create_index("ix_projects_chama_status_created",
                    "projects", ["chama_id", "status", sa.text("created_at DESC")])
    op.create_index("ix_chama_members_user", "chama_members", ["user_id", "chama_id"])

    # partial index for the reconciliation sweep — tiny, and stays tiny
    op.execute("""CREATE INDEX ix_contributions_pending
                  ON contributions (initiated_at)
                  WHERE status = 'pending'""")

    # full-text search for the projects feed (API-01)
    op.execute("""ALTER TABLE projects ADD COLUMN search_vector tsvector
                  GENERATED ALWAYS AS (
                    to_tsvector('simple', coalesce(title,'') || ' ' ||
                                          coalesce(description,''))
                  ) STORED""")
    op.execute("CREATE INDEX ix_projects_search ON projects USING GIN (search_vector)")
```

```
# routers/projects.py — before: 500s on any project with contributions
@router.delete("/{project_id}", status_code=204)
def delete_project(...):
    db.delete(project); db.commit()

# after: financial records are never destroyed
@router.delete("/{project_id}", status_code=204)
async def cancel_project(project_id: UUID, ...):
    project = await get_owned_project(session, project_id, user)
    has_money = await session.scalar(
        select(func.count()).select_from(Contribution)
        .where(Contribution.project_id == project_id,
               Contribution.status == ContributionStatus.SUCCESS)
    )
    if has_money:
        project.status = ProjectStatus.CANCELLED       # auditable, reversible
    else:
        project.deleted_at = func.now()                # soft delete
    await session.commit()
```

```
# routers/chamas.py — let the constraint decide, not a prior SELECT
stmt = (
    insert(ChamaMember)
    .values(chama_id=chama.id, user_id=user.id, role=ChamaMemberRole.MEMBER)
    .on_conflict_do_nothing(constraint="uq_chama_member")
    .returning(ChamaMember.id)
)
if (await session.execute(stmt)).scalar_one_or_none() is None:
    raise HTTPException(409, "You are already a member of this Chama")
```

**Expected benefits**

Reliability: removes a deterministic 500 and a data-corrupting race. Performance: composite and partial indexes turn multi-predicate scans into single ordered index scans — typically 10–50× on the contributions table at scale, and the reconciliation sweep stays constant-time as history grows. Regulatory: financial records become non-destructible by design.

### PERF-04 · PERF-05 — Unbounded list responses, offset pagination, and no cache or worker tier

`P1 · HIGH`

routers/budgets.py · routers/chamas.py · routers/payments.py · requirements.txt

**Current implementation**

`GET /budgets`, `GET /chamas`, `GET /chamas/{id}/members` and `GET /users/me/contributions` return complete result sets with no limit. `GET /chamas/{id}/projects` paginates with `page`/`page_size`, unvalidated, plus a separate `COUNT(*)` per request. There is no Redis, no Celery/ARQ, and no scheduled job anywhere in the stack.

**Problem**

Response size is controlled by the client's data, not by the API — a user with 3,000 contributions gets all 3,000, serialised through Pydantic, on a mobile connection. `page_size` is unbounded, so `?page_size=100000` is a denial-of-service primitive. Offset pagination re-scans and discards `OFFSET` rows on every page, so deep pages get progressively slower, and rows shift between pages when new projects are created mid-scroll. The absence of a worker tier is why PAY-03's outbox, the reconciliation sweep, FIN-02's nightly control, receipts and notifications have nowhere to run.

**Risk**

Trivially triggered resource exhaustion, degrading UX as accounts age, and — most importantly — no place to put the asynchronous work that the payments fixes require. Without Redis there is also no rate limiter (SEC-03) and no token deny-list (SEC-01), so this finding blocks two P0 remediations.

**Recommended refactor**

A single generic keyset-paginated envelope for every collection endpoint, with a server-enforced maximum. Add Redis (cache + rate limits + deny-list) and ARQ (async-native, lighter than Celery for this workload) with a scheduler for the periodic controls. Cache only what is safe: never a balance, only slow-changing reference data, keyed and explicitly invalidated.

**Code changes**

```
# app/schemas/pagination.py  (new) — one envelope, every list endpoint
class CursorPage(BaseModel, Generic[T]):
    items: list[T]
    next_cursor: str | None = None
    has_more: bool = False

    @classmethod
    def build(cls, rows: Sequence[Any], limit: int) -> "CursorPage[T]":
        has_more = len(rows) > limit
        page = list(rows[:limit])
        return cls(items=page, has_more=has_more,
                   next_cursor=encode_cursor(page[-1]) if has_more and page else None)

# every list endpoint signature becomes:
limit: int = Query(20, ge=1, le=100)     # server decides the ceiling, not the client
cursor: str | None = None
```

```
# requirements.txt — additions
redis[hiredis]==5.2.1
arq==0.26.3                      # async task queue + cron scheduler
asyncpg==0.30.0
structlog==24.4.0
slowapi==0.1.9
opentelemetry-instrumentation-fastapi==0.50b0
prometheus-client==0.21.1
bcrypt==4.2.1                    # was 4.0.1

# app/workers/settings.py  (new)
class WorkerSettings:
    functions = [process_provider_callback, initiate_payment, send_receipt]
    cron_jobs = [
        cron(reconcile_pending,   second={0, 30}),          # PAY-03 safety net
        cron(verify_ledger_totals, hour=2, minute=0),       # FIN-02 control
        cron(purge_expired_tokens, hour=3, minute=0),       # SEC-01 hygiene
    ]
    max_jobs = 20
    job_timeout = 60
    retry_jobs = True
    max_tries = 5                # exponential backoff between attempts
```

**Expected benefits**

Performance: bounded, constant-cost responses; deep pagination stops degrading; payload sizes on mobile networks drop by an order of magnitude for heavy accounts. Scalability: unblocks the worker-dependent P0 fixes and lets read-heavy reference data be cached. Reliability: periodic controls give the system a self-healing loop it currently lacks entirely.

### SEC-04 · SEC-05 — Wildcard CORS, no security middleware, and a cleartext LAN base URL in the shipping app

`P1 · HIGH`

backend/app/main.py · core/config.py · mobile/.../api_constants.dart

**Current implementation**

```
# main.py — the only middleware in the application
app.add_middleware(CORSMiddleware,
    allow_origins=["*"] if settings.DEBUG else settings.ALLOWED_HOSTS,
    allow_credentials=False if settings.DEBUG else True,
    allow_methods=["*"], allow_headers=["*"])

# config.py
ALLOWED_HOSTS: List[str] = ["*"]        # ← the production default is a wildcard

// api_constants.dart
static const String baseUrl = 'http://192.168.1.193:8000';   // cleartext, LAN
```

**Problem**

The `ALLOWED_HOSTS` default is `["*"]`, so a deployment that simply forgets the environment variable runs with credentialed wildcard CORS — a configuration browsers reject outright, which means it will either fail confusingly or be "fixed" by loosening something else. There is no `TrustedHostMiddleware` (so Host-header injection can poison absolute URLs), no HTTPS redirect, no HSTS, no `X-Content-Type-Options`, and no request-size limit — `/docs` and `/redoc` are also unconditionally public, publishing the full internal API surface. On the client, the base URL is a hardcoded private IP over plain HTTP: every token, phone number and amount crosses the network in the clear, there is no per-environment configuration, and there is no certificate pinning — so even after moving to HTTPS the app remains trivially interceptable with a user-installed CA.

**Risk**

Full credential interception on any hostile network — which, for the target market, means most public Wi-Fi. The app as configured cannot function outside one developer's LAN, so this also blocks release. Android 9+ and iOS ATS will reject the cleartext connection anyway unless the project has explicitly weakened its network security config, which is itself a finding.

**Recommended refactor**

Fail closed on configuration: no wildcard default, and a validator that refuses to boot in production with permissive settings. Add the standard middleware stack. On the client, resolve the base URL from a build-time environment (`--dart-define`) with HTTPS enforced, and pin the certificate's public-key hash with a backup pin so rotation does not brick the app.

**Code changes**

```
# app/core/config.py — refuse to start in an unsafe configuration
class Settings(BaseSettings):
    ENVIRONMENT: Literal["local", "staging", "production"] = "local"
    ALLOWED_ORIGINS: list[AnyHttpUrl] = []          # no wildcard default
    ALLOWED_HOSTS: list[str] = ["localhost"]

    @model_validator(mode="after")
    def _production_is_strict(self):
        if self.ENVIRONMENT == "production":
            if self.DEBUG:
                raise ValueError("DEBUG must be false in production")
            if "*" in self.ALLOWED_HOSTS or not self.ALLOWED_ORIGINS:
                raise ValueError("Explicit hosts and origins are required")
            if len(self.SECRET_KEY) < 32:
                raise ValueError("SECRET_KEY must be at least 32 bytes")
        return self
```

```
# app/main.py — full stack, ordered outermost → innermost
app = FastAPI(
    title=settings.APP_NAME, version="1.0.0",
    docs_url=None if settings.ENVIRONMENT == "production" else "/docs",
    redoc_url=None if settings.ENVIRONMENT == "production" else "/redoc",
    openapi_url=None if settings.ENVIRONMENT == "production" else "/openapi.json",
)
app.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.ALLOWED_HOSTS)
if settings.ENVIRONMENT != "local":
    app.add_middleware(HTTPSRedirectMiddleware)
app.add_middleware(SecurityHeadersMiddleware)     # HSTS, nosniff, frame-deny
app.add_middleware(RequestContextMiddleware)      # OBS-01
app.add_middleware(BodySizeLimitMiddleware, max_bytes=1_048_576)
app.add_middleware(RateLimitMiddleware)           # SEC-03
app.add_middleware(CORSMiddleware,
    allow_origins=[str(o) for o in settings.ALLOWED_ORIGINS],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
    allow_headers=["Authorization", "Content-Type", "Idempotency-Key",
                   "X-Request-Id"],
    max_age=600)
```

```
// mobile: lib/core/config/env.dart  (new)
class Env {
  static const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
  static const baseUrl = String.fromEnvironment('API_BASE_URL');
  static const pinnedSpkiSha256 = String.fromEnvironment('API_SPKI_PIN');
  static const backupSpkiSha256 = String.fromEnvironment('API_SPKI_PIN_BACKUP');

  static void assertValid() {
    assert(baseUrl.startsWith('https://'), 'API_BASE_URL must be HTTPS');
  }
}
// build:  flutter build apk --dart-define=API_BASE_URL=https://api.changa.co.ke \
//           --dart-define=API_SPKI_PIN=...   (no URL is ever committed)
```

```
// api_client.dart — public-key pinning with a rotation-safe backup pin
final adapter = IOHttpClientAdapter(createHttpClient: () {
  final client = HttpClient(context: SecurityContext(withTrustedRoots: true));
  client.badCertificateCallback = (_, __, ___) => false;   // never bypass
  return client;
});
_dio.httpClientAdapter = adapter;
_dio.interceptors.add(CertificatePinInterceptor(
  pins: {Env.pinnedSpkiSha256, Env.backupSpkiSha256},      // two pins, always
));
```

**Expected benefits**

Security: eliminates plaintext credential exposure and raises the bar on interception from "install a CA" to "compromise the pinned key". Reliability: a misconfigured deployment fails at boot instead of serving traffic insecurely. Operability: per-flavour builds make staging and production separable, which is currently impossible.

### SEC-06 — Mass assignment: update handlers `setattr` whatever the payload contains

`P1 · HIGH`

routers/projects.py · routers/chamas.py · routers/budgets.py

**Current implementation**

```
for field, value in payload.model_dump(exclude_unset=True).items():
    setattr(project, field, value)        # identical in update_chama, update_budget
```

**Problem**

The write surface is defined implicitly by whatever fields happen to be on the request schema, and there is no allowlist at the point of mutation. Today the schemas may be narrow; the risk is that this pattern makes every future schema addition a potential privilege escalation with no code change at the mutation site to review. If `raised_amount`, `status`, `owner_id`, `chama_id` or `total_income` ever appears on an update schema — including by inheriting from a create schema, the most common refactor in this codebase's style — a user immediately gains the ability to set their own funding total or move a project between chamas. There is also no state-machine validation: nothing prevents `status` going from `completed` back to `active`, or a target being lowered below the amount already raised.

A latent privilege-escalation path that will open silently the next time someone reuses a schema, and no protection against illegal state transitions on money-bearing records. Both are the kind of defect that is cheap to prevent structurally and expensive to find by review.

**Recommended refactor**

Explicit field allowlists at the mutation site, a validated state machine for status changes, and business invariants asserted before commit. The handler should name every field it is willing to write.

**Code changes**

```
# app/services/project_service.py  (new)
MUTABLE_BY_OWNER = frozenset({
    "title", "description", "cover_image_url", "deadline",
    "target_amount", "is_anonymous", "payment_name",
})   # deliberately excludes raised_amount, status, owner_id, chama_id

ALLOWED_TRANSITIONS = {
    ProjectStatus.ACTIVE:    {ProjectStatus.PAUSED, ProjectStatus.COMPLETED,
                              ProjectStatus.CANCELLED},
    ProjectStatus.PAUSED:    {ProjectStatus.ACTIVE, ProjectStatus.CANCELLED},
    ProjectStatus.COMPLETED: set(),          # terminal
    ProjectStatus.CANCELLED: set(),          # terminal
}

async def update_project(session, project: Project, patch: ProjectUpdateRequest,
                         actor: User) -> Project:
    changes = patch.model_dump(exclude_unset=True)

    if rejected := set(changes) - MUTABLE_BY_OWNER:
        raise HTTPException(422, f"Fields not editable: {sorted(rejected)}")

    if "target_amount" in changes:
        raised = await current_raised(session, project.id)
        if changes["target_amount"] < raised:
            raise HTTPException(
                422, "Target cannot be below the amount already raised")

    for field, value in changes.items():
        setattr(project, field, value)       # now provably bounded
    return project

async def transition_status(session, project: Project,
                            target: ProjectStatus, actor: User) -> None:
    if target not in ALLOWED_TRANSITIONS[project.status]:
        raise HTTPException(
            409, f"Cannot move a {project.status.value} project to {target.value}")
    project.status = target       # audited automatically via the REG-01 hook
```

**Expected benefits**

Security: the writable surface becomes explicit and reviewable, so schema changes can no longer widen it by accident. Reliability: illegal state transitions and self-inconsistent targets become impossible. Maintainability: business rules move out of routers into a service that can be unit-tested without HTTP.

### SEC-07 · SEC-08 — Client-side hardening absent; weak password policy and no MFA path

`P1 · HIGH`

mobile: auth_provider.dart, api_client.dart, main.dart · backend: schemas/auth.py, core/security.py

**Current implementation**

Tokens are stored in `FlutterSecureStorage` with `encryptedSharedPreferences: true` — correct, and the strongest security decision in the mobile codebase. Beyond that there is nothing: no root/jailbreak detection, no biometric gate, no `FLAG_SECURE` screenshot protection on payment screens, no clipboard hygiene for the invite code and phone fields, no inactivity timeout, and `clearTokens()` calls `_storage.deleteAll()`, wiping unrelated keys. Session state is traced with `print()`, which persists in release builds and lands in `logcat`. Server-side, the password rule is 8 characters with one letter and one digit, `ChangePasswordRequest` enforces only length, bcrypt runs at library-default cost, and there is no MFA, OAuth or device-management surface at all. `is_verified` is never set, so phone ownership — the identity anchor for a mobile-money product — is never proven.

**Problem**

A compromised or rooted device yields the full session with no additional friction, and a shoulder-surfer or screen recorder captures amounts and phone numbers. `print()` in release is a real leak channel: any app with log access on older Android, and any crash-report bundle, carries session state. On the server, "8 characters, one digit" admits `password1` — combined with no rate limiting (SEC-03) and no MFA, a single leaked credential list is sufficient for mass takeover. Unverified phone numbers mean the STK push target is asserted by the user rather than proven, which is both a fraud vector and an AML gap.

**Risk**

Account takeover on lost, shared or rooted devices — and device sharing is common in the target market. Regulatory expectations for a payments app include step-up authentication on sensitive actions; none exists, so high-value operations are protected by nothing more than a 30-minute bearer token.

**Recommended refactor**

On the client: biometric re-authentication before payment and profile changes, integrity checks that degrade rather than block (warn, disable high-value actions, report), `FLAG_SECURE` on payment and invite screens, clipboard clearing after a timeout, a 5-minute inactivity lock, scoped key deletion, and no logging in release. On the server: raise the password floor to 12 characters with a breach-list check, bcrypt cost 12 explicitly, TOTP-based MFA with the enrolment tables in place from day one, and SMS OTP verification of the phone number at registration so `is_verified` means something.

**Code changes**

```
// mobile: api_client.dart — before: destroys keys it does not own
Future<void> clearTokens() async {
  await _storage.deleteAll();
}
// after: delete only what this class wrote
Future<void> clearTokens() async {
  await Future.wait([
    _storage.delete(key: AppConstants.accessTokenKey),
    _storage.delete(key: AppConstants.refreshTokenKey),
  ]);
}
```

```
// mobile: lib/core/security/guarded_action.dart  (new)
// step-up authentication in front of anything that moves money
Future<bool> requireBiometric(String reason) async {
  final auth = LocalAuthentication();
  if (!await auth.canCheckBiometrics) return true;      // graceful on old devices
  return auth.authenticate(
    localizedReason: reason,
    options: const AuthenticationOptions(
      biometricOnly: false, stickyAuth: true, useErrorDialogs: true),
  );
}

// payment_screen.dart
onPressed: () async {
  if (!await requireBiometric('Confirm this contribution')) return;
  await ref.read(paymentInitProvider.notifier).pay(...);
}
```

```
// mobile: payment_screen.dart / invite_code_sheet.dart — block capture
@override
void initState() {
  super.initState();
  ScreenProtector.preventScreenshotOn();     // FLAG_SECURE / iOS obscuring
}
@override
void dispose() {
  ScreenProtector.preventScreenshotOff();
  super.dispose();
}

// clipboard hygiene after copying an invite code
await Clipboard.setData(ClipboardData(text: code));
Timer(const Duration(seconds: 60), () async {
  final current = await Clipboard.getData('text/plain');
  if (current?.text == code) await Clipboard.setData(const ClipboardData(text: ''));
});
```

```
# backend: app/schemas/auth.py — meaningful policy, shared by both flows
MIN_PASSWORD_LENGTH = 12

def validate_password_strength(v: str) -> str:
    if len(v) < MIN_PASSWORD_LENGTH:
        raise ValueError(f"Password must be at least {MIN_PASSWORD_LENGTH} characters")
    classes = sum(bool(re.search(p, v)) for p in
                  (r"[a-z]", r"[A-Z]", r"\d", r"[^\w\s]"))
    if classes < 3:
        raise ValueError("Use at least three of: lowercase, uppercase, digit, symbol")
    if is_breached(v):                      # k-anonymity lookup, cached locally
        raise ValueError("This password has appeared in a known breach")
    return v

# ChangePasswordRequest now uses the SAME validator — before, it checked
# only length, so users could downgrade to a weak password after signup.
```

```
# backend: app/core/security.py — explicit, tunable cost
BCRYPT_ROUNDS = 12                # pin it; do not inherit the library default

def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(),
                         bcrypt.gensalt(rounds=BCRYPT_ROUNDS)).decode()

def needs_rehash(hashed: str) -> bool:
    return int(hashed.split("$")[2]) < BCRYPT_ROUNDS   # transparent upgrade on login
```

```
# backend: app/models/auth.py — MFA and device tables, present from day one
class MfaFactor(Base):
    __tablename__ = "mfa_factors"
    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id     = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    kind        = Column(SAEnum(MfaKind), nullable=False)      # totp | sms
    secret_enc  = Column(LargeBinary, nullable=False)          # envelope-encrypted
    confirmed_at = Column(DateTime(timezone=True), nullable=True)
    __table_args__ = (UniqueConstraint("user_id", "kind", name="uq_mfa_user_kind"),)

class Device(Base):
    __tablename__ = "devices"
    id           = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id      = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    label        = Column(String(80), nullable=True)     # "Amina's Pixel 7"
    platform     = Column(String(20), nullable=False)
    last_seen_at = Column(DateTime(timezone=True), nullable=True)
    last_seen_ip = Column(INET, nullable=True)
    trusted      = Column(Boolean, nullable=False, server_default="false")

class LoginAttempt(Base):        # login history, required for dispute handling
    __tablename__ = "login_attempts"
    id         = Column(BigInteger, primary_key=True, autoincrement=True)
    email      = Column(String(255), nullable=False, index=True)
    user_id    = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    successful = Column(Boolean, nullable=False)
    ip         = Column(INET, nullable=True)
    user_agent = Column(String(255), nullable=True)
    at         = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
```

**Expected benefits**

Security: device compromise no longer equals account compromise; sensitive screens stop leaking to screenshots and logs; credential stuffing loses its payload. Regulatory: step-up authentication, device visibility and login history are all explicit expectations for a payments application, and the MFA tables mean enabling it later is a feature flag rather than a migration of live accounts.

### REL-01 · REL-02 — The deployment cannot be highly available, and provider calls have no resilience policy

`P1 · HIGH`

docker-compose.yml · backend/Dockerfile · services/mpesa.py · services/airtel.py

**Current implementation**

The compose file — the only deployment definition in the repository — runs a single API container with `--reload`, mounts the source tree as a volume, and includes pgAdmin exposed on `:5050` with `admin@changa.co.ke / admin` and Postgres published on `:5432` with `postgres/postgres`. The Dockerfile runs as root, keeps `gcc` in the final image, and starts a single-process uvicorn. Provider calls use bare `httpx` with a timeout and `raise_for_status()`, no retry, no backoff, no circuit breaker; the OAuth token is re-fetched on every single `stk_push`.

**Problem**

There is no path from this topology to high availability: one replica means every deploy is an outage, `--reload` watches the filesystem and will restart on any write, and the `create_all` race (DB-01) prevents simply raising the replica count. Root plus build tools in the runtime image widens the blast radius of any RCE. Default-credentialled pgAdmin adjacent to the production database is a direct compromise path. On the resilience side, fetching a fresh OAuth token per push doubles the latency of every payment and doubles the number of calls that can fail; a single Daraja 500 becomes a user-visible failure with no retry, while a Daraja slowdown propagates straight into request latency with no breaker to shed load.

**Risk**

Deploys are outages; a provider hiccup is an incident; a provider slowdown is a cascading failure that exhausts the connection pool and takes down endpoints unrelated to payments. With no worker separation, background load and user traffic also contend for the same process.

**Recommended refactor**

Multi-stage non-root image, gunicorn with uvicorn workers, migrations as a pre-deploy job, API and worker as separate deployments behind separate scaling policies, PgBouncer in transaction mode, and a rolling update with readiness gating. Wrap every outbound provider call in one resilience decorator: bounded exponential backoff with jitter, retry only on idempotent-safe conditions, a circuit breaker that fails fast when the provider is down, and a cached OAuth token refreshed slightly before expiry.

**Code changes**

```
# backend/Dockerfile — multi-stage, non-root, no compilers in the runtime
FROM python:3.12-slim AS builder
WORKDIR /build
RUN apt-get update && apt-get install -y --no-install-recommends gcc libpq-dev
COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

FROM python:3.12-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends libpq5 curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 10001 changa
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir --no-index --find-links=/wheels /wheels/* \
    && rm -rf /wheels
WORKDIR /app
COPY --chown=changa:changa ./app ./app
USER 10001
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=3s --retries=3 \
  CMD curl -fsS http://localhost:8000/ready || exit 1
CMD ["gunicorn", "app.main:app", "-k", "uvicorn.workers.UvicornWorker", \
     "-w", "4", "-b", "0.0.0.0:8000", "--graceful-timeout", "30", \
     "--timeout", "60", "--max-requests", "10000", "--max-requests-jitter", "1000"]
```

```
# app/services/resilience.py  (new) — one policy, every provider call
from tenacity import (retry, stop_after_attempt, wait_exponential_jitter,
                      retry_if_exception_type, before_sleep_log)

provider_call = retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential_jitter(initial=0.5, max=4),   # jitter avoids thundering herd
    retry=retry_if_exception_type((httpx.ConnectError, httpx.ReadTimeout,
                                   ProviderUnavailable)),
    reraise=True,
    before_sleep=before_sleep_log(log, logging.WARNING),
)

class CircuitBreaker:
    """Opens after `threshold` consecutive failures; probes after `cooldown`."""
    def __init__(self, name, threshold=5, cooldown=30):
        self.name, self.threshold, self.cooldown = name, threshold, cooldown
        self.failures, self.opened_at = 0, None

    def check(self):
        if self.opened_at and time.monotonic() - self.opened_at < self.cooldown:
            provider_circuit_open.labels(self.name).inc()
            raise ProviderUnavailable(f"{self.name} circuit open")   # fail fast

    def record(self, ok: bool):
        if ok:
            self.failures, self.opened_at = 0, None
        else:
            self.failures += 1
            if self.failures >= self.threshold:
                self.opened_at = time.monotonic()
                log.error("provider.circuit_opened", provider=self.name)
```

```
# app/services/mpesa.py — cache the OAuth token instead of refetching per push
_TOKEN_KEY = "mpesa:oauth_token"

async def get_access_token(redis) -> str:
    if cached := await redis.get(_TOKEN_KEY):
        return cached.decode()
    resp = await get_http_client().get(
        f"{settings.MPESA_BASE_URL}/oauth/v1/generate?grant_type=client_credentials",
        headers={"Authorization": f"Basic {_basic_credentials()}"},
    )
    resp.raise_for_status()
    body = resp.json()
    # refresh 60s early so a token never expires mid-flight
    await redis.setex(_TOKEN_KEY, int(body.get("expires_in", 3600)) - 60,
                      body["access_token"])
    return body["access_token"]

# before: every stk_push() called get_access_token(), i.e. two round trips
# to Safaricom per contribution instead of one.
```

**Expected benefits**

Availability: zero-downtime rolling deploys and horizontal scaling become possible; target 99.9% is reachable. Performance: token caching removes one full round trip to Safaricom from every contribution — roughly 200–400 ms off each initiation. Fault tolerance: transient provider errors are absorbed by retries instead of surfacing to users, and the breaker prevents a slow provider from exhausting the pool. Security: non-root, minimal runtime image, and no default-credentialled admin tool beside the database.

### MOB-01 · MOB-02 · MOB-03 — Refresh stampede, client-side fan-out aggregation, and raw exception text shown to users

`P1 · HIGH`

core/network/api_client.dart · all_projects_screen.dart · auth_provider.dart · project_provider.dart

**Current implementation**

The Dio `_AuthInterceptor.onError` refreshes tokens per failing request, with no coordination between concurrent 401s. `allChamaProjectsProvider` is a synchronous `Provider` that loops over the user's chamas calling `ref.watch(chamaProjectsProvider(chama.id))`, concatenates the results and sorts them. Error states are built with `AuthError(e.toString())` and `state.copyWith(error: e.toString())`, where `e` is a `Failure` subclass. Notifiers call `load()` from their constructors. `connectivity_plus` is a declared dependency but is not used anywhere.

**Problem**

Three distinct defects, all user-visible. *(a) Refresh stampede:* when an access token expires, several in-flight requests 401 together and each starts its own refresh. Since the server rotates and revokes on use (and, after SEC-01, treats reuse as theft), the first refresh succeeds and the rest present a consumed token — so they fail, hit `clearTokens()`, and the user is logged out at random. Post-SEC-01 this escalates from an annoyance to a family-wide revocation. *(b) Fan-out aggregation:* the projects screen issues one network request per chama, sequentially through provider initialisation, then sorts the entire dataset in Python-like fashion on every rebuild; there is no pagination, so a user in 10 chamas with 40 projects each holds 400 models in memory and the list re-sorts on any single chama's update. *(c) Raw error text:* `Failure` declares no `toString()` override, so `e.toString()` yields `Instance of 'ServerFailure'` — that string is what a user sees when login fails. The carefully written `message` field is never read. `AllProjectsScreen`'s `onRefresh` also does not await, so the pull-to-refresh spinner dismisses immediately.

Random logouts mid-payment — the worst possible moment — plus a browse screen that gets slower the more successful the user's chamas become, and error messaging that destroys credibility on first contact. Each is individually a plausible top-line retention issue.

**Recommended refactor**

Single-flight the refresh behind one shared `Completer` and queue the waiting requests. Replace the fan-out with the single server-side feed added in API-01, driven by an `AsyncNotifier` with cursor pagination. Introduce a presentation-mapping layer so the UI consumes user-safe messages, never exception text, and move initial loads out of constructors into `build`/`AsyncNotifier.build` so Riverpod controls lifecycle and retry.

**Code changes**

```
// api_client.dart — single-flight refresh; concurrent 401s share one attempt
class _AuthInterceptor extends Interceptor {
  Completer<String?>? _refreshing;          // null when idle

  Future<String?> _refreshOnce() {
    if (_refreshing != null) return _refreshing!.future;   // join the in-flight one
    final completer = Completer<String?>();
    _refreshing = completer;

    _performRefresh().then((token) {
      completer.complete(token);
    }).catchError((e) {
      completer.completeError(e);
    }).whenComplete(() {
      _refreshing = null;
    });
    return completer.future;
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || _isPublic(err.requestOptions.path)) {
      return handler.next(err);
    }
    if (err.requestOptions.extra['retried'] == true) {     // never loop
      return handler.next(err);
    }
    try {
      final token = await _refreshOnce();
      if (token == null) return handler.next(err);
      final opts = err.requestOptions
        ..headers['Authorization'] = 'Bearer $token'
        ..extra['retried'] = true;
      handler.resolve(await _client.dio.fetch(opts));
    } catch (_) {
      await _client.clearTokens();
      _onSessionExpired();               // one signal, not one per request
      handler.next(err);
    }
  }
}
```

```
// all_projects_screen.dart — before: N requests, unbounded, re-sorted per rebuild
final allChamaProjectsProvider = Provider<List<ProjectModel>>((ref) {
  final chamaState = ref.watch(chamaListProvider);
  final projects = <ProjectModel>[];
  for (final chama in chamaState.chamas) {
    projects.addAll(ref.watch(chamaProjectsProvider(chama.id)).projects);
  }
  projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return projects;
});

// after: one paginated server query (API-01), sorted and filtered in Postgres
@riverpod
class ProjectFeed extends _$ProjectFeed {
  @override
  Future<Paged<ProjectModel>> build({String? search, ProjectStatus? status}) {
    return ref.watch(projectsRepositoryProvider)
              .feed(search: search, status: status, limit: 20);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;
    final next = await ref.read(projectsRepositoryProvider)
                          .feed(cursor: current.nextCursor, limit: 20);
    state = AsyncData(current.append(next));      // append, never re-sort
  }
}
```

```
// core/errors/failures.dart — make Failure presentable, and never leak internals
sealed class Failure implements Exception {
  final String message;          // user-safe, already localisable
  final String? code;            // stable, for analytics and support
  const Failure(this.message, {this.code});

  @override
  String toString() => message;  // was missing: e.toString() gave
                                 // "Instance of 'ServerFailure'"
}

// auth_provider.dart — before
catch (e) { state = AuthError(e.toString()); }
// after
catch (e) { state = AuthError(e is Failure ? e.message : _genericMessage); }
```

```
// all_projects_screen.dart — the refresh indicator must await the work
onRefresh: () async {
  ref.read(chamaListProvider.notifier).refresh();      // before: not awaited,
},                                                     // spinner vanished at once
// after
onRefresh: () => ref.refresh(projectFeedProvider.future),
```

**Expected benefits**

Reliability: random logouts eliminated; token refresh becomes one request regardless of concurrency. Performance: the projects feed goes from N sequential requests and an unbounded in-memory sort to one paginated query — for a user in 8 chamas, roughly 8× fewer requests and constant memory. UX: real error messages, and a pull-to-refresh that reflects actual work.

### TEST-01 — No CI, SQLite substituted for Postgres, and no contract, concurrency or load tests

`P1 · HIGH`

backend/tests/ · mobile/changa/test/ · no workflow files in the repository

**Current implementation**

Two backend test files (`test_auth.py`, `test_projects.py`) run against `sqlite:///./test_changa.db` with `create_all`/`drop_all` per test, and the fixtures target the removed `POST /projects` route with a `visibility` field. There is one default Flutter widget test. There are no GitHub Actions workflows, no coverage threshold, no linting gate, and no dependency or secret scanning.

**Problem**

SQLite cannot express what this application depends on: it has no native UUID type, different enum semantics, no `NUMERIC` exactness guarantees, no `SELECT FOR UPDATE`, no `ON CONFLICT` on named constraints, no partial or GIN indexes, and different transaction isolation. Every remediation in this audit relies on at least one of those, so the current harness is structurally incapable of verifying the fixes. Because the fixtures also target dead routes, the suite is red today — which means its signal has already been abandoned, and API-01 shipped unnoticed as a direct result. With no CI, nothing runs even when it is green.

**Risk**

No regression protection on a system that moves money. In particular, the concurrency and idempotency properties introduced by FIN-02 and PAY-02 are exactly the kind of behaviour that silently regresses under refactoring and cannot be caught by review — only by a test that runs two callbacks in parallel against real Postgres.

**Recommended refactor**

Run tests against real Postgres in an ephemeral container (`testcontainers`), migrate with Alembic rather than `create_all` so migrations are themselves tested, and isolate tests with a transaction rollback per test instead of dropping tables. Add the test classes that matter for money: idempotency, concurrency, state machines, authorization matrices, and a recorded-cassette contract test per provider. Gate merges on lint, type-check, coverage floor and `alembic check`.

**Code changes**

```
# tests/conftest.py — real Postgres, real migrations, fast isolation
@pytest.fixture(scope="session")
def postgres_container():
    with PostgresContainer("postgres:16-alpine") as pg:
        yield pg

@pytest.fixture(scope="session")
async def engine(postgres_container):
    url = postgres_container.get_connection_url().replace(
        "postgresql+psycopg2", "postgresql+asyncpg")
    eng = create_async_engine(url)
    await run_migrations(url)          # exercises Alembic, not create_all
    yield eng
    await eng.dispose()

@pytest.fixture
async def session(engine):
    """Each test runs in a transaction that is rolled back — no drop_all."""
    async with engine.connect() as conn:
        trans = await conn.begin()
        async with AsyncSession(bind=conn, expire_on_commit=False) as s:
            yield s
        await trans.rollback()
```

```
# tests/test_payment_idempotency.py  (new) — the test that must never fail
async def test_duplicate_callback_credits_once(session, project, contribution):
    payload = mpesa_success_body(contribution.reference, amount=contribution.amount)

    await process_provider_callback(payload)
    await process_provider_callback(payload)      # provider retry
    await process_provider_callback(payload)      # and again

    raised = await session.scalar(
        select(Project.raised_amount).where(Project.id == project.id))
    entries = await session.scalar(
        select(func.count()).select_from(LedgerEntry)
        .where(LedgerEntry.contribution_id == contribution.id))

    assert raised == contribution.amount          # credited exactly once
    assert entries == 1

async def test_concurrent_callbacks_do_not_lose_updates(engine, project):
    """Two different contributions settling simultaneously must both count."""
    a, b = await make_pending(engine, project, "100.00"), \
           await make_pending(engine, project, "250.00")

    await asyncio.gather(
        process_provider_callback(mpesa_success_body(a.reference, "100.00")),
        process_provider_callback(mpesa_success_body(b.reference, "250.00")),
    )
    async with AsyncSession(engine) as s:
        raised = await s.scalar(select(Project.raised_amount)
                                .where(Project.id == project.id))
    assert raised == Decimal("350.00")            # fails today: lost update
```

```
# .github/workflows/ci.yml  (new)
name: CI
on: [push, pull_request]

jobs:
  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }
      - run: pip install -r requirements.txt -r requirements-dev.txt
      - run: ruff check app tests
      - run: mypy app --strict
      - run: alembic upgrade head && alembic check      # DB-01 drift gate
      - run: pytest --cov=app --cov-fail-under=75
      - run: |
          python -m app.tools.dump_openapi > openapi.json
          git diff --exit-code openapi.json               # API-01 contract gate
      - uses: aquasecurity/trivy-action@master            # image CVE scan
      - run: pip-audit
      - uses: gitleaks/gitleaks-action@v2                 # secret scan

  mobile:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter analyze
      - run: dart run custom_lint                        # riverpod_lint is configured
      - run: flutter test --coverage
```

**Expected benefits**

Testability: the harness becomes capable of verifying the properties the business depends on — exactly-once crediting, concurrency safety, authorization boundaries. Reliability: contract and drift gates make API-01-class breakage impossible to merge. Maintainability: the refactors in this audit become safe to perform, which is the practical precondition for everything else here.

## 6. Medium-severity findings (P2)

Real debt, but neither a launch blocker nor an incident source at the stated volumes. Recorded with the same structure, in condensed form.

### ARCH-01 · ARCH-02 — No domain or service layer; authorization semantics are inconsistent

`P2 · MEDIUM`

**Current.** Backend layers are `routers → models`, with business rules inline in handlers and no repository or service tier; `services/` holds only the two provider clients. Authorization is a set of ad-hoc helpers: `_assert_chama_member` in `projects.py` raises 404, `_assert_member` in `chamas.py` raises 403 for the same condition; project creation requires chama *ownership*, so the `ADMIN` role exists in the enum but grants nothing; contributions check project status but never membership. On the mobile side, `features/*/domain/` does not exist — repositories return transport DTOs (`ProjectModel.fromJson`) straight into widgets, and `dartz` and `get_it` are dependencies that are never used.

**Problem & risk.** Rules that should exist once are duplicated per handler and drift — the 404/403 split is already evidence. Because `ADMIN` is inert, the permission model in the enum does not describe the permission model in the code, which is how authorization bugs are introduced during feature work. Without a domain layer, no business rule is unit-testable without HTTP and a database, which is why the payment logic has no tests. This is a velocity and correctness tax rather than an immediate breach.

**Refactor.** Introduce `repositories/` (all SQL), `services/` (business rules, no HTTP types) and thin routers that only translate HTTP. Replace the assert helpers with one declarative permission dependency, and give the mobile side real domain entities that the UI depends on instead of wire models.

```
# app/core/permissions.py  (new) — one definition, consistent status codes
class Permission(StrEnum):
    CHAMA_VIEW    = "chama:view"
    CHAMA_MANAGE  = "chama:manage"
    PROJECT_CREATE = "project:create"
    PROJECT_EDIT   = "project:edit"

ROLE_GRANTS = {
    ChamaMemberRole.OWNER:  set(Permission),
    ChamaMemberRole.ADMIN:  {Permission.CHAMA_VIEW, Permission.PROJECT_CREATE,
                             Permission.PROJECT_EDIT},        # ADMIN now means something
    ChamaMemberRole.MEMBER: {Permission.CHAMA_VIEW},
}

def require(permission: Permission):
    async def dependency(chama_id: UUID, session=Depends(get_session),
                         user=Depends(get_current_user)) -> ChamaMember:
        member = await session.scalar(
            select(ChamaMember).where(ChamaMember.chama_id == chama_id,
                                      ChamaMember.user_id == user.id))
        # non-membership is always 404 (do not confirm the chama exists);
        # insufficient role is always 403. One rule, applied everywhere.
        if member is None:
            raise HTTPException(404, "Not found")
        if permission not in ROLE_GRANTS[member.role]:
            raise HTTPException(403, "Insufficient permissions")
        return member
    return dependency

# usage
@router.post("/{chama_id}/projects",
             dependencies=[Depends(require(Permission.PROJECT_CREATE))])
```

**Benefits.** Maintainability: authorization becomes one reviewable table instead of scattered asserts. Security: consistent, intentional status codes and no inert roles. Testability: business rules become unit-testable without a web server.

### MOB-04 · MOB-05 · MOB-06 — UI performance details, router rebuilds, and missing offline/localisation support

`P2 · MEDIUM`

**Current.** The UI layer is better than the rest of the mobile code: slivers with `SliverChildBuilderDelegate`, `RepaintBoundary` around the app-bar background, `ref.watch(...select(...))` to narrow rebuilds, extracted `const` leaf widgets, precomputed shadows, and genuine skeleton, empty and error states. Three gaps remain. `ProjectCard._CoverImage` uses `Image.network` although `cached_network_image` is a dependency; list children have no `Key`. `routerProvider` watches the whole `authNotifierProvider`, so the entire `GoRouter` is reconstructed on every auth transition, and its `redirect` is `async` and awaits `SharedPreferences.getInstance()` on every navigation. There is no offline cache, no optimistic update, no `connectivity_plus` usage despite the dependency, and all copy is hardcoded English (with Swahili strings inline) with no `flutter_localizations`.

**Problem & risk.** `Image.network` re-downloads on every scroll pass and decodes at full resolution into memory — on a 140px-tall card with a 2000px source that is roughly 16 MB of raster per image, and it is the most likely cause of jank and OOM on low-end Android. Rebuilding the router discards navigator state and can drop the back stack. The async redirect adds a disk read to every route change. No offline support means the app is unusable on the intermittent connectivity that is normal in the target market, and a payment initiated on a flaky connection has no local record.

**Refactor.** `CachedNetworkImage` with explicit `memCacheWidth`; stable value keys on list children; a stable router that reads auth through a `Listenable` rather than being rebuilt, with onboarding state hoisted out of `redirect`; a connectivity provider feeding an offline banner; and ARB-based localisation for English and Swahili from the start.

```
// project_widgets.dart — before: full-resolution decode, no disk cache
Image.network(url!, height: 140, width: double.infinity, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder());

// after: cached, downscaled at decode time, with a real placeholder
CachedNetworkImage(
  imageUrl: url!,
  height: 140, width: double.infinity, fit: BoxFit.cover,
  memCacheWidth: (MediaQuery.devicePixelRatioOf(context) * 400).round(),
  fadeInDuration: const Duration(milliseconds: 150),
  placeholder: (_, __) => const ProjectCoverSkeleton(),
  errorWidget: (_, __, ___) => _placeholder(),
);

// list children get stable keys so element recycling is correct on reorder
(_, i) => ProjectCard(key: ValueKey(projects[i].id), project: projects[i]);
```

```
// app_router.dart — before: whole router rebuilt on every auth change,
// and an async disk read inside redirect
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);      // ← rebuilds router
  return GoRouter(redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();   // ← disk, every nav
    ...
  });
});

// after: one router instance for the app's lifetime; auth is a Listenable
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ValueNotifier<AuthState>(const AuthInitial());
  ref.listen(authNotifierProvider, (_, next) => notifier.value = next,
             fireImmediately: true);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    refreshListenable: notifier,          // refreshes routes, keeps the stack
    redirect: (context, state) {          // now synchronous
      final auth = notifier.value;
      final seenOnboarding = ref.read(onboardingSeenProvider);  // loaded at startup
      ...
    },
    routes: _routes,
  );
});
```

**Benefits.** Performance: cached, downscaled images typically cut list-scroll memory by 80–90% and remove the dominant jank source on low-end devices; a synchronous redirect removes a disk read from every navigation. UX: navigation state survives auth changes, and the app becomes usable on intermittent connections. Reach: Swahili localisation is a market requirement, not a nicety.

### OPS-01 — Repository and image hygiene

`P2 · MEDIUM`

**Current & problem.** `reset_db.py` — a script whose purpose is to drop everything — sits at the backend root and is copied into the image by `COPY..`. There is no `.dockerignore`, so local `.env` files, test databases and VCS metadata can be baked into layers. `docker-compose.yml` ships pgAdmin with `admin/admin` and publishes Postgres with `postgres/postgres`. Dependency pins are stale in security-relevant places (`bcrypt==4.0.1`, `python-jose==3.3.0`, `psycopg2-binary==2.9.9`) with no automated update path.

**Risk.** A destructive script reachable inside a production container; credentials and local state leaking into published layers; unpatched crypto and JWT libraries. None of these is exploitable on its own, but each meaningfully amplifies any other compromise.

**Refactor.** Move dev scripts under `scripts/dev/` and exclude them; add a strict `.dockerignore`; split compose into `docker-compose.dev.yml` (pgAdmin, published ports, reload) and a production manifest with neither; adopt `pip-tools` with hashes plus Dependabot; and consider replacing `python-jose` with the more actively maintained `pyjwt`.

```
# backend/.dockerignore  (new)
.env
.env.*
*.db
*.sqlite3
.git
.pytest_cache
__pycache__/
tests/
scripts/dev/
reset_db.py
```

**Benefits.** Security: smaller attack surface, no secrets in layers, no destructive tooling in production. Maintainability: reproducible builds and an automated patch path.

## 7. Target architecture

The remediation converges on one shape. Nothing below is speculative: each layer exists to remove a specific finding, and the whole thing is reachable from the current codebase without a greenfield rewrite of anything except the payments path.

Mobile

Flutter, feature-first, unchanged. Riverpod providers consume a generated OpenAPI client — no hand-written paths. One `Money` value type (minor units, integer). Refresh serialised behind a single-flight mutex; tokens in Keychain/Keystore; TLS-only base URL from build flavour.

Edge

TLS termination, WAF, per-route rate limits, request-ID injection. Provider callbacks arrive on a dedicated path with IP allow-listing and signature verification before any application code runs.

API

FastAPI, fully async (`asyncpg` + async SQLAlchemy), stateless, ≥2 replicas. Routers do transport only; validation in schemas, rules in a service layer, persistence in repositories. Authorization via a single policy primitive, never ad-hoc owner checks.

Ledger

Append-only double-entry `ledger_entries` in Postgres; `NUMERIC(18,2)` or `BIGINT` minor units, never `FLOAT`. Balances are derived views, never mutable counters. Every write carries an idempotency key and an actor; nothing is ever updated in place.

Async

Transactional outbox → worker (Celery or ARQ) for provider calls, retries with jitter, circuit breaking, and a scheduled reconciliation job that queries provider status for every non-terminal transaction older than its timeout.

Platform

Managed Postgres with PITR and a read replica, Redis for cache and locks, Alembic as the single source of schema truth, secrets in a managed store, OpenTelemetry traces plus structured JSON logs and Prometheus metrics behind payment-funnel alerts.

## 8. Remediation roadmap

Four phases, 9–13 weeks, staffed at two backend engineers, one mobile engineer and a half-time platform engineer. Phases are ordered by dependency, not by severity: the money model has to land before anything that writes money can be trusted, and observability has to land before any of it can be verified in production.

| Phase | Scope | Closes | Weeks |
|---|---|---|---|
| P-1 | **Stop the bleeding.** Freeze `create_tables()` and make Alembic authoritative; migrate all monetary columns to integer minor units; introduce the append-only ledger with derived balances; backfill and reconcile existing rows under a maintenance window. | FIN-01, FIN-02, DB-01, PERF-03 | 2–3 |
| P-2 | **Trustworthy payments.** Signature verification and IP allow-listing on callbacks; idempotency keys on every state transition; transactional outbox and worker; timeouts, retries and circuit breaker; the reconciliation job and its dashboard. | PAY-01…03, REL-02, PERF-05 | 3–4 |
| P-3 | **Security, identity and visibility.** Hash refresh tokens and add a revocation list with short-lived access tokens; rate limits and lockout; scoped CORS and security headers; explicit update schemas replacing `setattr`; structured logging, correlation IDs, metrics, traces, Sentry actually initialised; audit trail and retention policy. | SEC-01…04, SEC-06, SEC-08, OBS-01, REG-01 | 2–3 |
| P-4 | **Contract, client and platform.** Generated API client and a contract test that fails CI on drift; async ORM and SQL aggregates; cursor pagination; single-flight refresh, TLS-only config, cached images, mapped error copy, Swahili localisation; CI with Postgres, HA topology, hardened images. | API-01, PERF-01/02/04, SEC-05/07, MOB-01…06, REL-01, TEST-01, OPS-01, ARCH-01/02 | 2–3 |

**Sequencing note.** P-1 and P-3 can overlap after week two — different files, different engineers. P-2 cannot start before the ledger exists, and no phase should ship without the CI gate from P-4's first week, which is the one item worth pulling forward.

## 9. Definition of production-ready

The audit's verdict flips when every line below is true, demonstrably and in staging with production-shaped data. This is the acceptance checklist, not a wish list.

01No `float` or `double` appears anywhere on a monetary path, in either language; a CI lint enforces it.

02Every balance shown to a user is derived from ledger entries, and the ledger sums to zero per transaction.

03A replayed provider callback, a duplicated one, and a forged one are each proven harmless by an automated test.

04A transaction abandoned mid-flight by the provider reaches a terminal state without human intervention, within a stated SLA.

05Schema changes only through Alembic; `create_tables()` is deleted, and CI verifies migrations against a fresh Postgres.

06Logout revokes access; refresh tokens exist only as hashes; login and payment initiation are rate-limited and alerted on.

07Every request has a correlation ID that appears in logs, traces and the mobile error report; the payment funnel is on a dashboard with paging alerts.

08The mobile client is generated from the served OpenAPI document; a contract test fails the build on drift.

09All traffic is TLS; no LAN address, credential or key is present in any committed file or built image.

10Two API replicas can be lost without downtime, and a point-in-time restore has been rehearsed end to end.

11Every money-moving action writes an immutable audit record naming the actor, and retention is documented against local requirements.

Scope & method

Static review of the full repository at the referenced commit: Flutter application, FastAPI service, migrations, Docker and compose manifests, dependency manifests and test suite. No dynamic testing, penetration testing or load testing was performed; findings marked as risks are reasoned from the code, not observed in production.

Not assessed

Commercial terms with payment providers, licensing obligations, the specific regulatory regime applicable to holding customer funds, and design/brand quality. Each of these should be reviewed by the appropriate specialist before launch; the regulatory item in particular may add scope beyond this roadmap.
