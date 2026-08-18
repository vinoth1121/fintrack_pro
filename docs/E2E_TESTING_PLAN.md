# FinTrack Pro — End-to-End Integration Testing Plan

Scope: verify the data path **Flutter → Node.js backend → AI provider (Gemini) → UI**
is correct, resilient, and never leaves the user on a blank / "white" screen.

> Pre-req: backend running (`npm run dev`), PostgreSQL migrated & seeded, Flutter
> app built against the same backend (`lib/core/config/server_config.dart`).
> Set `AI_ENABLED=true` in `backend/.env` for the "live AI" cases and `false`
> for the "mock fallback" cases.

## 1. Test environments / feature flags
| Env | `AI_ENABLED` | Provider | Purpose |
|-----|--------------|----------|---------|
| Mock | `false` | n/a | Verify graceful fallback JSON + no white screen |
| Live | `true` | `google` (`AI_BASE_URL=…/v1beta/openai`) | Verify real Gemini call + structured JSON |

## 2. Critical user journeys (CUJs)
### 2.1 AI Chat (`POST /api/ai/chat`)
1. Open AI Chat, send "Analyze my spending this month".
2. Assert a typing indicator shows immediately (`_loading == true` → `_TypingIndicator`),
   then a markdown reply renders. **No white screen.**
3. Assert the reply references numbers that exist in PostgreSQL for that user
   (server-side `buildUserContext` only — see `ai.routes.js:110`), not arbitrary values.
4. Kill the AI provider (bad `AI_API_KEY`) → assert mock reply + `provider:"mock"`,
   no crash, no blank screen.

### 2.2 Receipt (Base64 image → backend)
Two distinct code paths exist — test **both**:
- **Receipts screen** (`lib/features/receipts/receipts_screen.dart`) → `AiRepository.scanReceipt(base64)`
  → `POST /api/ai/receipt`.
  - Capture/select image → `ScanningPhase` spinner → review screen with parsed
    merchant/total/items. Assert `ScanStatus`/`_ReceiptPhase` transitions.
  - Send a **corrupt/blank** image → assert `result != null` with safe defaults
    (`merchant:"Scanned Receipt"`, `total:0`) and no null crashes in `ReceiptData.fromJson`.
- **Expense Receipt Scanner** (`receipt_scanner_screen.dart`) parses **on-device**
  (no network). Verify it still works offline and shows the review screen.

### 2.3 Voice (transcript → backend)
- **Top-level Voice screen** (`lib/features/voice/voice_screen.dart`) →
  `AiRepository.transcribeAndParse('')` → `POST /api/ai/voice`.
  Assert `VoiceResult.transaction` is a valid `{type,amount,category,date}` and
  the screen renders a review state, not a blank page.
- **Expense Voice screen** (`voice_expense_screen.dart`) parses **on-device**.
  Verify listening → processing → review transitions and error copy when no amount.

### 2.4 Insights & Weekly Summary
- Insights screen (`AiRepository.insights`) and Notifications (`weeklySummary`)
  must render cards even when the provider is dead (mock payload), and never throw
  on malformed JSON (the route wraps `JSON.parse` in try/catch with a safe default).

## 3. Error & edge-case matrix
| Scenario | Expected behavior |
|----------|-------------------|
| 401 (bad/missing JWT) | Backend 401 → Dio interceptor refresh/retry; UI shows auth error, not white |
| AI provider 4xx/5xx | `markProviderDead()` → 60s cooldown → mock JSON; UI renders graceful copy |
| 8s timeout (AbortController) | Same fallback path; UI not blocked > ~8s |
| Malformed/non-JSON model output | Strip ``` fences, `JSON.parse` guarded → safe defaults (`ai.routes.js`) |
| `AI_ENABLED=false` | Immediate deterministic mock JSON, no network |
| Empty transcript / no image | 400 with `{ok:false,error}` → UI toast, stays on prior screen |

## 4. White-screen prevention checklist (per screen)
- [ ] Every async AI call sets a loading flag **before** `await` and clears it
      **after** (`finally`/mounted guard).
- [ ] A loading widget (spinner/typing indicator/scanning phase) is shown while loading.
- [ ] `if (!mounted) return;` after every `await` before `setState`/`context` use.
- [ ] Failures resolve to **safe defaults or user-friendly copy**, never `null`
      passed to a `fromJson` that throws.
- [ ] Dio errors are caught and converted to friendly strings (`ai_repository.dart:_logAiFailure`).

## 5. Automated checks
- **Backend (node:test / supertest):** table-driven tests for `/chat`, `/receipt`,
  `/voice`, `/insights`, `/weekly-summary` with `AI_ENABLED=false` (mock) and with a
  mocked `fetch` returning malformed JSON (assert safe-default normalization).
- **Flutter (widget/integration tests):** drive each screen, inject a fake
  `AiRepository` that returns `null`/throws, assert a loading state is shown and a
  non-empty result renders (no `find.text('')`-only blank). Use
  `test/widget_test.dart` + `integration_test/` for real device runs.

## 6. Manual sign-off gate
All CUJs in §2 pass in **both** Mock and Live envs, and the edge matrix in §3
produces no crash and no white screen, before merge to `main`.
