"""
scripts/dev/reset_db.py — DEV ONLY. Drops the public schema and rebuilds it
from the Alembic migration history (never from the ORM models directly —
that is the exact create_all()-vs-migrations drift DB-01 in
docs/Changa_Engineering_audit.md exists to close).

This script is excluded from the production image (see backend/.dockerignore)
and must never be reachable from a deployed container. Run it locally:

    cd backend && python scripts/dev/reset_db.py
"""
import subprocess
import sys
from pathlib import Path

from sqlalchemy import text

from app.database import engine

BACKEND_ROOT = Path(__file__).resolve().parents[2]

print("This will DESTROY all data in the configured DATABASE_URL.")
if input("Type 'reset' to continue: ").strip() != "reset":
    print("Aborted.")
    sys.exit(1)

print("Dropping and recreating the public schema...")
with engine.begin() as conn:
    conn.execute(text("DROP SCHEMA public CASCADE"))
    conn.execute(text("CREATE SCHEMA public"))

print("Rebuilding schema via `alembic upgrade head`...")
subprocess.run(["alembic", "upgrade", "head"], cwd=BACKEND_ROOT, check=True)

print("Done. Register a fresh user to get started.")