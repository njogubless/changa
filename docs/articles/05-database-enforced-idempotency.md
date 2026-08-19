# Two requests, one truth: idempotency in the database

"Idempotent" is one of those words that sounds academic until the exact moment your phone loses signal mid-payment. You tap "contribute," the request goes out, the connection drops before you see a response, and — reasonably — you tap it again. Or the payment provider's own callback delivery retries because it didn't get an acknowledgment fast enough. Either way, the same successful payment can now arrive at your server described twice.

The append-only ledger (see the previous article) solved this for the specific case of *crediting a project's total*. But the underlying `contributions` table itself had no equivalent guarantee. Nothing stopped two near-simultaneous requests from both reading a contribution as "not yet completed," both deciding to mark it successful, and both writing — a classic read-then-write race, where the check and the action aren't atomic.

## What we changed

We pushed the "has this already happened?" question down into constraints the database enforces on every write, not assumptions the application code has to get right every single time it touches this table:

- A **unique constraint** on `(provider, provider_reference)` — the payment provider's own receipt number. Two rows claiming to be the same M-Pesa receipt can't both exist; the second insert simply fails, cleanly, instead of silently succeeding and creating a duplicate.
- A **CHECK constraint** requiring `amount > 0` — a bad amount stops being possible to store at all, not just something you'd catch with a Python `if`.
- A **composite index** on `(project_id, status)`, since idempotency checks and status lookups are now something the database does on every write, so they need to be fast.

Worth calling out: Alembic's autogeneration, which usually writes migrations for you by comparing your models to the database, doesn't reliably pick up CHECK constraints on its own. It's an easy thing to add to the model file and then discover — much later — was never actually applied to any real database. We caught this specifically by not trusting the generated migration file at face value: it has to be applied to an actual database and re-diffed against the models before it counts as verified.

## How we knew it worked

We simulated the exact race this was built to prevent: two requests for the same provider receipt, fired concurrently. One succeeds; the other gets a clean, expected failure from the unique constraint — not a silent duplicate, not a crash, a specific and recoverable error. Then the usual loop: throwaway Postgres, apply the migration, `alembic check` for zero drift, tear down.

There was one sharp edge worth remembering for next time: Alembic's revision-id column in production is a fixed-width `VARCHAR(32)`. A descriptive migration name that's perfectly readable in the file itself can be too long once it becomes the revision id, and the failure mode is an obscure database truncation error at migration time — not a helpful one at authoring time. Short, deliberate revision ids avoid that entirely.

**The lesson:** idempotency isn't a checklist item you can tick off with an `if this hasn't happened yet` in application code — that check and the write it guards need to be one atomic operation, or the two requests racing each other will find the gap between them.
