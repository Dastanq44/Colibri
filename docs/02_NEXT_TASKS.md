# 02_NEXT_TASKS.md — handoff backlog

State as of 2026-07-10. All MVP feature phases (0–12, 14, 15) are implemented
and tested (279 unit tests + live-backend sync smoke test). Since the original
handoff, a large post-MVP pass landed on two long-lived branches:

- **`main`** — Material/Android-styled variant.
- **`liquid-glass`** — the iOS-native variant (system-blue Cupertino design,
  real native Liquid Glass tab bar + top buttons via `cupertino_native`,
  modern sheets/loaders). Feature-identical to `main`; only visuals differ.
  See docs/LIQUID_GLASS.md. **All feature work must land on both branches**
  (shared/data files are identical; presentation files get per-branch skins).

Post-MVP features added on both branches: EPUB cover extraction + covers
everywhere, favourites, profile editor (avatar/bio) with multi-select
favourites, reading presets (Profile A–F), natural pauses in fast mode,
resume-word highlight + long-press handoff, fast-mode scrubbing +
letter-centred words, author search in catalog, portrait lock outside the
reader, container-safe path resolution (books/covers/avatar survive iOS app
updates), and a first-run settings seed race fix.

## Blocked on the user (minutes each)

1. **Maestro CLI install** — `curl -Ls https://get.maestro.mobile.dev | bash`,
   then `maestro test maestro/flows` on a booted simulator with an imported
   book; fix selector drift. (Text selectors assume an English locale.)
2. **Android SDK** (only for `main`/Android) — install via Android Studio,
   set `ANDROID_HOME`, run `flutter build appbundle`, create upload keystore.
3. **Verify delete-account deploy** — `supabase functions deploy
   delete-account` if not yet deployed; then create a throwaway user, delete
   in-app, confirm auth user + rows + files are gone.
4. **Apple/Google developer accounts** for TestFlight / Play internal
   testing; signing per docs/release/STORE_ASSETS.md. (Personal-device
   sideloading works today with a free account; 7-day resign cycle.)

Done since the original list: Amplitude key + adapter live, SENTRY_DSN set,
app icon designed and wired (flutter_launcher_icons).

## Book-database wiring (the user's stated next goal)

The catalog UI end (search incl. author names, covers via `books.cover_url`,
book detail, add-to-shelf, home rails) is ready and reads from Supabase
(`books`, `authors`, `book_authors`, `book_categories`). To make a real book
database useful, the missing piece is **catalog file delivery**: cloud-shelf
entries have `fileLocalPath = ''` and open Book Detail, not the reader
(deliberately post-MVP). Wiring plan:

1. Populate `books` (+ authors/categories, `cover_url`) and upload book files
   to Supabase Storage (bucket per format or a `books` bucket keyed by id).
2. Add a download path: Book Detail "Download" → fetch from Storage →
   `FileStorageService.copyIntoBookStorage` → set `fileLocalPath` (+ cover
   extraction) → entry becomes readable/offline like an import.
3. Progress/resume already works once the file is local; sync upload skips
   catalog-sourced books (sourceType 'catalog').
4. Optional: size/format gates, download progress UI, delete-download action.

## Next development tasks (in suggested order)

1. **Manual QA pass** — walk docs/QA_CHECKLIST.md on a real iPhone (user is
   sideloading now) and, later, one Android device; file/fix what falls out.
2. **Run + stabilize Maestro flows** once the CLI exists.
3. **Goals & streaks** (Home goal card is a placeholder): daily minutes from
   local_reading_sessions vs profiles.goal_daily_minutes; streak =
   consecutive days with sessions. Data is already recorded.
4. **PDF fast mode via text layer**: pdfrx exposes text extraction; tokenize
   per page, map token → page, keep the no-text-layer fallback message.
5. **Reviews (Phase 13, optional)** — plan tasks 1301–1305; cloud tables and
   RLS already exist.
6. **Reading-session cloud sync** (`reading_sessions` table exists; local
   sessions are recorded but not uploaded).
7. **Per-book WPM** (plan 8.3 "optionally per book") — global persistence
   works (last-used speed is remembered); per-book override is small.
8. **Sync hardening leftovers** (commit 4128754): FK-failed annotation
   uploads classified permanent rather than waiting for the parent book;
   create-signed-out → delete-signed-in splits queue rows across accounts.
   Both unreachable on normal paths.
9. **Offline niceties** (from the 2026-07-09 audit, all LOW): friendly
   offline auth error message; catalog add-to-shelf should enqueue offline
   instead of failing; cloud-shelf refresh retries within a session;
   sign-out result surfaced.

## Environment notes for the next agent

- `.env.dev` (gitignored) holds live dev Supabase keys + SENTRY_DSN +
  AMPLITUDE_API_KEY; email confirmation is disabled on the dev project, and
  a smoke-test user (colibri.sync.smoke@example.com) plus one fixed-id smoke
  book row exist.
- Live tests are tagged `live` (dart_test.yaml) and self-skip without
  `.env.dev`. Run: `flutter test test/e2e/live_sync_smoke_test.dart`.
- Integration test: `flutter test integration_test -d <simulator-udid>`.
- Catalog seed is applied on dev (5 books / 5 authors / 4 categories);
  `supabase/seed.sql` is idempotent.
- Known upsert gotcha: `books` must use plain insert + duplicate-key-as-
  success (see SupabaseSyncRepository) — ON CONFLICT arbiters need SELECT
  visibility that upload rows don't have pre-file-upload. Don't "simplify"
  it back to upsert.
- The app is portrait-locked except inside the reader (product decision
  2026-07-09; supersedes the older CLAUDE.md "avoid global orientation
  lock" note).
- iOS deployment target is 14.0 on `liquid-glass` (cupertino_native);
  `main` stays at 13.0.
