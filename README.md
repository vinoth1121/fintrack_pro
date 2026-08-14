# FinTrack Pro

**FinTrack Pro** is an AI-powered personal finance management application built with **Flutter** (frontend) and a **Node.js / Express + PostgreSQL** backend. It helps users track income, expenses, budgets, savings goals, subscriptions, and receipts, while an integrated AI assistant delivers smart insights and recommendations.

## Features

- 🔐 Secure authentication (email/password, OTP, biometric unlock, refresh-token rotation)
- 💸 Transaction, income & expense tracking with categories
- 📊 Budgets, savings goals, and subscription management
- 🧾 Receipt scanning and PDF export
- 📈 Interactive analytics dashboards (charts) and reports
- 🌍 Multi-currency support and localization (i18n)
- 🤖 AI chat assistant for financial insights (configurable provider, mock fallback)
- 🔔 Local notifications and reminders
- 🎨 Lumina design system with light/dark themes

## Tech Stack

| Layer        | Technology                                                        |
|--------------|-------------------------------------------------------------------|
| Frontend     | Flutter 3.24+, Dart 3.5+, Riverpod, go_router                    |
| Networking   | Dio (with JWT interceptor & auto-refresh)                         |
| Storage      | flutter_secure_storage, shared_preferences                       |
| Charts/UI    | fl_chart, flutter_animate, google_fonts, cupertino_icons        |
| Backend      | Node.js, Express, JSON Web Tokens (jsonwebtoken)                 |
| Database     | PostgreSQL (via `pg` query pool)                                 |
| AI Provider  | NVIDIA / OpenAI-compatible API (configurable; mock fallback)     |

## Project Structure

This is a monorepo containing the Flutter app and its backend service:

```
fintrack_pro/
├── lib/                 # Flutter application (feature-first architecture)
│   ├── app/            # App bootstrap, theme
│   ├── core/           # Config, network, storage, router, errors, utils
│   ├── data/           # Models, repositories, seed data
│   ├── features/       # Auth, dashboard, expenses, budget, ai_chat, …
│   ├── providers/      # Global Riverpod providers
│   └── shared/         # Reusable widgets (buttons, inputs, feedback, shell)
├── test/               # Flutter widget & unit tests
├── android/ ios/       # Platform-specific native project files
├── backend/            # Node.js / Express REST API + PostgreSQL
│   └── src/            # Routes, middleware, db, utils
├── assets/             # Branding & static assets
└── pubspec.yaml        # Flutter dependencies
```

## Prerequisites

- **Flutter SDK** ≥ 3.24.0 and **Dart** ≥ 3.5.0 — [install guide](https://docs.flutter.dev/get-started/install)
- **Node.js** ≥ 18 and **npm**
- **PostgreSQL** ≥ 14 running locally (or reachable host)
- A device/emulator (Android, iOS, or desktop) for the Flutter app

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/<your-username>/fintrack_pro.git
cd fintrack_pro
```

### 2. Backend setup

```bash
cd backend
npm install
cp .env.example .env      # then edit .env with your real values (never commit it)
```

Create the database and apply the schema/migrations:

```bash
# Ensure a PostgreSQL database named fintrack_pro exists, then:
npm run db:migrate       # create tables
npm run db:seed          # optional: load demo data
npm run dev              # start API on http://localhost:3000
```

> The backend reads configuration from `backend/.env`. See `backend/.env.example` for the full list of variables. **Never commit your real `.env` file** — it contains secrets.

### 3. Flutter app setup

```bash
cd ..                     # back to project root
flutter pub get
flutter run               # launches on the connected device / emulator
```

To run tests:

```bash
flutter test
```

## Configuration & Environment Variables

The backend requires the following environment variables (defined in `backend/.env`):

| Variable                 | Description                                              |
|--------------------------|----------------------------------------------------------|
| `PORT`                   | API server port (default `3000`)                         |
| `DB_HOST` / `DB_PORT`    | PostgreSQL host & port                                   |
| `DB_NAME` / `DB_USER` / `DB_PASS` | Database credentials                        |
| `JWT_ACCESS_SECRET`      | Secret for signing access tokens (use a long random string) |
| `JWT_REFRESH_SECRET`     | Secret for signing refresh tokens                        |
| `JWT_ACCESS_EXPIRES_IN`  | Access token lifetime (e.g. `15m`)                       |
| `JWT_REFRESH_EXPIRES_IN` | Refresh token lifetime (e.g. `7d`)                       |
| `AI_ENABLED`             | `true` to call the AI provider, `false` for mock replies |
| `AI_PROVIDER`            | `nvidia` / `openai` (OpenAI-compatible)                  |
| `AI_BASE_URL`            | Base URL of the AI provider                              |
| `AI_MODEL`               | Model identifier                                          |
| `AI_API_KEY`             | **Secret** API key for the AI provider                   |

The frontend reads its backend base URL from the Dio client configuration (`lib/core/network/dio_client.dart`). Update the endpoint if your API is hosted elsewhere.

## Usage

1. Start the backend (`npm run dev` inside `backend/`).
2. Run the app (`flutter run`).
3. Register a new account or use the seeded demo credentials.
4. Explore the dashboard, add transactions, set budgets/goals, and ask the AI assistant for insights.

## Security Notes

- All secrets and credentials live in environment variables (`backend/.env`), which is excluded from version control via `.gitignore`.
- Auth tokens are stored securely on-device (flutter_secure_storage / shared_preferences) and attached automatically as `Bearer` tokens.
- Refresh tokens are stored in the database and rotated on reuse for invalidation.

## License

This project is provided as-is for personal/educational use. Add a `LICENSE` file if you intend to distribute it.
