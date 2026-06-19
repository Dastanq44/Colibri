# 00_PROJECT_CONTEXT.md

# Hybrid Mobile E-Reader Project Context

## 1. Purpose of This File

This file is the short project context for Claude.

Claude should read this file before implementing any task.

This file defines:

- what the product is
- what the final technical stack is
- what is included in MVP
- what is excluded from MVP
- what architectural rules must be followed
- what UX decisions are already final

This file is intentionally shorter than `01_DEVELOPMENT_TASK_PLAN.md`.

---

# 2. Product Summary

## 2.1 Product concept

This project is a hybrid mobile e-reader for iOS and Android.

The app has two reading modes:

1. **Portrait orientation** = normal ebook reading.
2. **Landscape orientation** = fast-reading mode.

The product must feel like a serious mobile reader first, not like a speed-reading gimmick.

The fast-reading mode is an additional reading mode, not the whole product.

## 2.2 Core value proposition

The app lets users switch between deep reading and faster focused reading without losing their position.

Simple product statement:

> Read normally when you want depth. Rotate your phone when you want speed.

## 2.3 Core user loop

The main user loop is:

```text
import/open book
→ read normally in portrait
→ rotate to landscape
→ fast mode starts from the same position
→ adjust WPM
→ rotate back to portrait
→ normal reader continues from the same position
→ resume later
```

## 2.4 Product positioning

The app should not be positioned as:

- a pure RSVP app
- a speed-reading trainer
- a gimmick that promises magical comprehension improvement

The app should be positioned as:

- a full mobile reader
- a personal reading library
- a reading progress tracker
- a hybrid normal/fast reading tool
- a calm reading environment
- an offline-first reading app

---

# 3. Source of Truth

Claude should use files in this priority order:

1. `CLAUDE.md`
2. `docs/00_PROJECT_CONTEXT.md`
3. `docs/01_DEVELOPMENT_TASK_PLAN.md`
4. `docs/research/*`

The research documents are background only.

If the research documents conflict with this file or the development task plan, follow this file and the development task plan.

---

# 4. Final Technical Stack

Use this final stack:

- **Mobile framework:** Flutter
- **Language:** Dart
- **State management:** Riverpod
- **Local database:** SQLite with Drift
- **Backend:** Supabase
- **Cloud database:** Supabase Postgres
- **Authentication:** Supabase Auth
- **File storage:** Supabase Storage
- **Backend functions:** Supabase Edge Functions
- **Crash reporting:** Sentry
- **Analytics:** Firebase Analytics or Amplitude
- **E2E testing:** Maestro
- **Beta distribution:** TestFlight and Google Play internal testing

Do not switch the app to:

- React Native
- Expo
- Firebase Firestore as the primary backend
- a custom backend
- a web-first app
- native-only iOS/Android apps

Firebase/Firestore may appear in background research, but it is not the chosen primary backend for this MVP.

---

# 5. MVP Scope

## 5.1 MVP includes

The MVP includes:

1. Onboarding
2. Authentication
3. Home screen
4. Catalog screen
5. My Books screen
6. Book detail screen
7. Book import
8. Portrait normal reader
9. Landscape fast reader
10. Reading progress tracking
11. Offline local library
12. Basic cloud sync
13. Reader settings
14. Mode lock
15. Speed lock setting
16. Basic notes/bookmarks
17. Basic profile
18. Basic goals/stats
19. Basic rule-based recommendations
20. Analytics
21. Crash reporting
22. Basic accessibility
23. Localization: ru-RU first, en-US fallback

## 5.2 MVP supported formats

The MVP supports:

- EPUB
- TXT
- PDF

Format rules:

- EPUB is the main format.
- TXT is a simple reliable format.
- PDF is supported in normal reading mode.
- PDF fast mode is enabled only if the PDF has a usable text layer.
- Scanned PDF OCR is not part of MVP.

## 5.3 MVP excludes

Do not build these in MVP:

- DRM
- paid book store
- subscriptions
- in-app purchases
- OCR for scanned PDFs
- ML recommendations
- full social feed
- OPDS support
- web app
- desktop app
- publisher tools
- advanced moderation dashboard
- complex admin CMS
- collaborative notes
- TTS/audio reading
- licensed commercial book marketplace

---

# 6. Key UX Decisions

## 6.1 Normal portrait reader

Portrait mode is the normal reading mode.

Portrait reader behavior:

- tap right side = next page
- tap left side = previous page
- bottom progress bar
- bottom-left mode lock icon
- bottom-center progress indicator
- bottom-right reader menu icon

The portrait reader should feel calm and book-like.

Avoid unnecessary controls.

Do not make center tap the main way to show controls in MVP.

## 6.2 Landscape fast reader

Landscape mode is the fast-reading mode.

Fast reader behavior:

- center shows current word or phrase
- previous and next context may be dimmed
- tap center = pause/play
- tap right = increase WPM
- tap left = decrease WPM
- long press right = gradually increase WPM
- long press left = gradually decrease WPM
- tap WPM indicator = open precise speed control
- bottom area shows WPM, progress, and lock state

Fast mode should be focused and minimal.

The user’s eyes should stay near the center.

## 6.3 WPM rules

Default WPM:

```text
275
```

Presets:

```text
200
275
350
425
```

Allowed range:

```text
150–700 WPM
```

Step:

```text
25 WPM
```

Speed feedback:

```text
+25 WPM
-25 WPM
Speed locked
Paused
```

Feedback duration:

```text
500–800 ms
```

## 6.4 Orientation behavior

Do not globally lock app orientation.

Only the Reader screen reacts to orientation changes.

Inside Reader:

- portrait = normal reader
- landscape = fast mode
- mode lock prevents automatic switching
- returning from landscape to portrait must preserve reading position

Add a stability threshold before switching mode:

```text
400–700 ms
```

This prevents rapid switching caused by unstable rotation or sensor noise.

## 6.5 Mode lock

Mode lock controls whether the Reader responds to orientation changes.

When mode lock is enabled:

- portrait remains normal reader even if device rotates
- landscape does not automatically enter fast mode
- current reader mode is preserved unless user changes it manually

Mode lock affects Reader only.

It must not affect the whole app.

## 6.6 Speed lock

Speed lock prevents accidental WPM changes.

When speed lock is enabled:

- tap left/right does not change WPM
- center tap still pauses/plays
- WPM control requires unlock
- app shows `Speed locked` feedback

Speed lock should exist in settings.

It does not need to be a prominent main-screen MVP control.

---

# 7. Architecture Rules

## 7.1 General structure

Use feature-based architecture.

Recommended high-level structure:

```text
lib/
  app/
  core/
  data/
  features/
  shared/
test/
integration_test/
maestro/
supabase/
docs/
```

## 7.2 Layer separation

Keep these layers separate:

- UI
- state management
- domain models
- repositories
- local database
- Supabase access
- file system services
- reader engine
- fast-mode engine
- sync engine
- analytics
- platform-specific services

## 7.3 Repository rule

UI must not call Supabase directly.

UI must not call Drift DAOs directly.

Use repositories as the boundary between UI/state and data sources.

Required repository interfaces:

```text
AuthRepository
ProfileRepository
BookRepository
CatalogRepository
LibraryRepository
ImportRepository
ReaderRepository
ProgressRepository
NotesRepository
ReviewRepository
RecommendationRepository
SyncRepository
SettingsRepository
AnalyticsRepository
```

## 7.4 Reader architecture

The reader should be modular.

Separate:

- normal reader UI
- fast reader UI
- reader domain models
- reader locator/progress logic
- file parsing
- text extraction
- tokenization
- WPM timing
- orientation switching
- settings
- sync

Fast-mode logic should be testable without UI.

Reader progress logic should be testable without UI.

---

# 8. Reader Rules

The reader is the core feature.

The reader must:

1. Work offline.
2. Save progress locally.
3. Sync progress when online.
4. Preserve position between normal and fast mode.
5. Avoid losing progress on app pause/resume.
6. Avoid rapid switching during unstable rotation.
7. Disable fast mode for unsupported files.
8. Avoid global orientation lock.
9. Respect mode lock.
10. Respect speed lock.
11. Support EPUB and TXT in normal reader.
12. Support PDF in normal mode.
13. Support fast mode only when linear text is available.

Progress should save:

- on page change
- every 10–15 seconds while reading
- on app pause
- on reader exit
- before mode switch

---

# 9. Book Import Rules

Use system file picker.

Supported extensions:

```text
.epub
.txt
.pdf
```

Import pipeline:

```text
select file
→ validate file
→ copy to app-controlled local storage
→ compute checksum
→ extract metadata
→ extract cover if possible
→ create local book record
→ upload to Supabase if logged in and sync is enabled
→ show success state
```

Import must work offline locally.

Cloud upload failure must not prevent local reading.

Unsupported or corrupted files must not crash the app.

Duplicate files should be detected by checksum.

---

# 10. Local-First and Sync Rules

The app is local-first.

Local reading must work without network.

Supabase sync should enhance the experience, not block the core reader.

Sync must cover:

- book metadata
- bookshelf status
- reading progress
- notes
- bookmarks
- reading sessions
- uploaded files when possible

Use sync queue for offline changes.

Every progress record should include:

```text
device_id
revision
updated_at
```

Do not silently overwrite major progress conflicts.

If needed, show a choice like:

```text
We found two reading positions:
This device: Chapter 8, 42%
Cloud: Chapter 9, 47%
Continue from later position?
```

---

# 11. Data and Privacy Rules

Do not send private book text to analytics.

Do not log private book text in Sentry.

Do not store sensitive tokens in plain local storage.

Use Supabase RLS for all user-owned data.

Private user data includes:

- uploaded book files
- reading progress
- notes
- bookmarks
- reading sessions
- profile-private data

Public data may include:

- catalog book metadata
- authors
- categories
- approved reviews
- public badges

---

# 12. Accessibility Rules

Reading comfort is a core product requirement.

Support:

- scalable text
- light theme
- sepia theme
- dark theme
- line height settings
- letter spacing settings
- reduced motion
- VoiceOver/TalkBack labels
- readable contrast
- haptic feedback for WPM changes
- large central word in fast mode

Readability profiles:

```text
standard
high_readability
dyslexia
low_vision
```

Reduced motion should reduce transitions and aggressive visual effects.

Fast mode should default to safer behavior when accessibility settings suggest it.

---

# 13. Localization Rules

Primary locale:

```text
ru-RU
```

Fallback locale:

```text
en-US
```

All user-facing strings should be localizable.

Internal enum values should stay language-neutral.

Example bookshelf statuses:

Internal:

```text
reading
finished
abandoned
want_to_read
```

Russian labels:

```text
Читаю
Прочитал
Брошено
Хочу прочитать
```

Support future RTL languages by not hardcoding assumptions unnecessarily.

Page direction should eventually be configurable or locale-aware.

---

# 14. Analytics Rules

Analytics should answer whether the core product works.

Track:

- import success/failure
- book opened
- reading session started
- reading session ended
- reader mode changed
- portrait-to-fast switch
- fast-to-portrait switch
- WPM changed
- mode lock toggled
- speed lock toggled
- progress checkpoint saved
- recommendation clicked
- note created
- bookmark created
- book completed

Do not track:

- private book text
- note content
- selected text
- raw uploaded file content

Analytics must be disableable in dev.

---

# 15. Testing Priorities

Highest-risk areas:

1. Losing reading progress
2. Poor orientation switching
3. Bad EPUB parsing
4. Weak offline behavior
5. Accidental fast-mode activation
6. Unreliable WPM timing
7. Sync conflicts
8. Corrupted file handling

Test these before secondary features.

Required test types:

- unit tests
- widget tests
- integration tests
- Maestro E2E tests
- manual QA on real devices

Core E2E flow:

```text
import EPUB
→ open in portrait reader
→ move forward
→ save progress
→ rotate to landscape
→ enter fast mode
→ change WPM
→ rotate back to portrait
→ confirm position continuity
→ exit
→ reopen
→ resume from saved position
```

---

# 16. Development Behavior for Claude

When implementing any task, Claude should:

1. Inspect existing project files first.
2. Implement only the requested task.
3. Avoid unrelated refactors.
4. Keep files small and readable.
5. Add tests where reasonable.
6. Explain what changed.
7. Mention assumptions or skipped items.
8. Not invent new features outside the plan.
9. Not change the final stack unless explicitly instructed.
10. Keep reader and fast-mode logic modular and testable.

Claude should not try to build the whole app in one response.

Work task by task.

---

# 17. Final Reminder

The most important feature is not the catalog, profile, badges, or reviews.

The most important feature is reliable reading continuity:

```text
normal reading
→ fast reading
→ normal reading
→ saved progress
→ resume later
```

If this loop is not stable, the app is not ready.
