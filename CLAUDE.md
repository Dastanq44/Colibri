# Claude Project Instructions

This project is a Flutter mobile app for iOS and Android.

## Product

The app is a hybrid mobile e-reader.

It has two reading modes:

1. Portrait orientation = normal ebook reading.
2. Landscape orientation = fast-reading mode.

The app must be a serious reader first, not a speed-reading gimmick.

Core loop:

import/open book → read normally → rotate to landscape for fast mode → adjust WPM → return to portrait without losing position → resume later.

## Source of truth

Use these files in this order of authority:

1. `/docs/00_PROJECT_CONTEXT.md`
2. `/docs/01_DEVELOPMENT_TASK_PLAN.md`
3. `/docs/research/*`

The research documents are background only. If they conflict with the final task plan or this file, follow this file and the final task plan.

## Final technical decisions

Use:

- Flutter + Dart
- Riverpod
- Drift/SQLite
- Supabase Auth
- Supabase Postgres
- Supabase Storage
- Supabase Edge Functions
- Sentry
- Firebase Analytics or Amplitude
- Maestro for E2E testing

Do not switch the project to React Native, Expo, Firebase Firestore, or a custom backend unless explicitly instructed.

## MVP formats

Support:

- EPUB
- TXT
- PDF

PDF fast mode is allowed only if the PDF has a usable text layer.

Scanned PDF OCR is not part of MVP.

## MVP exclusions

Do not implement these in MVP:

- DRM
- paid book store
- subscriptions
- OCR
- ML recommendations
- full social feed
- OPDS
- web app
- desktop app
- advanced moderation dashboard

## Architecture rules

Use feature-based architecture.

Keep these layers separate:

- UI
- state management
- domain models
- repositories
- local database
- remote Supabase access
- platform-specific services
- reader engine
- fast-mode engine

The UI must not call Supabase or Drift directly. Use repositories.

## Reader rules

The reader is the core feature.

The reader must:

- preserve position across portrait and landscape modes
- work offline
- save progress reliably
- avoid global orientation lock
- use mode lock inside the Reader only
- support tap left/right in portrait
- support tap center/left/right in fast mode
- keep fast mode optional and reversible

## Fast mode rules

Fast mode:

- starts in landscape orientation
- shows centered current word or phrase
- may show dimmed previous and next context
- center tap = pause/play
- right tap = increase WPM
- left tap = decrease WPM
- WPM step = 25
- WPM range = 150–700
- default WPM = 275
- speed feedback should show for 500–800 ms

## Development behavior

When implementing tasks:

1. Inspect existing files first.
2. Implement only the requested task.
3. Do not perform unrelated refactors.
4. Keep files small and readable.
5. Add tests when useful.
6. Explain what changed.
7. Mention assumptions or skipped items.
8. Do not invent product features outside the task plan.