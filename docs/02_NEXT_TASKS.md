# 02_NEXT_TASKS.md — handoff backlog

State as of 2026-07-08 (branch `feat/phase-0-foundation`): all MVP feature
phases (0–12, 14, 15) are implemented and tested — 237 unit tests, a
device-run integration test of the core loop, and a live-backend sync smoke
test. What remains is distribution work, a few user-gated unblocks, and
deliberately deferred features. Read `CLAUDE.md` and
`docs/01_DEVELOPMENT_TASK_PLAN.md` first; `docs/QA_CHECKLIST.md` tracks
manual QA.

## Blocked on the user (minutes each)

1. **Maestro CLI install** — `curl -Ls https://get.maestro.mobile.dev | bash`
   (agent may not pipe remote installers). Then run
   `maestro test maestro/flows` on a booted simulator with an imported book
   (see maestro/README.md) and fix any selector drift.
2. **Android SDK** — not present on this machine, so
   `flutter build appbundle` fails. Install via Android Studio, set
   `ANDROID_HOME`, re-run the build, then create an upload keystore.
3. **Amplitude API key** (analytics vendor decision: Amplitude) — then add
   the adapter behind `analyticsRepositoryProvider`
   (lib/data/repositories/analytics_repository.dart) and pass the key via
   env (`--dart-define-from-file`). Events are already wired everywhere.
4. **SENTRY_DSN** in `.env.dev` / `.env.production` — init code is live in
   main.dart; a DSN turns it on.
5. **Deploy the delete-account function** —
   `supabase functions deploy delete-account` (code is in
   supabase/functions/delete-account/; the app already calls it and
   degrades gracefully until deployed). Then verify: create a throwaway
   user, delete in-app, confirm auth user + rows + files are gone.
6. **App icon** — still the Flutter default. Provide a 1024×1024 master,
   then wire `flutter_launcher_icons` (see docs/release/STORE_ASSETS.md).
7. **Apple/Google developer accounts** for TestFlight / Play internal
   testing; signing setup per docs/release/STORE_ASSETS.md.

## Next development tasks (in suggested order)

1. **Run + stabilize Maestro flows** once the CLI exists (QA Phase 16
   remainder). Known risk: text selectors assume an English device locale.
2. **Manual QA pass** — walk docs/QA_CHECKLIST.md on at least one Android
   device and one iPhone; file/fix what falls out.
3. **Goals & streaks** (Home goal card is a placeholder): daily minutes
   from local_reading_sessions vs profiles.goal_daily_minutes; streak =
   consecutive days with sessions. Data is already recorded.
4. **PDF fast mode via text layer** (plan allows when a text layer exists):
   pdfrx exposes text extraction; tokenize per page, map token → page for
   position continuity, keep the no-text-layer fallback message.
5. **Reviews (Phase 13, optional)** — plan tasks 1301–1305; cloud tables
   and RLS already exist.
6. **Sync hardening leftovers** (documented in commit 4128754): FK-failed
   annotation uploads are classified permanent rather than waiting for the
   parent book; a create-signed-out → delete-signed-in sequence splits
   queue rows across accounts. Both unreachable on normal paths.
7. **Reading-session cloud sync** (`reading_sessions` table exists; local
   sessions are recorded but not uploaded).
8. **Per-book WPM** (plan 8.3 "optionally per book") — global persistence
   works; per-book override is a small settings addition.

## Environment notes for the next agent

- `.env.dev` (gitignored) holds live dev Supabase keys; email confirmation
  is disabled on the dev project, and a smoke-test user
  (colibri.sync.smoke@example.com) plus one fixed-id smoke book row exist.
- Live tests are tagged `live` (dart_test.yaml) and self-skip without
  `.env.dev`. Run: `flutter test test/e2e/live_sync_smoke_test.dart`.
- Integration test: `flutter test integration_test -d <simulator-udid>`.
- Catalog seed is applied on dev (5 books / 5 authors / 4 categories);
  `supabase/seed.sql` is idempotent.
- Known upsert gotcha: `books` must use plain insert + duplicate-key-as-
  success (see SupabaseSyncRepository) — ON CONFLICT arbiters need SELECT
  visibility that upload rows don't have pre-file-upload. Don't "simplify"
  it back to upsert.
