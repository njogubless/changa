import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from app.core.config import settings

engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


class SchemaOutOfDate(RuntimeError):
    """Raised at startup when the database has not been migrated to head.

    Alembic is the only thing that is allowed to touch DDL (see DB-01 in
    docs/Changa_Engineering_audit.md) — the app used to paper over this with
    `Base.metadata.create_all()` on every boot, which only ever adds tables
    and can silently diverge from the migration history. Refuse to serve
    traffic against a schema nobody can account for instead.
    """


def verify_schema_at_head() -> None:
    from alembic.config import Config
    from alembic.script import ScriptDirectory
    from alembic.runtime.migration import MigrationContext

    backend_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    alembic_cfg = Config(os.path.join(backend_root, "alembic.ini"))
    alembic_cfg.set_main_option("script_location", os.path.join(backend_root, "alembic"))
    script = ScriptDirectory.from_config(alembic_cfg)
    head_revision = script.get_current_head()

    with engine.connect() as connection:
        context = MigrationContext.configure(connection)
        current_revision = context.get_current_revision()

    if current_revision != head_revision:
        raise SchemaOutOfDate(
            f"Database is at revision {current_revision!r} but the application "
            f"expects {head_revision!r}. Run `alembic upgrade head` before starting "
            "the API — schema changes are never applied automatically."
        )
