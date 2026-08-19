# Stopping a brute force without adding Redis

The only middleware registered anywhere in Changa's API was CORS. That meant every endpoint accepted unlimited requests from anyone: unlimited login attempts against a single account, unlimited free-form account registrations, and — the one with a real dollar cost attached — unlimited real STK pushes triggered through the payment-initiation endpoint. Each one of those is a genuine, billed request to Safaricom. A script hammering that endpoint isn't just an inconvenience; it's a phone bill, and enough of it will get the platform's shortcode suspended by the provider entirely.

There's a second, quieter risk in how a naive login check often gets written. If checking a password for a user that doesn't exist returns "invalid credentials" *faster* than checking one for a user that does — because the real check does an actual password comparison and the fake one short-circuits before it gets there — that timing difference alone tells an attacker which emails are registered, without ever needing a correct password.

## What we changed

**A rate limiter, but not a Redis-backed one.** Changa runs as a single replica today; there's no second instance for a shared, distributed rate-limit store to coordinate with. Adding Redis specifically to solve a problem a single process can already solve in memory would be new infrastructure with nothing forcing it to exist yet. So the limiter is a small, in-process, thread-safe sliding window — a dictionary of timestamps per identity, cleared out as it ages — deliberately designed as a seam: every call site goes through one function, so swapping in a Redis-backed version later, once there's more than one replica to coordinate across, touches this one module and nothing else.

Different endpoints get keyed differently, on purpose: login attempts are limited per source IP (a flood guard) *and* separately per account (so spreading attempts across many IPs doesn't help an attacker outrun the per-account lockout). Payment initiation and chama-join are limited per authenticated user, since that's what actually constrains the behavior you're trying to stop — an IP-based limit on an authenticated action just means the attacker uses more IPs.

**A progressive account lockout, independent of the IP-based limiter.** Five failed logins locks an account for fifteen minutes; ten locks it for an hour. And every login check — even for an email that was never registered — now runs a full password comparison against a dummy hash instead of returning early, so there's no timing difference for an attacker to read.

## A bug the test suite's own architecture exposed

Once the limiter was wired in, the full regression suite came back with new failures — registrations getting rejected that had nothing to do with rate limiting as a *feature*, and everything to do with rate limiting as *global state*. The test client uses a single fixed fake source IP for every test in the run, and the registration limit (three per hour) doesn't know or care that these are supposed to be independent tests — from its point of view, it's the same IP, hammering the endpoint, and by the fourth test in the file, every subsequent registration correctly got rejected.

The fix wasn't to weaken the limiter — it was to give the test suite the same reset hook a production deploy would never need but a test run absolutely does: a function that clears the limiter's state, wired into an autouse fixture that runs before every single test, the same pattern the project already used to get a fresh database per test.

**The lesson:** you don't need distributed infrastructure to solve a problem your current topology doesn't have yet. Build the simplest thing that's correct for how the system actually runs today, but design the one seam that'll matter later — and remember that global state, even well-intentioned rate-limiting state, needs an explicit reset story or it'll leak sideways into your tests.
