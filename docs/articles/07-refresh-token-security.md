# A refresh token is a password with extra steps

A refresh token is what lets someone stay logged in without re-entering their password every fifteen minutes. Functionally, it *is* a password — anyone who has it can use it to get a fresh access token and act as that user. Changa's original schema stored it like this:

```python
token = Column(String(500), unique=True, nullable=False)  # the full JWT, in plaintext
```

The full, working token, written verbatim into the database. Read access to that one table — a backup file, a replica, a logged slow query, a SQL injection anywhere else in the app — is immediate, silent account takeover for every user with an active session. Nobody would ever store a password that way. A refresh token deserves the exact same treatment, and wasn't getting it.

There was a second problem layered on top: access tokens had no `jti` (a unique ID per token) and nothing checked one against a revocation list. Logging out only ever flipped a flag on the *refresh* token. The access token you already had kept working, unaffected, for the rest of its lifetime — logout didn't actually end your session, it just stopped you from getting a new one.

## What we changed

- **Refresh tokens are now opaque, high-entropy random strings — not JWTs — and only their SHA-256 hash is ever stored.** The raw token exists for one moment, in the response to the client; the database never sees it again. Even a full read of the table gives an attacker nothing usable.
- **Access tokens gained a `jti` claim and a much shorter lifetime** (15 minutes, down from 30). Logging out now adds that `jti` to a small revocation table, and a per-user `tokens_valid_after` timestamp lets one action — a password change, an admin disabling an account — invalidate *every* outstanding access token at once, not just future ones.
- **Refresh tokens are grouped into rotation "families,"** one per login session. Each time a refresh token is used, it's marked consumed and a new one is issued in its place. If a *consumed or already-revoked* token gets presented again — the signature of a stolen token being replayed by someone who isn't the legitimate user — the entire family is revoked immediately, not just that one request rejected.

## A bug the regression suite caught, not a code review

While verifying this branch, the full test suite came back with new failures it hadn't had before — a signal worth stopping for, not explaining away. The cause: a couple of call sites passed `str(user.id)` into the function that builds a new refresh token row, and that string landed directly on a column typed as a real UUID. It happened to *look* fine against Postgres, but broke outright under the test suite's SQLite substitution, and more importantly, it was simply the wrong type being passed around — correct by accident, not by design. The fix was straightforward once found: keep the user's ID as an actual UUID object all the way through, and only convert it to a string at the one place that genuinely needs a string — encoding it into a JWT claim.

That's the value of running the *entire* regression suite on every branch, not just the tests that seem related: this bug had nothing to do with what the branch was "supposed" to be about, and would have shipped invisibly otherwise.

## How we knew it worked

We tested reuse detection directly: use a refresh token, then present that same now-consumed token again, and confirm the whole session family — not just that one request — stops working. And logout: get an access token, log out, then try to use that same still-technically-valid-by-expiry access token, and confirm it's rejected.

**The lesson:** anything that grants access is a credential, whether or not it's called one. Store it the way you'd store a password, give yourself a way to revoke it in bulk, and treat "an already-used token showing up again" as the security signal it actually is.
