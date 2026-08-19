# Schema truth: why we deleted `create_tables()`

Every time the Changa API started up, it ran one line: `Base.metadata.create_all(bind=engine)`. Read the tables your Python code defines, and create any that don't exist yet in the database. It's the first thing almost every SQLAlchemy tutorial shows you, and it feels harmless — it only *adds* things, right?

That's exactly the problem. It only adds. It never tells you when a column changed type, when a constraint got stricter, or when two people's local branches quietly drifted apart about what the schema should look like. And it runs on every boot. Deploy two replicas of the API at the same time — completely normal during a rolling deploy — and both processes can race to create the same table at the same moment. One of them loses that race and crashes.

There's a deeper issue underneath: **nobody could point to a single source of truth for what the database actually looked like.** The Python model file said one thing. The live database, shaped by months of ad-hoc changes, might say another. There was no history to diff, no way to review a schema change before it shipped, and no way to answer "what did the `contributions` table look like three months ago?"

## What we changed

We made Alembic — the migration tool already sitting unused in the project — the only thing allowed to touch the database's structure. Concretely:

- **Deleted `create_tables()`.** The app no longer creates or alters tables on boot.
- **Added `verify_schema_at_head()`.** On startup, the app checks the database's current migration revision against what the code expects. If they don't match, it refuses to start, with an error telling you to run `alembic upgrade head` first. A mismatched schema is now a loud failure at boot, not a silent one hours later.
- **Rebuilt the migration history from scratch** as a single, verified baseline, since the old one no longer matched reality.
- **Moved `reset_db.py`** — a script that wipes the database — out of the production image entirely, into `scripts/dev/`, and added a confirmation prompt.

## How we knew it worked

We didn't just read the migration and hope. For every migration in this project, the check was the same: spin up a throwaway Postgres container, run `alembic upgrade head` against it, then run `alembic check` — a command that fails loudly if the migration doesn't produce *exactly* the schema the Python models describe. Zero drift, or it doesn't ship. Then the container gets thrown away.

That last step matters as much as the first. A migration that "looks right" reading the diff is not the same as a migration that was actually run against a real database and produced the table you meant.

**The lesson:** if a tool can silently reshape production on every boot, it isn't convenient — it's a race condition waiting for two replicas to start at once. Make the schema something you can diff, review, and verify before it ever touches real data.
