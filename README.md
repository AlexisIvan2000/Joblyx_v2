# Joblyx

AI career assistant for tech professionals: personalized **career roadmap** generation, **resume coach** (job offer/resume compatibility analysis), **interview simulator**, and **application tracking** — all powered by AI.

The project is a **monorepo** with three components:

| Folder | Role | Stack | Deployment |
|---|---|---|---|
| [`backend/`](#backend--fastapi-api) | Versioned REST API | FastAPI · PostgreSQL · SQLAlchemy async | Railway |
| [`frontend/`](#frontend--mobile-app) | Mobile app (end users) | Flutter · Riverpod | Google Play |
| [`panel-admin/`](#panel-admin--admin-console) | Admin console | React · Vite | Vercel · `admin.joblyx.com` |

```
joblyx_v2/
├── backend/        FastAPI API (auth, AI, roadmap, coach, interview, admin)
├── frontend/       Flutter mobile app
└── panel-admin/    React admin panel
```

---

## Architecture & flow

```
Mobile (Flutter)  ─┐
                   ├──►  FastAPI API  /v1/client/*  ──►  PostgreSQL
Panel (React)     ─┘                  /v1/admin/*        Cloudflare R2 (files)
                                          │              OpenAI · Resend · Sentry
                                          └── require_admin / require_super_admin
```

- The API is **versioned** under `/v1`, split into two routers:
  - `/v1/client/*` — consumed by the mobile app (auth, users, roadmap, applications, assistant).
  - `/v1/admin/*` — consumed by the panel, globally protected by `require_admin`.
- The mobile app and the panel are **two independent applications**: no shared code.

---

## Roles & access

Three roles, resolved from the database on **every request** (never from the JWT):

| Role | Access | Notes |
|---|---|---|
| `user` | Mobile app | Standard user. |
| `admin` | Admin panel (limited permissions) | Can deactivate accounts, manage users, view stats/audit/errors. |
| `super_admin` | Admin panel (full access) | **Unique**, immutable via the API (recovery only through direct SQL), **blocked on the mobile app**. |

Permanent account deletion is reserved for the `super_admin`. An `admin` can only **deactivate** (reversible, revokes sessions).

---

## Backend — FastAPI API

### Stack

- **FastAPI** + **Uvicorn**, Python 3.13
- **SQLAlchemy 2.0** (async) + **asyncpg**, **PostgreSQL**, **Alembic** migrations
- **Auth**: JWT (24 h access + 30 d refresh with rotation), **argon2** hashing
- **AI**: OpenAI — `gpt-4o` (roadmap generation), `gpt-4o-mini` (coach, interview, skill extraction)
- **Storage**: Cloudflare **R2** (S3-compatible via boto3) for resumes and avatars
- **Email**: **Resend** · **NLP**: spaCy (fr/en models) · **PDF**: PyMuPDF (resume extraction)
- **Rate limiting**: slowapi · **Monitoring**: Sentry · **Cron**: APScheduler

### Architecture (clean)

```
api/v1/{client,admin}/   Routers (validation, DTOs) — thin HTTP layers
        │
services/                Business logic (auth, roadmap, coach, interview, admin, emailing, storage…)
        │
repositories/            Data access (SQLAlchemy async)
        │
models/{db,api_schemas}  ORM models & Pydantic schemas
core/                    config, security, database, exceptions, uploads, password
```

Business errors are named exceptions centralized in `core/exceptions.py` (`DomainError` → `status_code` + `error_code`).

### Run locally

```bash
cd backend
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
# Create a .env file (see variables below)
alembic upgrade head                                 # apply migrations
python -m uvicorn app:app --reload --port 8080
```

On startup, the app applies Alembic migrations and guarantees the existence of the `super_admin` account (`ADMIN_EMAIL` / `ADMIN_PASSWORD`, source of truth — the password is re-synced on every boot).

### Tests

```bash
cd backend
python -m pytest          # unit + integration suite
```

### Environment variables

Variables marked with **\*** are required (the app crashes explicitly at startup if missing).

| Variable | Description |
|---|---|
| `JWT_SECRET_KEY` * | JWT signing key |
| `DATABASE_URL` * (or `DB_URL`) | PostgreSQL URL (`postgresql://…`, converted to asyncpg) |
| `OPENAI_API_KEY` * | OpenAI key |
| `RESEND_API_KEY` * | Resend key (email sending) |
| `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` / `R2_ENDPOINT_URL` * | Cloudflare R2 credentials |
| `CORS_ORIGINS` | Allowed origins, comma-separated (e.g. `https://admin.joblyx.com`). Empty = no browser allowed |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | Bootstrap super_admin account |
| `SENTRY_DSN`, `SENTRY_ENVIRONMENT`, `SENTRY_API_TOKEN`, `SENTRY_ORG_SLUG`, `SENTRY_PROJECT_SLUG` | Monitoring + panel Errors page |
| `LINKEDIN_CLIENT_ID` / `LINKEDIN_CLIENT_SECRET` / `LINKEDIN_REDIRECT_URI` | LinkedIn OAuth |
| `RESEND_FROM_EMAIL`, `RESEND_FROM_NAME` | Email sender (defaults provided) |
| `ACCESS_TOKEN_EXPIRE_MINUTES`, `REFRESH_TOKEN_EXPIRE_DAYS`, `JWT_ALGORITHM` | Token settings (defaults: 1440, 30, HS256) |
| `RAPIDAPI_KEY`, `FRONTEND_URL` | Optional (market data, email links) |

### Deployment

Railway via `Procfile` (`uvicorn app:app`) or `Dockerfile`. Migrations are applied at startup.

---

## Frontend — Mobile app

### Stack

- **Flutter** (Dart SDK ≥ 3.11)
- **Riverpod 3** (state management) · **Dio** (HTTP + SSE via `CancelToken`)
- **go_router** (navigation, shell + bottom nav) · **flutter_screenutil** (responsive)
- Custom i18n (flattened JSON `fr.json` / `en.json`) · **shared_preferences** · **flutter_secure_storage**
- **cached_network_image** · **firebase_crashlytics** · **tutorial_coach_mark** (guided onboarding)
- **app_links** (LinkedIn OAuth deep link)

### Features (`lib/features/`)

`authentication` · `onboarding` · `roadmap` (dashboard + AI roadmap) · `assistant` (resume coach + interview simulator) · `applications` (application tracking) · `settings`

> All AI features display results via **text streaming (SSE)**, not just a spinner.

### Run locally

```bash
cd frontend
flutter pub get
flutter run                         # connected device/emulator
flutter test                        # unit + widget tests
flutter analyze                     # lint
```

The API URL and sensitive secrets are passed via `--dart-define` (e.g. `LINKEDIN_CLIENT_ID`).

### Build & release (Google Play)

```bash
flutter build appbundle --release   # AAB signed via android/key.properties
```

Current version: `1.0.2+7`. The `super_admin` is rejected at login on mobile (panel only).

---

## Panel-admin — Admin console

### Stack

- **React 19** + **Vite** · **react-router v7** · **axios** (JWT interceptors + auto-refresh)
- **recharts** (charts) · **lucide-react** (icons)

### Pages (`src/pages/`)

Dashboard (statistics + actual OpenAI cost) · Users (list + detail + actions) · Audit log · Errors (Sentry proxy)

### Run locally

```bash
cd panel-admin
npm install
npm run dev        # http://localhost:5173
npm run build      # production build (per-page code splitting)
npm run lint
```

Set `VITE_API_URL` (e.g. `https://api.joblyx.com`) — value baked in at build time by Vite.

### Deployment

Vercel, domain **`admin.joblyx.com`** (Cloudflare DNS in *DNS only* mode). The panel's origin must be included in the backend's `CORS_ORIGINS`.

---

## Project conventions

- **Code comments in French**, concise, no decorative long-dash separators.
- **Log messages in English.**
- **Named, centralized business exceptions** in `core/exceptions.py` (never raw string messages in services).
- **Network images** via `CachedNetworkImageProvider` on mobile.
- **AI features** streamed via SSE.
