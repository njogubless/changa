# Changa
> Group Contribution Management Platform 

Flutter + FastAPI + PostgreSQL | M-Pesa Daraja + Airtel Money

---

## What is Changa?
Changa lets groups pool money for shared projects. Each member sees real-time funding progress, their percentage contribution, and how much is still needed. Projects can be public or private, and teams can be formed within a project.
It comes with premium features like budgeting and more. 

---

## Stack
| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.41 + Dart 3.11 |
| State | Riverpod 2.x |
| HTTP | Dio 5.x |
| Backend | FastAPI 0.111 (Python 3.11) |
| Database | PostgreSQL 15 |
| Auth | JWT + bcrypt |
| Payments | M-Pesa Daraja + Airtel Money |
| DevOps | Docker + Docker Compose |

---

## Project Structure
```
CHANGA/
├── backend/          # FastAPI Python API
│   ├── app/
│   │   ├── core/     # Config, security, JWT
│   │   ├── models/   # Database tables
│   │   ├── routers/  # API endpoints
│   │   ├── schemas/  # Request/response shapes
│   │   └── services/ # M-Pesa, Airtel integrations
│   ├── tests/
│   ├── requirements.txt
│   └── .env.example
├── mobile/           # Flutter app (Clean Architecture)
│   └── lib/
│       ├── core/
│       └── features/ # auth, projects, payments, profile
├── infrastructure/   # Docker, Nginx
├── docs/
└── scripts/
```

---

## Quick Start

### Backend
```bash
cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # fill in your values
uvicorn app.main:app --reload --port 8000
# Docs → http://localhost:8000/docs
```

### Flutter
```bash
cd mobile
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

### Full Stack (Docker)
```bash
docker-compose up --build
```

---

## Key API Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /auth/register | Create account |
| POST | /auth/login | Login → JWT tokens |
| GET | /projects | List public projects |
| POST | /projects | Create project |
| POST | /contributions/mpesa | Pay via M-Pesa |
| POST | /contributions/airtel | Pay via Airtel Money |
| GET | /contributions/status/{ref} | Check payment status |

---

## Android Support
- Minimum: Android 7.0 (API 24)
- Target: Android 14 (API 34)
- Covers 95%+ of Android devices in Kenya

---

## Environment Variables
Copy `backend/.env.example` to `backend/.env` and fill in:
- `SECRET_KEY` — generate with `python3 -c "import secrets; print(secrets.token_hex(32))"`
- `DATABASE_URL` — your PostgreSQL connection string
- `MPESA_CONSUMER_KEY` / `MPESA_CONSUMER_SECRET` — from [developer.safaricom.co.ke](https://developer.safaricom.co.ke)
- `AIRTEL_CLIENT_ID` / `AIRTEL_CLIENT_SECRET` — from [developers.airtel.africa](https://developers.airtel.africa)

---

## Security Rules
- Never commit `.env` — it contains secret keys
- Never commit `venv/` or `build/`
- Always commit `.env.example` (template only)