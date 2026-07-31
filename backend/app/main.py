import asyncio
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.core.config import settings
from app.database import verify_schema_at_head
from app.routers import auth, projects, payments, chamas, budgets
from app.workers import payment_worker


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Schema changes only ever come from `alembic upgrade head`, run as a
    # deploy step before the app starts — never implicitly at boot. See
    # docs/Changa_Engineering_audit.md, DB-01.
    if os.environ.get("PYTEST_RUNNING") != "1":
        verify_schema_at_head()

    # Drains the payment outbox and sweeps stale PENDING contributions —
    # see PAY-03. Skipped under pytest so the test suite doesn't spin up a
    # background loop against a database it's about to drop.
    worker_task = None
    if os.environ.get("PYTEST_RUNNING") != "1":
        worker_task = asyncio.create_task(payment_worker.run_forever())

    yield

    if worker_task is not None:
        worker_task.cancel()
        try:
            await worker_task
        except asyncio.CancelledError:
            pass


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

app.include_router(auth.router)
app.include_router(chamas.router)
app.include_router(projects.router)
app.include_router(payments.router)
app.include_router(budgets.router)   # ← new


@app.get("/health", tags=["System"])
def health():
    return {"status": "ok", "app": settings.APP_NAME}