from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.core.config import settings
from app.database import create_tables
from app.routers import auth, projects, payments, chamas, budgets


@asynccontextmanager
async def lifespan(app: FastAPI):
    import os
    if os.environ.get("PYTEST_RUNNING") != "1":
        create_tables()
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

app.include_router(auth.router)
app.include_router(chamas.router)
app.include_router(projects.router)
app.include_router(payments.router)
app.include_router(budgets.router)   # ← new


@app.get("/health", tags=["System"])
def health():
    return {"status": "ok", "app": settings.APP_NAME}