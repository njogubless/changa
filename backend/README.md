# Changa Backend API 🌿

> *Fellow developer — building something for your people is one of the most rewarding things you can do. This backend exists so you can focus on what makes Changa unique, not the plumbing.*

Changa is a **group contribution management platform** built for the Kenyan market. Think chamas, project fundraisers, community drives — made digital, transparent, and easy to pay for using M-Pesa and Airtel Money.

This FastAPI backend handles everything under the hood: authentication, project management, team coordination, payment initiation, and real-time contribution tracking.

---

## What's Inside

This isn't a toy API. Here's what you get out of the box:

- **FastAPI 0.111** — async Python web framework with automatic OpenAPI docs at `/docs`
- **PostgreSQL + SQLAlchemy 2.0** — production-grade relational database with a clean ORM
- **JWT Authentication** — access tokens (30 min) + refresh tokens (7 days) with rotation
- **M-Pesa Daraja STK Push** — send payment prompts directly to users' phones
- **Airtel Money API** — full Airtel payment initiation and callback handling
- **Public & Private Projects** — visibility controls and invite-only membership
- **Team Management** — create teams within projects, track team contributions
- **Real-time Contribution Stats** — percentage funded, deficit, per-user share
- **Anonymous Projects** — contributor identities hidden from other members
- **Docker + Docker Compose** — run the entire stack with one command
- **Pytest test suite** — auth flow tests included, pattern established for the rest

---

## The User Journey

Understanding the flows will help you extend them confidently.

### Flow 1: New User Registers and Contributes

This is the happy path.

1. User sends `POST /auth/register` with name, email, phone (254XXXXXXXXX format), password
2. Server validates, hashes the password with bcrypt, saves to PostgreSQL
3. User sends `POST /auth/login` — server returns `access_token` + `refresh_token`
4. User browses `GET /projects` — sees all public projects
5. User picks a project, taps "Contribute KES 500 via M-Pesa"
6. Flutter app calls `POST /contributions/mpesa` with amount + phone
7. Server generates an internal reference (e.g. `MPESA-A3F7B2D1`), saves `status=PENDING`
8. Server calls Safaricom's Daraja STK Push API
9. User's phone vibrates — M-Pesa prompt appears, they enter PIN
10. Safaricom calls `POST /payments/mpesa/callback` with the result
11. Server updates `status=SUCCESS`, adds amount to `project.raised_amount`
12. Flutter polls `GET /contributions/status/MPESA-A3F7B2D1` every 3 seconds
13. User sees the success screen with their receipt number

### Flow 2: Token Expiry (Invisible to User)

Access tokens expire after 30 minutes. Here's what happens:

1. Flutter makes any API call — server returns `401 Unauthorized`
2. The Dio interceptor in Flutter catches the 401 automatically
3. Interceptor calls `POST /auth/refresh` with the refresh token
4. Server returns a new access token
5. Interceptor retries the original request with the new token
6. User never sees a login screen

### Flow 3: Private Project Access

1. Project owner creates project with `visibility: private`
2. Owner invites members via `POST /projects/{id}/members` (by email or phone)
3. Only invited members can see the project in their list
4. Anonymous flag hides contributor names from each other (but not from the owner)

---

## Project Structure

```
backend/
├── app/
│   ├── main.py                   ← Entry point: app creation, CORS, router registration
│   ├── database.py               ← SQLAlchemy engine, SessionLocal, Base, get_db dependency
│   ├── core/
│   │   ├── config.py             ← All settings loaded from .env via Pydantic BaseSettings
│   │   └── security.py          ← bcrypt hashing, JWT creation/verification, auth dependency
│   ├── models/
│   │   └── models.py             ← All 7 database tables: User, Project, Team, Contribution...
│   ├── schemas/
│   │   ├── auth.py               ← Pydantic shapes for request/response (register, login, tokens)
│   │   └── projects.py          ← Pydantic shapes for projects, teams, contributions, payments
│   ├── routers/
│   │   ├── auth.py               ← POST /auth/register, /login, /refresh, /logout, /me
│   │   ├── projects.py          ← CRUD for projects, teams, membership management
│   │   └── payments.py          ← M-Pesa + Airtel initiation, callbacks, status polling
│   └── services/
│       ├── mpesa.py              ← Daraja OAuth, STK Push, callback processing
│       └── airtel.py            ← Airtel Money payment initiation and callback handling
├── tests/
│   └── test_auth.py             ← 10 auth test cases (register, login, token, protected routes)
├── requirements.txt
├── Dockerfile
├── .env.example                 ← Template — copy to .env and fill in your keys
└── README.md
```

---

## Getting Started

### Prerequisites

- Python 3.11+
- PostgreSQL 15+ (or Docker)
- A Safaricom Daraja account for M-Pesa ([developer.safaricom.co.ke](https://developer.safaricom.co.ke))
- An Airtel Africa developer account for Airtel Money ([developers.airtel.africa](https://developers.airtel.africa))

### Option A: Run with Docker (Recommended)

This starts the API, PostgreSQL, and PgAdmin in one command.

```bash
# Clone and enter the project
git clone https://github.com/your-org/changa.git
cd changa

# Copy and fill in environment variables
cp backend/.env.example backend/.env

# Start everything
docker-compose up --build
```

Your API is live at **http://localhost:8000**
Interactive docs at **http://localhost:8000/docs**
PgAdmin (database GUI) at **http://localhost:5050**

### Option B: Run Locally

```bash
cd backend

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate       # Linux/macOS
# venv\Scripts\activate        # Windows

# Install dependencies
pip install -r requirements.txt

# Set up environment
cp .env.example .env
# Edit .env — at minimum set SECRET_KEY and DATABASE_URL

# Generate a strong SECRET_KEY
python3 -c "import secrets; print(secrets.token_hex(32))"

# Create the database (PostgreSQL must be running)
createdb changa_db

# Start the server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

---

## Environment Variables

Copy `.env.example` to `.env` and configure:

```env
# App
APP_NAME=Changa
DEBUG=True
SECRET_KEY=generate-this-with-secrets.token_hex-32

# Database
DATABASE_URL=postgresql://postgres:password@localhost:5432/changa_db

# JWT
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7
ALGORITHM=HS256

# M-Pesa Daraja (get from developer.safaricom.co.ke)
MPESA_CONSUMER_KEY=your_key_here
MPESA_CONSUMER_SECRET=your_secret_here
MPESA_SHORTCODE=174379                  # Use 174379 for sandbox testing
MPESA_PASSKEY=your_passkey_here
MPESA_CALLBACK_URL=https://your-domain.com/payments/mpesa/callback
MPESA_BASE_URL=https://sandbox.safaricom.co.ke

# Airtel Money (get from developers.airtel.africa)
AIRTEL_CLIENT_ID=your_id_here
AIRTEL_CLIENT_SECRET=your_secret_here
AIRTEL_BASE_URL=https://openapiuat.airtel.africa
AIRTEL_CALLBACK_URL=https://your-domain.com/payments/airtel/callback
```

> **Payment callbacks need a public URL.** During local development, use [ngrok](https://ngrok.com) to expose your local server:
> ```bash
> ngrok http 8000
> # Copy the https URL → paste into MPESA_CALLBACK_URL and AIRTEL_CALLBACK_URL
> ```

---

## API Reference

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/auth/register` | Create a new account |
| `POST` | `/auth/login` | Login → receive JWT tokens |
| `POST` | `/auth/refresh` | Get new access token using refresh token |
| `POST` | `/auth/logout` | Revoke refresh token |
| `GET` | `/auth/me` | Get current user profile |
| `POST` | `/auth/change-password` | Change account password |

### Projects

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/projects` | List public projects (paginated, searchable) |
| `POST` | `/projects` | Create a new project |
| `GET` | `/projects/{id}` | Full project details + funding progress |
| `PUT` | `/projects/{id}` | Update project (owner only) |
| `DELETE` | `/projects/{id}` | Delete or cancel project |
| `GET` | `/projects/{id}/contributors` | List contributors + their percentages |
| `POST` | `/projects/{id}/members` | Invite member to private project |
| `POST` | `/projects/{id}/teams` | Create a team |
| `GET` | `/projects/{id}/teams` | List all teams in a project |
| `POST` | `/projects/{id}/teams/{team_id}/join` | Join a team |

### Payments & Contributions

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/contributions/mpesa` | Initiate M-Pesa STK Push |
| `POST` | `/contributions/airtel` | Initiate Airtel Money payment |
| `GET` | `/contributions/status/{ref}` | Poll payment status |
| `GET` | `/users/me/contributions` | My contribution history + stats |
| `POST` | `/payments/mpesa/callback` | Safaricom callback (internal) |
| `POST` | `/payments/airtel/callback` | Airtel callback (internal) |

---

## Database Schema

Seven tables, clean relationships:

```
users               ← accounts, phone numbers, hashed passwords
projects            ← title, target, raised_amount, visibility, status
project_members     ← links users ↔ private projects (owner/admin/member)
teams               ← sub-groups within a project
team_members        ← links users ↔ teams (admin/member)
contributions       ← every payment attempt with status tracking
refresh_tokens      ← stored tokens for logout and rotation
```

Every project model exposes computed properties:
- `percentage_funded` — `(raised / target) × 100`
- `deficit` — `target - raised` (never negative)
- `is_funded` — `raised >= target`

---

## Running Tests

```bash
cd backend
source venv/bin/activate
pytest tests/ -v
```

The test suite uses SQLite (no PostgreSQL needed) and covers registration, login, duplicate detection, phone validation, password rules, protected routes, and health checks.

---

## The Honest Limitations

This is a strong foundation, not a finished product. Know what you're getting into:

**No email verification.** Users register and can immediately log in. A real app needs an email confirmation step. You'll want to add a `is_verified` flow with a verification token sent via email.

**No password reset.** The `change-password` endpoint exists, but there's no "forgot password" email flow. This is straightforward to add but requires an email service like Resend or SendGrid.

**No subscription billing.** The payment system handles one-time contributions beautifully. It does not handle recurring billing, subscription renewals, or automatic expiry. You'd add a `subscription_status` and `subscription_ends_at` to your user model and check it in a middleware.

**Single currency (KES).** The system is wired for Kenyan Shillings throughout. Multi-currency is a bigger architectural change, though it starts with adding a `currency` field to projects (which is already there) and routing payments accordingly.

**In-memory sessions, not Redis.** For high traffic, consider adding Redis for session/token storage. The current setup works fine for thousands of users on a single server.

**Callbacks require HTTPS.** Safaricom and Airtel will not send callbacks to `http://` URLs. You need either a real domain with SSL or ngrok for local development.

---

## The Roadmap

Here's how you take this from boilerplate to production SaaS:

**Step 1 — Email verification.** Add a `verification_token` column, send an email on register, create a `POST /auth/verify-email` endpoint. Use [Resend](https://resend.com) — their free tier is generous.

**Step 2 — Password reset.** `POST /auth/forgot-password` generates a time-limited token, emails it, `POST /auth/reset-password` consumes it.

**Step 3 — Subscription model.** Add `subscription_status` and `subscription_ends_at` to the User model. Wire up the webhook to set these when a payment succeeds. Add a middleware to check subscription validity on protected routes.

**Step 4 — Alembic migrations.** Right now, `Base.metadata.create_all()` creates tables on startup. For production, generate proper Alembic migration files so schema changes are tracked and reversible.

**Step 5 — Push notifications.** When a contribution succeeds, notify the project owner. Firebase Cloud Messaging + a `device_tokens` table gets you there.

**Step 6 — Admin panel.** Build a simple `/admin` section for viewing projects, users, and transactions. FastAPI + a simple HTML template, or connect to a tool like Metabase.

---

## A Final Word

The hardest part of building for your community is believing it's worth doing. You've already cleared that bar.

The Daraja integration, the JWT rotation, the contribution math — that's all handled. What remains is yours to build: the features, the community, the thing that makes Changa *yours*.

This is just the beginning.

**Go build something people will use.**