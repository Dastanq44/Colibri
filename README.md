# Colibri

A hybrid mobile e-reader for iOS and Android.

- **Portrait** = normal ebook reading.
- **Landscape** = focused fast-reading mode (centered word/phrase).

> Read normally when you want depth. Rotate your phone when you want speed.

Colibri is a serious reader first; fast mode is an additional, reversible reading mode. The core loop is: import/open a book → read in portrait → rotate to landscape for fast mode → adjust WPM → rotate back without losing position → resume later.

See [`CLAUDE.md`](CLAUDE.md), [`docs/00_PROJECT_CONTEXT.md`](docs/00_PROJECT_CONTEXT.md), and [`docs/01_DEVELOPMENT_TASK_PLAN.md`](docs/01_DEVELOPMENT_TASK_PLAN.md) for the authoritative product/spec and the phased task plan. Background research lives in [`docs/research/`](docs/research/).

## Tech stack

Flutter · Dart · Riverpod · Drift/SQLite · Supabase (Auth/Postgres/Storage/Edge Functions) · Sentry · go_router · `flutter gen-l10n` · Maestro (E2E).

## Project status

Foundational phases are landing in order:

- ✅ **Phase 0 — Project foundation**: routing, placeholder screens, theme, localization, env config, repository interfaces.
- ✅ **Phase 2 — Local database**: Drift/SQLite tables, DAOs, defaults, sync status, sync queue, device id service.
- ✅ **Phase 1 — Supabase backend foundation**: SQL migrations, RLS, storage buckets, seed data, and a dev-safe Supabase client provider. Backend SQL lives in [`supabase/`](supabase/) — see [`supabase/README.md`](supabase/README.md) to apply it.
- ✅ **Phase 3 — Auth & profile**: Supabase-backed `AuthRepository`/`ProfileRepository`, Riverpod auth/profile providers, and real Auth + Profile screens (dev-safe when no backend is configured).
- ✅ **Local import + My Books (local)**: pick an EPUB/TXT/PDF → validate → checksum (dedupe) → copy into app storage → create local book/shelf/progress rows → appears in My Books. No cloud upload yet.
- ✅ **Normal reader MVP (TXT)**: tap a TXT book → portrait reader → tap left/right to page → progress saved locally → reopening resumes. EPUB/PDF show a friendly "coming soon".
- 🚧 **Fast mode (TXT)**: rotate the reader to landscape for RSVP-style fast reading — centered word, tap left/center/right to slow/pause/speed up, WPM 150–700 (step 25), with position carried across normal ↔ fast. Orientation only switches mode *inside the reader* (no global lock).

There is still no EPUB/PDF rendering or sync engine — those land in later phases (see the task plan).

## First-time setup

The native `android/` and `ios/` folders are **not** checked in yet. After cloning, generate them and fetch packages:

```bash
# 1. Generate the native platform projects without touching lib/.
flutter create --platforms=android,ios --org com.colibri .

# 2. Fetch dependencies, generate localizations, then Drift code.
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs

# 3. Create your local env file from the template and fill in values.
cp .env.example .env.dev

# 4. (Optional) Stand up the backend — see supabase/README.md.
```

> Until `flutter gen-l10n` runs, the analyzer will report a missing
> `app_localizations.dart` import — that file is generated from the ARB files.

## Running

Environment values are injected at run/build time via `--dart-define-from-file`
(nothing secret is hardcoded). Validation is environment-aware: in **dev** the
Phase 0 placeholder app boots even without Supabase keys (a warning is logged),
while **staging** and **production** fail fast in `main()` if `SUPABASE_URL` or
`SUPABASE_ANON_KEY` is missing.

```bash
# Dev runs even without a configured .env.dev (placeholders only).
flutter run --dart-define-from-file=.env.dev
flutter run --dart-define-from-file=.env.staging
flutter run --dart-define-from-file=.env.production
```

Build examples:

```bash
flutter build apk    --dart-define-from-file=.env.production
flutter build ipa    --dart-define-from-file=.env.production
```

## Testing

```bash
flutter test
```

## Project structure

```
lib/
  main.dart                 # bootstrap: load+validate config, run app
  app/
    app.dart                # MaterialApp.router (theme + l10n + routing)
    router/                 # go_router routes, shell (bottom tabs), unknown route
    theme/                  # light/dark app themes, sepia reader palette, tokens
    localization/           # ARB files + locale provider (+ generated output)
  core/
    config/                 # AppEnvironment + AppConfig (env variables)
    result/  errors/        # Result<T> + typed Failures
    constants/              # product constants (WPM rules, timings)
  data/
    local/                  # Drift database, tables, DAOs, device id (Phase 2)
    remote/                 # Supabase client provider + bootstrap (Phase 1)
    repositories/           # 14 repository interfaces (boundaries) + barrel
  features/                 # onboarding, auth, home, catalog, library,
                            # book_detail, import, profile, settings, reader
  shared/                   # shared widgets/models/services
test/                       # unit tests
integration_test/  maestro/ # E2E (Phase 16)
supabase/                   # migrations, seed.sql, policies (Phase 1)
```

### Architecture rules (enforced going forward)

- UI/state never calls Supabase or Drift directly — always through a repository.
- Reader engine and fast-mode engine stay UI-independent and testable.
- All user-facing strings are localized (`ru-RU` primary, `en-US` fallback).

## Environment variables

| Key                 | Required | Used in  | Notes                          |
| ------------------- | -------- | -------- | ------------------------------ |
| `APP_ENV`           | no       | core     | `dev` / `staging` / `production` |
| `SUPABASE_URL`      | staging/prod | Phase 1 | dev tolerates absence; fails fast in staging/prod |
| `SUPABASE_ANON_KEY` | staging/prod | Phase 1 | dev tolerates absence; fails fast in staging/prod |
| `SENTRY_DSN`        | no       | Phase 15 | crash reporting                |
| `ANALYTICS_ENABLED` | no       | Phase 15 | keep `false` in dev            |

## Next task

**Reader hardening + EPUB text extraction MVP**: better TXT pagination, basic
EPUB text extraction, a table-of-contents placeholder, reader settings
integration, improved progress mapping, and more Android real-device testing.
