# What if the process dies mid-payment? The transactional outbox

Here's a question worth sitting with: when a member taps "contribute," your server needs to do two things — save a record that a contribution is pending, *and* actually call M-Pesa or Airtel to trigger the STK push on the member's phone. Those two things cannot both happen as a single database transaction, because one of them is a network call to a third party that can take fifteen seconds and can fail in ways entirely outside your control.

So what happens if your server saves the "pending contribution" row successfully, and then — the process crashes, the network blips, anything — never actually calls the provider? You get a contribution stuck forever in `PENDING`, with no STK push ever sent, and a member wondering why nothing happened on their phone.

## What we changed

We used a pattern called the **transactional outbox**: instead of trying to do the database write and the provider call in the same breath, split them.

1. When a contribution is initiated, the API writes *two* things in one database transaction: the `Contribution` row itself, and an `OutboxMessage` row describing "push this payment to the provider." Either both get committed, or neither does — no in-between state where one exists without the other.
2. A separate background worker continuously drains that outbox: it picks up pending messages, actually calls the provider's API, and records the outcome.
3. A **reconciliation sweep** runs on a timer, checking on any contribution that's been sitting in `PENDING` too long by asking the provider directly what actually happened to it — because sometimes the provider processed the payment but Changa never received (or successfully processed) the confirming callback.

This is the same idea as the append-only ledger from earlier — move the guarantee from "the code has to remember to do this" into a durable, database-backed queue that survives a crash — applied to an outgoing action instead of an incoming one.

## Two bugs the verification loop caught before they shipped

Neither of these was visible from reading the code casually. Both showed up because every branch in this project was run against a real, full regression suite before being trusted:

**The Airtel retry was silently a no-op.** The guard deciding whether to retry a failed push checked `contribution.checkout_request_id or contribution.provider == AIRTEL` — which is *always true* for an Airtel contribution, regardless of whether a previous attempt had actually been made. It looked like a retry guard. It behaved like "always retry, forever," because the condition never actually gated anything for that branch. The fix was splitting the check by provider: M-Pesa keys off whether a checkout ID exists yet; Airtel keys off whether `push_attempts > 0`.

**Contributions with no checkout ID were stuck forever, invisibly.** If a push to the provider failed before a checkout ID was even assigned, the reconciliation sweep's logic hit a silent early return — it never counted against the retry budget, so the contribution just sat in `PENDING` indefinitely with no path to resolution and no alert. The fix: that case now counts against the same attempt budget as everything else and escalates to a clear `failure_reason` after enough attempts, instead of vanishing into a state nothing else checks for.

## How we knew it worked

Beyond the standard migration-verification loop, this needed a functional test that actually simulated the failure mode the pattern exists for: kill the worker process mid-drain, restart it, and confirm the outbox message — and therefore the provider push — still eventually happens exactly once, not zero times and not twice.

**The lesson:** any time a database write and an external call need to happen together but can't be one atomic operation, write down the *intent* durably first, and let a separate, restartable process carry it out. That way a crash between the two loses nothing — it just means the outbox has one more message waiting for the worker to come back.
