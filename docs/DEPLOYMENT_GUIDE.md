# FinTrack Pro — Deployment & Synchronization Guide

From virtual/workspace → local dev → GitHub, with dependency & env setup.

## 0. Prerequisites
- Node.js 18+ and npm
- Flutter 3.22+ (`flutter doctor` clean)
- PostgreSQL 14+ (local or managed, e.g. Neon/Supabase)
- Git
- A Google Gemini API key (AI Studio) for live AI

---

## 1. Workspace → Local machine
1. Stop any running dev servers in the workspace.
2. Copy the project tree (excluding generated/secret files):
   ```bash
   # from the workspace root
   rsync -a --exclude node_modules --exclude build --exclude .dart_tool \
         --exclude '*.env' --exclude 'backend/.env' FinTrack_Pro/ ~/dev/fintrack_pro
   ```
3. **Never copy `.env` / `backend/.env`** (they hold secrets). Recreate them locally.

## 2. Backend setup (Node + PostgreSQL)
```bash
cd fintrack_pro/backend
npm install                 # install dependencies from package.json
cp .env.example .env        # create real env (edit values, do NOT commit)
```
Edit `backend/.env`:
- `DB_HOST/DB_PORT/DB_NAME/DB_USER/DB_PASS` → your PostgreSQL
- `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` → `openssl rand -hex 32` each
- AI block:
  ```
  AI_ENABLED=true
  AI_PROVIDER=google
  AI_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai   # note /openai suffix
  AI_MODEL=gemini-2.5-flash
  AI_API_KEY=REAL_GEMINI_KEY
  ```
  Keep `AI_ENABLED=false` for local/offline dev (mock replies).
Run migrations + (optional) seed:
```bash
npm run migrate            # backend/src/db/migrate.js (drops & recreates schema)
node src/db/seed.js        # optional sample data
npm run dev                # starts server; check http://localhost:3000/api/health
```

## 3. Frontend setup (Flutter)
```bash
cd fintrack_pro
flutter pub get            # install Dart packages
```
Point the app at the backend in `lib/core/config/server_config.dart`
(local `http://10.0.2.2:3000` for Android emulator, `localhost` for iOS/desktop).
Run:
```bash
flutter analyze            # must pass (no errors)
flutter test               # unit/widget tests
flutter run                # or: flutter build apk / flutter build ios
```

## 4. Environment-variable hardening (security)
- [ ] `.env` and `backend/.env` are in `.gitignore` (already covered) — confirm with
      `git check-ignore backend/.env` before first commit.
- [ ] `AI_API_KEY` / JWT secrets are **never** hard-coded and never logged. The
      backend reads them only via `process.env` (`ai.routes.js`, `db/pool.js`).
- [ ] `dotenv` loads `.env` (server.js) — no secret reaches the client bundle.
- [ ] Rotate any key that was ever committed (GitHub "dead" history) immediately.
- [ ] For CI/deploy, inject env via the platform's secret store, not the repo.

## 5. GitHub synchronization
```bash
cd fintrack_pro
git init                   # if not already a repo
git remote add origin git@github.com:<you>/fintrack_pro.git
git pull origin main --allow-unrelated-histories   # if repo pre-exists
```
Pre-commit guardrails:
```bash
git add -A
git status                 # manually confirm NO .env / backend/.env / secrets staged
# If accidentally staged:
git restore --staged backend/.env
```
Commit & push:
```bash
git commit -m "feat: FinTrack Pro MVP (Node+PG backend, Flutter client)"
git push -u origin main
```
Branch workflow for changes:
```bash
git checkout -b feat/ai-internal-data
# ... edit, test, commit ...
git push -u origin feat/ai-internal-data
# open PR → CI (flutter analyze + node test) → merge to main
```

## 6. CI checklist (recommended)
- Backend: `npm ci && npm test` (with `AI_ENABLED=false`).
- Frontend: `flutter pub get && flutter analyze && flutter test`.
- Secrets scan (e.g. gitleaks) must pass before merge.

## 7. Go-live sanity
- [ ] `/api/health` returns `{ok:true}`.
- [ ] `POST /api/ai/chat` with a valid JWT returns a reply (mock or Gemini).
- [ ] `.env` present on the server; not in the repo.
- [ ] DB migrated; app can read/write transactions for a test user.
