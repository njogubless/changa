# When the app and the server quietly stop agreeing

The Flutter app's main project-browsing screen called `GET /projects`. The server didn't define that route. It never had — creating and listing projects had been moved, at some earlier point, to live under `/chamas/{chama_id}/projects` instead, and nobody had gone back to update the client.

Here's the part that let this go unnoticed for a while: `GET /projects` doesn't cleanly 404. FastAPI's router sees the request and matches it against `GET /projects/{project_id}` with an empty or invalid ID in that slot, so it comes back as a `422` validation error instead — which the app's error handling maps to a generic "something went wrong" message. A genuinely missing endpoint dressed itself up as a garden-variety validation failure. The mobile app was also client-side aggregating projects across every chama a user belonged to as a separate workaround, which happened to paper over just enough of the broken screen's absence to keep the bug from being glaringly obvious in daily use. And the test suite covering this exact endpoint was already failing for the same reason, which meant its signal — "hey, this is broken" — had already been silently written off before this work started.

The API also declared routes for team membership — `/projects/{id}/members`, `/projects/{id}/teams`, a team-join endpoint — that had never existed on the server at all. There's no `Team` concept anywhere in the backend's data model. These weren't drifted; they were speculative from the start.

## What we changed

The instinct here could easily have been "the client expects `GET /projects`, so let's build `GET /projects`." That would have been the wrong fix. Before writing anything, it's worth asking what's actually true on both sides — and it turned out `GET /projects/mine`, an endpoint that already existed and already ran exactly the cross-chama query the client needed, just hadn't been given the one feature (search filtering) the client was already sending as a query parameter. Building a second endpoint that does almost the same thing as one that already exists is exactly the kind of duplication that causes *this class of bug* in the first place.

So the fix was smaller than it first looked:

- Added `search` filtering to the endpoint that already existed, instead of inventing a new one.
- Pointed the client's project-list screen at that real endpoint.
- Deleted the client-side code calling the dead `POST /projects` — which, on inspection, had zero actual callers anywhere in the app. The real, working project-creation flow already correctly posted to the chama-scoped route; the dead code was an orphaned second implementation nobody used, not a missing feature.
- Deleted the team/member constants and their route builders outright, rather than stubbing out endpoints for a feature that doesn't exist in the domain model.

## How we knew it worked

The test suite's own SQLite substitution has an unrelated, pre-existing bug that made a chunk of this area unreliable to verify through pytest directly — so instead of trusting a suite already known to be noisy here, we stood up a real server against a real Postgres database and walked the actual flow end to end: register, create a chama, create two projects, confirm the dead routes now correctly 404, confirm the real endpoint returns both projects with no filter and correctly narrows to one with a matching search term and to zero with a non-matching one.

**The lesson:** contract drift between a client and a server doesn't always look like an error — it can look like a slightly-too-generic failure message that gets shrugged off as a fluke. Before building the endpoint a client says it wants, check whether something that already does the job is sitting one function away from correct.
