import os
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

os.environ.setdefault("SECRET_KEY", "test-secret-key-not-for-production-32chars")
os.environ.setdefault("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/changa_db")

from app.main import app
from app.database import Base, get_db

TEST_DATABASE_URL = "sqlite:///./test_changa.db"

engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(autouse=True)
def reset_db():
    """Fresh tables for every test, created on the TEST engine."""
    import app.models.models  # noqa — register all models
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def registered_user(client):
    """Register a user and return (client, tokens, user_data)."""
    user_data = {
        "full_name": "Amina Wanjiru",
        "email": "amina@changa.co.ke",
        "phone": "254712345678",
        "password": "Secure123",
    }
    resp = client.post("/auth/register", json=user_data)
    assert resp.status_code == 201
    return client, resp.json(), user_data


@pytest.fixture
def auth_headers(registered_user):
    """Return Authorization headers for an authenticated user."""
    _, tokens, _ = registered_user
    return {"Authorization": f"Bearer {tokens['access_token']}"}


@pytest.fixture
def sample_project(client, auth_headers):
    """Create a project and return its data."""
    resp = client.post(
        "/projects",
        json={
            "title": "Harambee ya Wanjiku",
            "description": "Tunachangia pamoja",
            "target_amount": 50000,
            "visibility": "public",
        },
        headers=auth_headers,
    )
    assert resp.status_code == 201
    return resp.json()
