from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.core.config import settings
from app.database import create_tables
from app.routers import auth, projects, payments


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Only create tables when not running under pytest
    import os
    if os.environ.get("PYTEST_RUNNING") != "1":
        create_tables()
    yield


app = FastAPI(
    title=settings.APP_NAME,
    description="Group contribution platform for Kenya — M-Pesa & Airtel Money",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.DEBUG else settings.ALLOWED_HOSTS,
    allow_credentials=False if settings.DEBUG else True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(projects.router)
app.include_router(payments.router)


@app.get("/health", tags=["System"])
def health():
    return {"status": "ok", "app": settings.APP_NAME}
