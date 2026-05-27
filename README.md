# Joblyx

Assistant de carrière IA pour les professionnels de la tech : génération de **roadmaps de carrière** personnalisées, **coach CV** (analyse de compatibilité offre/CV), **simulateur d'entretien**, et **suivi de candidatures**  le tout propulsé par l'IA.

Le projet est un **monorepo** à trois composants :

| Dossier | Rôle | Stack | Déploiement |
|---|---|---|---|
| [`backend/`](#backend--api-fastapi) | API REST versionnée | FastAPI · PostgreSQL · SQLAlchemy async | Railway |
| [`frontend/`](#frontend--application-mobile) | Application mobile (utilisateurs) | Flutter · Riverpod | Google Play |
| [`panel-admin/`](#panel-admin--console-dadministration) | Console d'administration | React · Vite | Vercel · `admin.joblyx.com` |

```
joblyx_v2/
├── backend/        API FastAPI (auth, IA, roadmap, coach, interview, admin)
├── frontend/       App mobile Flutter
└── panel-admin/    Panel admin React
```

---

## Architecture & flux

```
Mobile (Flutter)  ─┐
                   ├──►  API FastAPI  /v1/client/*  ──►  PostgreSQL
Panel (React)     ─┘                  /v1/admin/*        Cloudflare R2 (fichiers)
                                          │              OpenAI · Resend · Sentry
                                          └── require_admin / require_super_admin
```

- L'API est **versionnée** sous `/v1`, séparée en deux routeurs :
  - `/v1/client/*` — consommé par l'app mobile (auth, users, roadmap, applications, assistant).
  - `/v1/admin/*` — consommé par le panel, protégé globalement par `require_admin`.
- Le mobile et le panel sont **deux applications indépendantes** : aucun code partagé.

---

## Rôles & accès

Trois rôles, résolus depuis la base de données à **chaque requête** (jamais depuis le JWT) :

| Rôle | Accès | Notes |
|---|---|---|
| `user` | App mobile | Utilisateur standard. |
| `admin` | Panel admin (permissions limitées) | Peut désactiver des comptes, gérer les users, consulter stats/audit/erreurs. |
| `super_admin` | Panel admin (accès total) | **Unique**, immuable via l'API (récupération uniquement par SQL direct), **bloqué sur l'app mobile**. |

La suppression définitive d'un compte est réservée au `super_admin`. L'`admin` ne peut que **désactiver** (réversible, révoque les sessions).

---

## Backend — API FastAPI

### Stack

- **FastAPI** + **Uvicorn**, Python 3.13
- **SQLAlchemy 2.0** (async) + **asyncpg**, **PostgreSQL**, migrations **Alembic**
- **Auth** : JWT (access 24 h + refresh 30 j avec rotation), hachage **argon2**
- **IA** : OpenAI — `gpt-4o` (génération roadmap), `gpt-4o-mini` (coach, entretien, extraction de compétences)
- **Stockage** : Cloudflare **R2** (S3-compatible via boto3) pour CV et avatars
- **Email** : **Resend** · **NLP** : spaCy (modèles fr/en) · **PDF** : PyMuPDF (extraction CV)
- **Rate limiting** : slowapi · **Monitoring** : Sentry · **Cron** : APScheduler

### Architecture (clean)

```
api/v1/{client,admin}/   Routeurs (validation, DTO) — fines couches HTTP
        │
services/                Logique métier (auth, roadmap, coach, interview, admin, emailing, storage…)
        │
repositories/            Accès données (SQLAlchemy async)
        │
models/{db,api_schemas}  Modèles ORM & schémas Pydantic
core/                    config, security, database, exceptions, uploads, password
```

Les erreurs métier sont des exceptions nommées centralisées dans `core/exceptions.py` (`DomainError` → `status_code` + `error_code`).

### Lancer en local

```bash
cd backend
python -m venv .venv && source .venv/bin/activate   # Windows : .venv\Scripts\activate
pip install -r requirements.txt
# Crée un fichier .env (voir variables ci-dessous)
alembic upgrade head                                 # applique les migrations
python -m uvicorn app:app --reload --port 8080
```

Au démarrage, l'app applique les migrations Alembic et garantit l'existence du compte `super_admin` (`ADMIN_EMAIL` / `ADMIN_PASSWORD`, source de vérité — le mot de passe est resynchronisé à chaque boot).

### Tests

```bash
cd backend
python -m pytest          # suite unitaire + intégration
```

### Variables d'environnement

Les variables marquées **\*** sont obligatoires (l'app crash explicitement au démarrage si absentes).

| Variable | Description |
|---|---|
| `JWT_SECRET_KEY` * | Clé de signature des JWT |
| `DATABASE_URL` * (ou `DB_URL`) | URL PostgreSQL (`postgresql://…`, convertie en asyncpg) |
| `OPENAI_API_KEY` * | Clé OpenAI |
| `RESEND_API_KEY` * | Clé Resend (envoi d'emails) |
| `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` / `R2_ENDPOINT_URL` * | Identifiants Cloudflare R2 |
| `CORS_ORIGINS` | Origines autorisées, séparées par virgules (ex. `https://admin.joblyx.com`). Vide = aucun navigateur autorisé |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | Compte super_admin bootstrap |
| `SENTRY_DSN`, `SENTRY_ENVIRONMENT`, `SENTRY_API_TOKEN`, `SENTRY_ORG_SLUG`, `SENTRY_PROJECT_SLUG` | Monitoring + page Erreurs du panel |
| `LINKEDIN_CLIENT_ID` / `LINKEDIN_CLIENT_SECRET` / `LINKEDIN_REDIRECT_URI` | OAuth LinkedIn |
| `RESEND_FROM_EMAIL`, `RESEND_FROM_NAME` | Expéditeur des emails (défauts fournis) |
| `ACCESS_TOKEN_EXPIRE_MINUTES`, `REFRESH_TOKEN_EXPIRE_DAYS`, `JWT_ALGORITHM` | Réglages tokens (défauts : 1440, 30, HS256) |
| `RAPIDAPI_KEY`, `FRONTEND_URL` | Optionnels (données marché, liens email) |

### Déploiement

Railway via `Procfile` (`uvicorn app:app`) ou `Dockerfile`. Les migrations s'appliquent au démarrage.

---

## Frontend — Application mobile

### Stack

- **Flutter** (Dart SDK ≥ 3.11)
- **Riverpod 3** (state management) · **Dio** (HTTP + SSE via `CancelToken`)
- **go_router** (navigation, shell + bottom nav) · **flutter_screenutil** (responsive)
- i18n maison (JSON aplati `fr.json` / `en.json`) · **shared_preferences** · **flutter_secure_storage**
- **cached_network_image** · **firebase_crashlytics** · **tutorial_coach_mark** (onboarding guidé)
- **app_links** (deep link OAuth LinkedIn)

### Fonctionnalités (`lib/features/`)

`authentication` · `onboarding` · `roadmap` (dashboard + roadmap IA) · `assistant` (coach CV + simulateur d'entretien) · `applications` (suivi candidatures) · `settings`

> Toutes les fonctions IA affichent le résultat en **streaming textuel (SSE)**, pas un simple spinner.

### Lancer en local

```bash
cd frontend
flutter pub get
flutter run                         # appareil/émulateur connecté
flutter test                        # tests unit + widget
flutter analyze                     # lint
```

L'URL d'API et les secrets sensibles passent par `--dart-define` (ex. `LINKEDIN_CLIENT_ID`).

### Build & release (Google Play)

```bash
flutter build appbundle --release   # AAB signé via android/key.properties
```

Version courante : `1.0.2+7`. Le `super_admin` est refusé à la connexion sur mobile (réservé au panel).

---

## Panel-admin — Console d'administration

### Stack

- **React 19** + **Vite** · **react-router v7** · **axios** (intercepteurs JWT + auto-refresh)
- **recharts** (graphiques) · **lucide-react** (icônes)

### Pages (`src/pages/`)

Dashboard (statistiques + coût OpenAI réel) · Utilisateurs (liste + détail + actions) · Journal d'audit · Erreurs (proxy Sentry)

### Lancer en local

```bash
cd panel-admin
npm install
npm run dev        # http://localhost:5173
npm run build      # build de production (code-splitting des pages)
npm run lint
```

Configurer `VITE_API_URL` (ex. `https://api.joblyx.com`) — valeur figée au build par Vite.

### Déploiement

Vercel, domaine **`admin.joblyx.com`** (DNS Cloudflare en mode *DNS only*). L'origine du panel doit figurer dans `CORS_ORIGINS` du backend.

---

## Conventions du projet

- **Commentaires de code en français**, concis, sans séparateurs décoratifs en longs tirets.
- **Messages de log en anglais.**
- **Exceptions métier nommées et centralisées** dans `core/exceptions.py` (jamais de message string brut dans les services).
- **Images réseau** via `CachedNetworkImageProvider` côté mobile.
- **Fonctions IA** en streaming SSE.
```

