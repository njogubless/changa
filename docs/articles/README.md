# The Changa engineering log

Changa is a Flutter + FastAPI app that lets Kenyan chamas — informal
savings and investment groups — pool contributions toward a shared goal
and pay in over M-Pesa or Airtel Money. Because it moves real money, an
engineering audit (`docs/Changa_Engineering_audit.md`) went through the
codebase looking for anything that could lose a member's money, leak
their data, or leave the team unable to answer "what happened to this
contribution?" It found 28 issues. Eleven were blocking: money handled as
floating-point numbers, payment callbacks nobody verified, tokens stored
in plaintext, and more.

This folder is eleven short articles, one per fix, written as the team
actually experienced them: what was broken, why it mattered, what changed,
and how we convinced ourselves it actually worked. Each one ends with a
one-line lesson that generalizes past this one codebase.

They're ordered the way the work happened — foundational fixes first,
because everything else was built on top of them.

1. [Schema truth: why we deleted `create_tables()`](01-schema-truth.md)
2. [The missing cent: money as `Decimal`, not `float`](02-money-as-decimal.md)
3. [Add should never mean add twice: the append-only ledger](03-append-only-ledger.md)
4. [Never trust a webhook: authenticating payment callbacks](04-authenticating-payment-callbacks.md)
5. [Two requests, one truth: idempotency in the database](05-database-enforced-idempotency.md)
6. [What if the process dies mid-payment? The transactional outbox](06-transactional-outbox.md)
7. [A refresh token is a password with extra steps](07-refresh-token-security.md)
8. [Stopping a brute force without adding Redis](08-rate-limiting-without-redis.md)
9. [Nobody could answer "what happened to this shilling"](09-observability-from-zero.md)
10. [When the app and the server quietly stop agreeing](10-api-contract-drift.md)
11. [The history that matters is the history you didn't record](11-audit-trail.md)
