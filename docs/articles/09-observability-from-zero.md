# Nobody could answer "what happened to this shilling"

There wasn't a single `logging.getLogger()` call anywhere in Changa's backend. Sentry — an error-tracking service — was listed as a dependency, but `sentry_sdk.init()` was never actually called, so it did nothing at all. The only output the server produced was Uvicorn's default access log: a line per request, with no way to connect a specific user's failed contribution to the specific provider call and callback that were involved in it. And `/health` returned a static `{"status": "ok"}` no matter what — even with the database completely unreachable, which means an orchestrator checking that endpoint would happily keep sending traffic to a pod that couldn't actually do anything.

Put plainly: if a member's contribution went wrong, there was no way to reconstruct what happened to it. Not because the information was hard to find — because it was never recorded in the first place.

## What we changed

Three pieces, each addressing a different half of "what happened":

**Structured, correlated logs.** Every log line is now JSON, and every request gets a `request_id` — either generated fresh, or taken from an inbound `x-request-id` header if the client already set one, so a support ticket and a server-side trace can refer to the exact same identifier. That ID gets echoed back in the response header and attached to every log line produced while handling that request, including an automatic, full-stack-trace log the moment before any unhandled exception propagates — nothing disappears into stdout unlogged anymore. A redaction step runs on every log line before it's written, so passwords, tokens, and phone numbers (kept to their last three digits — enough for support to confirm they're looking at the right person, not enough to be the number) can't end up in a log by accident, no matter which code path produced it.

**A real readiness check.** `/health` still answers "is the process running" with no dependency checks — that's what it should be, since an orchestrator uses it to decide whether to *restart* a pod, and a database outage shouldn't trigger a restart loop. A new `/ready` endpoint actually queries the database and returns a 503 if it can't reach it — the signal an orchestrator should use to *stop routing traffic here*, which is a meaningfully different decision from "restart this."

**The payment funnel became visible.** Structured log lines now mark each state transition a contribution goes through — initiated, settled successfully, settled with a mismatch, failed — because a drop in successful payments is, as the original audit put it, "the single most important business signal," and before this change it was invisible until users started complaining.

## What we deliberately left out

The fuller version of this fix — the kind you'd find in a fully mature setup — also wires in Prometheus metrics and OpenTelemetry distributed tracing. We didn't build that here, on purpose. Changa runs as a single replica with no metrics-scraping infrastructure or trace collector deployed anywhere; adding that instrumentation now would be code pointed at nothing, dead weight until infrastructure exists to receive it. What shipped is the part that's pure library code with no new infrastructure dependency — logs, correlation, and Sentry (which only needed a DSN, since the dependency was already there). The structured event logs for the payment funnel are written so that promoting them into real metrics later is a mechanical, low-risk follow-up, not a redesign.

## How we knew it worked

We stopped the database on purpose and confirmed `/health` still said OK while `/ready` correctly returned 503 with a full stack trace logged. We sent a custom `x-request-id` and confirmed it came back unchanged instead of being overwritten. And we deliberately logged a line containing a password and a phone number and confirmed the redaction step caught both.

**The lesson:** the time to add observability is before you need to debug something, not during. If a request can fail in a way nobody can trace back to its cause, that's not a missing feature — it's the reason a dozen other bugs stay invisible until a user reports them.
