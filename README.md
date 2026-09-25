<p align="center">
  <img src="assets/branding/logo_transparent.png" alt="FinTrack Pro logo" width="140"/>
</p>

<h1 align="center">FinTrack Pro</h1>

<p align="center">
  <b>AI-powered personal finance management — track, budget, save, and grow.</b><br/>
  A complete mobile + backend + AI project built with Flutter, Node.js, and PostgreSQL.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.24%2B-02569B?logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.5%2B-0175C2?logo=dart&logoColor=white" alt="Dart"/>
  <img src="https://img.shields.io/badge/Node.js-18%2B-339933?logo=nodedotjs&logoColor=white" alt="Node.js"/>
  <img src="https://img.shields.io/badge/PostgreSQL-14%2B-4169E1?logo=postgresql&logoColor=white" alt="PostgreSQL"/>
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License"/>
</p>

---

## 📖 What is FinTrack Pro?

FinTrack Pro is a **full-stack personal finance application**. In plain terms, it is a money-management app that anyone can install on their phone to understand and control their day-to-day finances:

- **Record** every expense and income — typed, spoken, or scanned from a receipt.
- **Plan** with budgets, savings goals, and subscription tracking.
- **Understand** with analytics charts, reports, and an AI assistant that explains your money in natural language.
- **Stay safe** with secure authentication, encrypted token storage, and a privacy-first design where all financial data stays on your device and your own server.

The project is intentionally split into two parts:

| Part | What it does |
|------|--------------|
| **📱 Mobile app** (`lib/`) | The Flutter application users interact with — dashboards, forms, charts, offline intelligence |
| **🖥️ REST API** (`backend/`) | A Node.js/Express + PostgreSQL server that stores data, handles authentication, and optionally fronts an AI provider |

The app is **local-first**: every smart feature (voice parsing, receipt parsing, insights, weekly summaries, and the chat assistant) works **completely offline, with no AI API key**, using the on-device engine in `lib/core/services/local_intelligence.dart`. Connecting a backend with an AI provider simply upgrades the experience.

---

## ✨ Features

### 💰 Money management
- **Expenses & income tracking** — categories, filters, search, payment methods, locations, tags
- **Budgets** — per-category budgets with progress rings and overspend alerts
- **Savings goals** — targets, deadlines, progress, and milestone notifications
- **Subscriptions** — recurring bills with next-due dates and billing cycles
- **Family accounts** — shared budgets and multi-member overview via the `/api/family` endpoints
- **Multi-currency** — track in INR and other currencies with locale-aware formatting

### 🤖 Intelligence
- **AI chat assistant (Lumina)** — ask "How much did I spend this month?" and get answers grounded in your own data; works offline via the local engine, or online via a Gemini / OpenAI-compatible provider
- **Voice & typed transaction entry** — "Spent 250 on dinner yesterday" becomes a structured transaction automatically
- **Receipt scanning** — photo capture with parsed merchant, date, and total, pre-filled into the transaction form
- **Proactive insights & weekly summaries** — spending forecasts, anomalies, and headlines computed on-device
- **Financial calculators** — EMI, GST, savings, and a basic calculator hub
- **Currency converter** — live cross-currency conversion

### 🔐 Security & quality
- **JWT authentication** with refresh-token rotation and short-lived access tokens
- **Password hashing** (bcrypt) — passwords are never stored in plain text
- **Encrypted on-device token storage** (flutter_secure_storage)
- **Hardened API** — Helmet security headers, rate limiting, CORS, and Zod request validation
- **Tested** — Flutter widget, unit, and flow tests (`flutter test`)

### 🌍 Experience
- **7 languages** — English, हिन्दी, தமிழ், Français, Español, Deutsch, 日本語
- **Lumina design system** — premium light/dark themes, smooth animations, responsive layout
- **Local notifications** — budget alerts, bill reminders, goal milestones
- **Reports & export** — financial summary (PDF) and all transactions (CSV)

---

## 🏗️ Architecture

```
┌─────────────────────────┐         ┌──────────────────────────────┐
│      Flutter app        │  HTTPS  │      Node.js / Express       │
│  ( Riverpod + go_router)│ ──────► │  REST API  ( 17 modules  )   │
│                         │   JWT   │                              │
│  • Screens & widgets    │         │  • Auth (JWT + refresh)      │
│  • Local intelligence   │         │  • Finance domain routes     │
│    (offline engine)     │         │  • Validation (Zod)          │
│  • Secure storage       │         │  • Security (Helmet, rate-   │
└─────────────────────────┘         │    limit, CORS)              │
                                    └──────────────┬───────────────┘
                                                   │ SQL (pg pool)
                                            ┌──────▼────────┐
                                            │   PostgreSQL  │
                                            └──────┬────────┘
                                                   │ optional
                                            ┌──────▼──────────────┐
                                            │  AI provider        │
                                            │  (Gemini/OpenAI-    │
                                            │   compatible API)   │
                                            └─────────────────────┘
```

**Data flow in one sentence:** the app records a transaction (typed, spoken, or scanned) → the local engine parses it instantly → it is stored in PostgreSQL through the authenticated REST API → analytics, budgets, goals, and the AI assistant read that same data to keep every screen and insight consistent.

---

## 🧱 Project structure

```
fintrack_pro/
├── lib/                        # Flutter application (feature-first architecture)
│   ├── app/                    # App bootstrap & theming
│   ├── core/
│   │   ├── config/             # Central app & server configuration
│   │   ├── network/            # Dio client (JWT interceptor & auto-refresh)
│   │   ├── router/             # go_router navigation & guards
│   │   ├── services/           # local_intelligence.dart (offline AI engine)
│   │   ├── storage/            # Token storage
│   │   ├── theme/              # Lumina design system
│   │   └── utils/              # Formatters, responsive helpers, toasts
│   ├── data/                   # Models, repositories, seed data
│   ├── features/               # One folder per feature: auth, dashboard,
│   │                           #   expenses, budget, savings, subscriptions,
│   │                           #   analytics, reports, ai_chat, family, …
│   ├── providers/              # Global Riverpod providers
│   ├── l10n/                   # 7-language localization
│   └── shared/                 # Reusable widgets (buttons, inputs, shell)
├── backend/                    # Node.js / Express REST API
│   ├── src/
│   │   ├── routes/             # 17 route modules (auth, transactions, ai, …)
│   │   ├── middleware/         # auth, validation (Zod), error handler
│   │   ├── db/                 # PostgreSQL pool, migrations, seed
│   │   └── utils/              # JWT helpers
│   ├── .env.example            # Template for your own .env (never commit .env)
│   └── package.json
├── test/                       # Flutter widget, unit & flow tests
├── android/  ios/              # Native platform projects
├── assets/                     # Branding & static assets
└── pubspec.yaml                # Flutter dependencies
```

---

## 🚀 Getting started

### Prerequisites

| Tool | Version | Install guide |
|------|---------|---------------|
| Flutter SDK | ≥ 3.24.0 | [docs.flutter.dev/get-started](https://docs.flutter.dev/get-started/install) |
| Dart | ≥ 3.5.0 (ships with Flutter) | included |
| Node.js + npm | ≥ 18 | [nodejs.org](https://nodejs.org/) |
| PostgreSQL | ≥ 14 | [postgresql.org](https://www.postgresql.org/download/) |
| A device or emulator | Android / iOS / desktop | — |

### 1️⃣ Clone the repository

```bash
git clone https://github.com/vinoth1121/fintrack_pro.git
cd fintrack_pro
```

### 2️⃣ Set up the backend

```bash
cd backend
npm install
cp .env.example .env        # then edit .env with YOUR real values
```

Create a PostgreSQL database named `fintrack_pro`, then load the schema and start the API:

```bash
npm run db:migrate          # create all tables
npm run db:seed             # optional: load demo data
npm run dev                 # API running on http://localhost:3000
```

> ⚠️ **Never commit your real `.env` file.** It holds database credentials, JWT secrets, and your AI API key. It is already excluded from version control via `.gitignore` — keep it that way.

### 3️⃣ Set up the Flutter app

```bash
cd ..                       # back to the project root
flutter pub get
flutter run                 # launches on the connected device / emulator
```

**Connecting the app to the backend:**

| Where the app runs | Backend URL to use |
|--------------------|--------------------|
| Android emulator | `http://10.0.2.2:3000` (default, works out of the box) |
| Physical device | `flutter run --dart-define=API_BASE_URL=http://<your-lan-ip>:3000` — or set it once in **Settings → Server connection** |
| Web | `http://localhost:3000` (default) |

### 4️⃣ Run the tests

```bash
flutter test                # widget, unit & flow tests
```

---

## ⚙️ Environment variables

The backend reads its configuration from `backend/.env` (see `backend/.env.example` for the full annotated template):

| Variable | Description |
|----------|-------------|
| `PORT` | API server port (default `3000`) |
| `DB_HOST` / `DB_PORT` | PostgreSQL host & port |
| `DB_NAME` / `DB_USER` / `DB_PASS` | Database name & credentials |
| `JWT_ACCESS_SECRET` | Secret for signing access tokens — use a long random string (`openssl rand -hex 32`) |
| `JWT_REFRESH_SECRET` | Secret for signing refresh tokens |
| `JWT_ACCESS_EXPIRES_IN` | Access token lifetime (e.g. `15m`) |
| `JWT_REFRESH_EXPIRES_IN` | Refresh token lifetime (e.g. `7d`) |
| `AI_ENABLED` | `true` to call the AI provider, `false` for offline mock replies |
| `AI_PROVIDER` | `google`, `nvidia`, or `openai` (OpenAI-compatible) |
| `AI_BASE_URL` | Base URL of the AI provider's chat-completions endpoint |
| `AI_MODEL` | Model identifier (e.g. `gemini-2.5-flash`) |
| `AI_API_KEY` | **Secret** API key for the AI provider |

---

## 🔌 API overview

Base URL: `http://localhost:3000/api` — all finance routes require a `Bearer` access token.

| Group | Endpoints |
|-------|-----------|
| Auth | `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `GET /auth/me`, `POST /auth/forgot-password`, `POST /auth/reset-password` |
| Finance | `/transactions`, `/expenses`, `/income`, `/budgets`, `/categories`, `/savings`, `/subscriptions`, `/accounts` |
| Intelligence | `/ai` (chat & insights), `/analytics`, `/calculator` |
| Utility | `/notifications`, `/notes`, `/family`, `/exports`, `/currency`, `/health` |

---

## 📸 Screenshots

The `assets/branding/` folder contains the app logo. Screenshots of the dashboard, expenses, budgets, analytics, AI chat, receipt scanner, voice entry, and the Tamil-language interface are captured on a Pixel device and available in the project report.

<details>
<summary>Screen catalogue</summary>

| # | Screen | What it shows |
|---|--------|---------------|
| 1 | Splash + Onboarding | Brand gradient, 4-slide introduction |
| 2 | Login / Register / OTP | Email + password auth with 6-digit OTP |
| 3 | Dashboard | Net worth, health score, recent transactions, budget rings |
| 4 | Expenses | Category chips, filters, search |
| 5 | Budget | Per-category progress rings, overspend alerts |
| 6 | Savings goals | Targets, deadlines, milestones |
| 7 | Subscriptions | Recurring bills, next-due dates |
| 8 | Analytics | Trend charts, category breakdown, 6-month sparklines |
| 9 | AI Insights | Proactive AI-generated observation cards |
| 10 | AI Chat | Conversational assistant grounded in your data |
| 11 | Receipt scanner | Photo capture + extracted fields |
| 12 | Voice entry | Transcription with parsed amount/category/note |
| 13 | Multi-language | Tamil (and 6 more languages) with localized formatting |
| 14 | Settings | Profile, currency, theme, language, server connection |

</details>

---

## 🛡️ Security notes

- **All secrets live in environment files** (`backend/.env`), excluded from version control via `.gitignore`. The template `backend/.env.example` contains only placeholders.
- **Passwords** are hashed with bcrypt before storage and never transmitted in plain text.
- **Auth tokens** are stored in encrypted on-device storage (flutter_secure_storage) and attached automatically as `Bearer` headers; refresh tokens are rotated on reuse so a leaked token self-invalidates.
- **The AI API key stays on the server** — it is never shipped inside the mobile app; the app talks to your backend, and the backend talks to the AI provider.
- **The API is hardened** with Helmet security headers, rate limiting, CORS, and Zod request validation.

---

## 🗺️ Roadmap

- [ ] Expand language support toward all 22 scheduled Indian languages
- [ ] Integration with India's Account Aggregator framework
- [ ] Cloud deployment guide (Docker + managed PostgreSQL)
- [ ] Biometric app-lock on all platforms
- [ ] Larger user study measuring financial-health improvement

---

## 🤝 Contributing

1. Fork the repository and create your branch from `main`.
2. Run `flutter analyze` and `flutter test` before opening a pull request — both must pass with no issues.
3. Keep pull requests focused: one feature or fix per PR.
4. **Never commit secrets** — `.env`, API keys, and credentials stay out of version control.

---

## 📄 License

This project is released under the [MIT License](LICENSE) for educational and personal use.
