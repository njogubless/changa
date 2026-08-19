# Add should never mean add twice: the append-only ledger

Picture the simplest possible way to record a contribution: when a payment succeeds, run `project.raised_amount += contribution.amount` and save. It reads perfectly reasonably. It's also quietly dangerous, because it assumes that "a payment succeeded" is an event that only ever happens once per payment.

It doesn't. Mobile networks drop connections. Payment providers retry callbacks that they think might not have arrived. A background job can crash after updating the database but before marking a job "done," and the next run picks up the same job again. Any one of those can cause the same successful payment to be processed twice — and `+=` has no memory. It doesn't know it already added this contribution five minutes ago. It just adds it again, and now a member's KES 500 contribution shows up as KES 1,000 raised.

The deeper issue: `raised_amount` was the *only* record. There was no way to ask "which contributions actually make up this total?" — the number existed, but its receipts didn't.

## What we changed

We introduced an append-only `ledger_entries` table — one row per contribution actually credited, never updated, never deleted — and made crediting a project provably happen at most once per contribution:

```python
inserted = db.execute(
    pg_insert(LedgerEntry).values(...)
    .on_conflict_do_nothing(constraint="uq_ledger_contribution_direction")
    .returning(LedgerEntry.id)
).scalar_one_or_none()

if inserted is None:
    return False  # already credited — nothing more to do
```

That `on_conflict_do_nothing`, backed by a unique constraint on `(contribution_id, direction)`, is the whole trick. It moves the "have I already done this?" check from application logic — which can race, retry, or simply forget — into the database itself, where it's enforced atomically no matter how many requests arrive for the same contribution at the same time. If the insert succeeds, this is the first time; credit the project. If it doesn't, someone already got here first; do nothing and return.

We also replaced the `+=` itself. Even with double-crediting solved, incrementing a value in Python and writing it back is still a race between two concurrent requests reading the same starting number. The fix there is a single atomic SQL statement instead: `UPDATE projects SET raised_amount = raised_amount + :amount WHERE id = :id` — the addition happens inside the database, in one step, instead of being split across a read in Python and a write back.

A budget's spent-amount tracking had the same shape of bug — Python arithmetic with a manual `max(0.0, ...)` clamp bolted on to hide negative numbers rather than prevent them — and got the same fix: a real atomic recomputation from the underlying rows, not an incremental adjustment that drifts.

## How we knew it worked

We wrote a reconciliation query that recomputes each project's total directly from its ledger entries and compares it to the stored `raised_amount`. Any mismatch is a bug, immediately, rather than a support ticket three weeks later. That query became part of the verification loop for every subsequent branch — a mismatch would have meant something regressed.

**The lesson:** if an operation needs to happen "exactly once," don't trust application code to remember that it already ran. Give the database something to enforce — a unique constraint it will reject a duplicate against — and let *that* be the source of truth.
