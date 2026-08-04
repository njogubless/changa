import os
from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.observability import configure_observability, get_logger
from app.database import get_db, verify_schema_at_head
from app.routers import auth, projects, payments, chamas, budgets

# Import-time side effects, both required before any request is served:
# registers audit_events/kyc_profiles/consent_records with Base.metadata
# (so create_all/alembic see them), and registers the before_flush/
# after_flush Session hooks that populate audit_events. See REG-01.
import app.models.audit  # noqa: F401
import app.models.compliance  # noqa: F401
import app.core.audit  # noqa: F401

log = get_logger("changa.main")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Schema changes only ever come from `alembic upgrade head`, run as a
    # deploy step before the app starts — never implicitly at boot. See
    # docs/Changa_Engineering_audit.md, DB-01.
    if os.environ.get("PYTEST_RUNNING") != "1":
        verify_schema_at_head()
    yield


_docs_url = "/docs" if settings.DEBUG else None
_redoc_url = "/redoc" if settings.DEBUG else None

app = FastAPI(
    title=settings.APP_NAME,
    description="Group contribution platform for Kenya — M-Pesa & Airtel Money",
    version="1.0.0",
    docs_url=_docs_url,
    redoc_url=_redoc_url,
    lifespan=lifespan,
)

_cors_origins = ["*"] if settings.DEBUG else settings.ALLOWED_HOSTS
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=not settings.DEBUG and "*" not in _cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

configure_observability(app)

app.include_router(auth.router)
app.include_router(chamas.router)
app.include_router(projects.router)
app.include_router(payments.router)
app.include_router(budgets.router)   # ← new


@app.get("/health", tags=["System"])
def health():
    """Liveness: is the process running at all? No dependency checks —
    an orchestrator uses this to decide whether to restart the pod, and a
    slow/unreachable database should trigger a readiness failure and
    traffic drain, not a restart loop."""
    return {"status": "ok", "app": settings.APP_NAME}


@app.get("/ready", tags=["System"])
def ready(db: Session = Depends(get_db)):
    """Readiness: can this instance actually serve traffic right now?
    Before this, /health always returned ok even with the database
    unreachable, so an orchestrator kept routing traffic to a broken pod
    (see OBS-01)."""
    try:
        db.execute(text("SELECT 1"))
        db_status = "ok"
    except Exception:
        log.exception("ready.db_check_failed")
        db_status = "fail"

    checks = {"db": db_status}
    ok = all(v == "ok" for v in checks.values())
    return JSONResponse(checks, status_code=200 if ok else 503)