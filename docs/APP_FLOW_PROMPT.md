# FinTrack Pro — Full App Flow Prompt (Build-From-Scratch Spec)

Use this prompt to (re)generate or reason about the **entire FinTrack Pro** application: an AI‑powered personal finance management app with a Flutter frontend and a Node.js/Express + PostgreSQL backend.

---

## 0. Product Goal

Build **FinTrack Pro**, a cross‑platform (Android/iOS/desktop/web capable) personal finance app that lets a user:
- Register / log in (email+password, OTP, phone OTP, biometric, passkey) and manage a secure session.
- Track income, expenses, and transactions across categories and accounts.
- Set budgets, savings goals, and manage recurring subscriptions.
- Scan receipts and use voice input to create transactions.
- Take notes, manage family sharing, and view local notifications/reminders.
- Use multi‑currency support and a localized UI (en, es, fr, de, hi, ta, ja).
- Ask an AI assistant ("Lumina") for insights derived **only** from the user's own data, with graceful mock fallback.
- View interactive analytics dashboards and export reports (CSV/PDF).

Tone/design: "Lumina" design system, light/dark themes, smooth animated transitions.

---

## 1. Tech Stack

**Frontend**
- Flutter 3.24+, Dart 3.5+
- State: `flutter_riverpod` (StateNotifier + providers), `go_router` for routing
- Network: `dio` (JWT interceptor + auto‑refresh), `flutter_secure_storage` + `shared_preferences`
- UI: `fl_chart`, `flutter_animate`, `google_fonts`, `cupertino_icons`, `intl`
- Misc: `image_picker`, `permission_handler`, `pdf`, `share_plus`, `speech_to_text`, `flutter_local_notifications`, `url_launcher`, `uuid`

**Backend**
- Node.js + Express 4, `pg` (PostgreSQL pool), `jsonwebtoken`, `bcryptjs`, `zod`, `multer`, `helmet`, `cors`, `express-rate-limit`, `morgan`, `dotenv`, `uuid`
- Tests: `jest` + `supertest`
- AI: OpenAI‑compatible chat completions API (NVIDIA/OpenAI configurable), with mock fallback

---

## 2. High‑Level Architecture

```
fintrack_pro/
├── lib/                 # Flutter app (feature-first)
│   ├── app/             # bootstrap (app.dart), theme, router
│   ├── core/            # config, network, storage, router, errors, utils, services, widgets
│   ├── data/            # models, repositories, seed data
│   ├── features/        # auth, dashboard, expenses, income, budget, analytics,
│   │                   #   savings, subscriptions, notes, currency, calculator,
│   │                   #   ai_chat, reports, notifications, settings, profile,
│   │                   #   onboarding, splash, family, receipts, voice, insights, transactions
│   ├── providers/       # global Riverpod providers (fintrack_provider, auth_provider, family_provider)
│   ├── shared/          # reusable widgets (buttons, inputs, feedback, shell)
│   └── l10n/            # arb + generated localizations + locale files
├── backend/             # Node.js REST API
│   └── src/
│       ├── server.js    # entrypoint (verifies DB, listens)
│       ├── app.js       # express app, middleware, route mounting (/api/x AND /x)
│       ├── db/          # pool.js, migrate.js, seed.js, fix_schema.js
│       ├── middleware/   # auth.js, validate.js, errorHandler.js
│       ├── routes/       # 16 route modules
│       ├── utils/        # jwt.js
│       └── test_*.js / tmp_*.js
├── android/ ios/         # native project files
├── assets/ docs/ test/   # branding, guides, flutter tests
└── pubspec.yaml
```

**Data flow:** Flutter UI → Riverpod providers → repositories (`fintrack_repository`, `auth_repository`, feature repos) → Dio → Express routes → `authenticate` middleware → Postgres. The central `fintrackProvider` holds all domain state, persists to `SharedPreferences`, and does **optimistic local updates** then syncs to the server (rolling back on failure).

---

## 3. Complete User Flow (from scratch)

### 3.1 Launch / Onboarding
1. `main()` initializes `WidgetsFlutterBinding`, applies any stored server URL override (`ServerConfig.applyStoredOverride`), and inits `NotificationService` (non‑fatal if OS notifications unavailable). Boots `ProviderScope(FinTrackApp())`.
2. `FinTrackApp` builds `MaterialApp.router` with `app_router` (go_router), light/dark themes, and the 7 locales.
3. Initial route = `/` → **SplashScreen** → decides next step.
4. If not onboarded → **OnboardingScreen** (`/onboarding`).
5. Auth gate (currently a **TODO stub** — `redirect` returns null; implement: read `authProvider.isAuthenticated` and `fintrackProvider.onboardingDone`).

### 3.2 Authentication flow
- **Login** (`/login`): email+password → `AuthRemoteDataSource.login` → stores tokens via `TokenStorage`.
- **Register** (`/register`): fullName/email/password → backend creates user (currency defaults to `INR`), returns access+refresh tokens + user.
- **OTP verify** (`/otp-verification`, receives email via `state.extra`): send OTP (printed to server logs in dev) → verify → tokens issued, email marked verified.
- **Forgot / reset password** (`/forgot-password`, `/reset-password`): OTP emailed (dev: logged), reset updates `password_hash` and revokes refresh tokens.
- **Phone OTP** (`/auth/phone/send`, `/auth/phone/verify`): 6‑digit code, finds user by phone.
- **Biometric** (`/auth/biometric` toggle, `/auth/biometric/verify`): after local biometric success, issues session tokens (dev accepts any non‑empty bioToken).
- **Passkey** (`/auth/passkey/generate`): returns WebAuthn challenge.
- After auth: call `fintrackProvider.syncFromServer()` to pull categories/accounts/transactions/budgets/goals/subscriptions/notes/notifications.

### 3.3 Main shell (authenticated)
`MainShell` (drawer navigation) wraps these routes (no page transition between drawer items):

| Route | Screen | Purpose |
|-------|--------|---------|
| `/dashboard` | DashboardScreen | Hero balance card, quick stats, spending chart, AI insight banner, financial health, top categories, recent transactions, quick actions |
| `/expenses` | ExpensesScreen | List + filter; child routes `add` (AddExpenseScreen, accepts `ScannedExpenseDraft`), `scan` (ReceiptScannerScreen), `voice` (VoiceExpenseScreen), `:id` (ExpenseDetailScreen) |
| `/income` | IncomeScreen | List; child `add` (AddIncomeScreen) |
| `/budget` | BudgetScreen | Budgets vs spend |
| `/analytics` | AnalyticsScreen | Charts/trends |
| `/savings` | SavingsScreen | Goals; child `add` (AddSavingsGoalScreen) |
| `/subscriptions` | SubscriptionsScreen | Recurring subs |
| `/notes` | NotesScreen | Notes; editor screen |
| `/calculators` | CalculatorHubScreen | Basic + EMI + GST + savings engines |
| `/currency` | CurrencyConverterScreen | Multi‑currency |
| `/ai-chat` | AiChatScreen | Chat with Lumina |
| `/reports` | AIReportsScreen | CSV/PDF export |
| `/settings` | SettingsScreen | Theme/locale/server override |
| `/profile` | ProfileScreen | Edit profile (name, avatarColor, baseCurrency, monthlyIncomeGoal) |
| `/notifications` | NotificationsScreen | In‑app notifications |

Child routes use a slide‑up + fade transition (`_buildPage`); shell routes use `NoTransitionPage`.

### 3.4 Transaction lifecycle (optimistic sync)
- Add → `fintrackProvider.addTransaction` updates state immediately, persists, calls `FinTrackRepository.createTransaction`, then reconciles with server response.
- Update/Delete → same pattern with **rollback** to a backup on server error. `deleteTransaction` restores previous list on failure.
- Notifications: `pushNotification` updates in‑app list and fires OS notification (fire‑and‑forget), then syncs.

### 3.5 AI assistance ("Lumina")
- `/ai/chat`: builds context **server‑side** from Postgres (`transactions_view`, budgets, goals, accounts), prepends an `INTERNAL FINTRACK PRO DATA` block, calls provider, enforces closed‑loop guardrails (strips URLs, `$TICKER`, external‑reference phrases), stores conversation + messages, returns mock reply if disabled/down.
- `/ai/receipt`, `/ai/voice`: accept image/base64 or transcript, return **strict JSON** (merchant/total/date/category… or parsed transaction). Regex fallback parsers when AI off.
- `/ai/insights`, `/ai/weekly-summary`: return structured JSON insight cards / forecast / anomalies; mock payloads when disabled.

### 3.6 Derived analytics
`derivedProvider` computes (from local state): month income/expense, total income/expense, net balance (sum of account balances), savings rate, category breakdown, 7‑day sparkline, budget usage + over‑budget count, MoM deltas, 6‑month trend, goals‑on‑track count.

---

## 4. Data Model (Postgres tables)

`users` (id, email unique, password_hash, full_name, avatar_url, phone, currency, is_email_verified, is_biometric_enabled, is_active, timestamps) ·
`refresh_tokens` (token unique, expires_at, user_id FK) ·
`otp_codes` (email, code, purpose, expires_at) ·
`categories` (user_id nullable, name, icon, color, type, is_default) ·
`expenses` (title, amount, currency, date, category_id, notes, receipt_url, is_recurring, tags[], payment_method, location, shared_with_family) ·
`income` (title, amount, currency, date, category_id, source, is_recurring, shared_with_family) ·
`budgets` (name, category_id, amount, spent, period, start/end_date, alert_at, color) ·
`savings_goals` + `savings_contributions` ·
`subscriptions` (name, amount, billing_cycle, next_billing_date, category_id, is_active, logo_url) ·
`notes` (title, content, color, tags[], is_pinned) ·
`accounts` (name, type, balance, currency, institution, account_number_masked) ·
`notifications` (title, body, type, kind, is_read, action, related_entity) ·
`family_members` (user_id, member_id, role) ·
`ai_conversations` + `ai_messages` (role, content, provider).

Plus view `transactions_view` (UNION of expenses + income as `type` expense/income).

**Flutter models** (lib/data/models/models.dart): `Category`, `Account`, `Transaction` (TxType), `Budget` (BudgetPeriod), `SavingsGoal`, `Subscription`, `Note`, `AppNotification` (NotificationKind), `ChatMessage`, `UserProfile` — all with `fromJson`/`toJson`/`copyWith`.

---

## 5. Backend API Surface (mounted at both `/api/x` and `/x`)

Auth (`/auth`, stricter rate limit): `POST register|login|refresh|logout`, `GET|PATCH|DELETE /me`, `POST otp/send|otp/verify`, `POST verify-email-dev`, `POST forgot-password|reset-password`, `POST phone/send|phone/verify`, `PATCH biometric`, `POST biometric/verify`, `POST passkey/generate`.
Features: `/expenses`, `/income`, `/budgets`, `/savings` (+ alias `/goals`, `POST /:id/contribute`), `/categories`, `/subscriptions`, `/notes`, `/notifications` (`POST /read-all`, `PATCH /:id`), `/accounts`, `/transactions`, `/analytics`, `/family` (`/members`), `/exports` (csv/json/all/summary), `/calculator` (savings-compound, loan-emi, split-bill, fire), `/currency/live`, `/ai` (chat, receipt, voice, insights, weekly-summary, conversations).

**Conventions:** responses `{ ok, ...data }`; auth via `Authorization: Bearer <accessToken>`; refresh on 401 hits `/auth/refresh`; errors `{ ok:false, error }`; not‑found handled by `notFoundHandler`; `errorHandler` last.

---

## 6. State & Persistence Rules

- Single source of truth on frontend: `fintrackProvider` (`StateNotifier<FinTrackState>`), persisted to `SharedPreferences` key `fintrack_pro_flutter_v1`.
- Auth tokens in `flutter_secure_storage` (`TokenStorage`); access token auto‑attached by `AuthInterceptor`; 401 → refresh via separate Dio instance → retry; on failure clear session.
- Optimistic UI everywhere; `lastSyncError` surfaces server‑save failures as a toast; deletes roll back.
- `syncFromServer()` after login; `seedAndSync()` to load demo data.

---

## 7. Build Instructions (from scratch)

1. **Backend:** `cd backend && npm install`; copy `.env.example`→`.env` (DB_* , JWT_* , AI_* ); `npm run db:migrate` (creates tables), optional `npm run db:seed`; `npm run dev` (port 3000).
2. **Frontend:** `flutter pub get`; set `AppConfig.apiBaseUrl` to backend; `flutter run`.
3. **Verification:** `flutter test`; backend `npm test` (jest).

---

## 8. Known Gaps to Address When Building

- Implement the **auth guard** in `app_router.dart` (currently a TODO stub returning null).
- Resolve **duplicate/overlapping modules**: `features/calculator` vs `features/calculators`; root `data/repositories/ai_repository.dart` vs `features/ai_chat/data/repositories/chat_repository.dart`.
- `AuthInterceptor` currently permits `/auth/me` without a token — tighten if needed.
- Several `tmp_*.js` / `test_*.js` backend scripts are scratch files; exclude from production.

---

**Use this spec as the single source of truth to regenerate, audit, or extend FinTrack Pro.**
