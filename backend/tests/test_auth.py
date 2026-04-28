import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.database import Base, get_db

TEST_DB_URL = "sqlite:///./test.db"
engine = create_engine(TEST_DB_URL, connect_args={"check_same_thread": False})
TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    db = TestingSession()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client():
    return TestClient(app)


VALID_USER = {
    "full_name": "Amina Wanjiru",
    "email": "amina@example.com",
    "phone": "254712345678",
    "password": "Secure123",
}


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_register_success(client):
    r = client.post("/auth/register", json=VALID_USER)
    assert r.status_code == 201
    data = r.json()
    assert data["user"]["email"] == VALID_USER["email"]
    assert "access_token" in data
    assert "refresh_token" in data


def test_register_duplicate_email(client):
    client.post("/auth/register", json=VALID_USER)
    r = client.post("/auth/register", json=VALID_USER)
    assert r.status_code == 400
    assert "Email" in r.json()["detail"]


def test_register_invalid_phone(client):
    r = client.post("/auth/register", json={**VALID_USER, "phone": "0712345678"})
    assert r.status_code == 422


def test_register_weak_password(client):
    r = client.post("/auth/register", json={**VALID_USER, "password": "abc"})
    assert r.status_code == 422


def test_login_success(client):
    client.post("/auth/register", json=VALID_USER)
    r = client.post("/auth/login", json={"email": VALID_USER["email"], "password": VALID_USER["password"]})
    assert r.status_code == 200
    assert "access_token" in r.json()


def test_login_wrong_password(client):
    client.post("/auth/register", json=VALID_USER)
    r = client.post("/auth/login", json={"email": VALID_USER["email"], "password": "wrongpass"})
    assert r.status_code == 401


def test_me_authenticated(client):
    reg = client.post("/auth/register", json=VALID_USER)
    token = reg.json()["access_token"]
    r = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200
    assert r.json()["email"] == VALID_USER["email"]


def test_me_unauthenticated(client):
    r = client.get("/auth/me")
    assert r.status_code == 401


def test_token_refresh(client):
    reg = client.post("/auth/register", json=VALID_USER)
    refresh = reg.json()["refresh_token"]
    r = client.post("/auth/refresh", json={"refresh_token": refresh})
    assert r.status_code == 200
    assert "access_token" in r.json()


def test_logout(client):
    reg = client.post("/auth/register", json=VALID_USER)
    token = reg.json()["access_token"]
    refresh = reg.json()["refresh_token"]
    r = client.post(
        "/auth/logout",
        json={"refresh_token": refresh},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 200
    
    r2 = client.post("/auth/refresh", json={"refresh_token": refresh})
    assert r2.status_code == 401
