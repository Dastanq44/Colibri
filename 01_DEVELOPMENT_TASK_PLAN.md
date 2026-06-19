# 01_DEVELOPMENT_TASK_PLAN.md

# Hybrid Mobile E-Reader Development Task Plan

## 0. Purpose of This File

This file is the main implementation plan for the hybrid mobile e-reader app.

Claude should use this file as the primary development backlog after reading:

1. `CLAUDE.md`
2. `docs/00_PROJECT_CONTEXT.md`
3. `docs/01_DEVELOPMENT_TASK_PLAN.md`

The research documents in `docs/research/` are background only. If there is a conflict between the research documents and this task plan, follow this task plan.

---

# 1. Product Summary

## 1.1 Product concept

Build a hybrid mobile e-reader for iOS and Android.

The app has two reading modes:

1. **Portrait orientation** = normal ebook reading.
2. **Landscape orientation** = fast-reading mode.

The app should feel like a serious mobile reader first, not like a speed-reading gimmick.

The key product idea is:

> Read normally when you want depth. Rotate your phone when you want speed.

## 1.2 Core user loop

The core loop of the product is:

1. User imports or opens a book.
2. User reads normally in portrait mode.
3. User rotates the phone to landscape.
4. Fast mode starts from the same reading position.
5. User adjusts WPM with screen taps.
6. User rotates back to portrait.
7. Normal reader continues from approximately the same position.
8. User exits the book.
9. User later reopens the app and resumes from saved progress.

## 1.3 MVP goal

The MVP must prove that the reading loop works reliably.

The MVP is not about building a marketplace, DRM system, OCR system, or social network. It is about validating the reader experience:

- normal reader
- fast reader
- orientation switching
- progress continuity
- offline reading
- basic sync
- personal library

---

# 2. Final Technical Stack

Use this stack:

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

Do not switch the project to:

- React Native
- Expo
- Firebase Firestore as the primary backend
- a custom backend
- a web-first implementation

---

# 3. MVP Scope

## 3.1 MVP includes

The MVP includes:

1. Onboarding
2. Auth
3. Home screen
4. Catalog screen
5. My Books screen
6. Book detail screen
7. Book import
8. Portrait normal reader
9. Landscape fast mode
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
23. Basic localization: Russian first, English fallback

## 3.2 MVP formats

Support these formats:

- EPUB
- TXT
- PDF

Rules:

- EPUB is the main MVP format.
- TXT is a simple reliable format.
- PDF is supported in normal reading mode.
- PDF fast mode is only available if the PDF has a usable text layer.
- Scanned PDF OCR is not part of MVP.

## 3.3 MVP excludes

Do not build these in MVP:

- DRM
- paid book store
- subscriptions
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

---

# 4. MVP Completion Definition

The MVP is complete only when this full scenario works:

1. User opens app.
2. User completes onboarding.
3. User signs up or signs in.
4. User imports an EPUB.
5. EPUB appears in My Books.
6. User opens the book in portrait reader.
7. User taps right to move forward.
8. Progress bar updates.
9. User rotates phone to landscape.
10. Fast mode opens from the same position.
11. User taps center to pause/play.
12. User taps right to increase WPM.
13. User sees `+25 WPM` feedback.
14. User rotates back to portrait.
15. Normal reader opens at approximately the same position.
16. User exits the reader.
17. User reopens the app later.
18. User continues from the saved position.
19. Progress syncs when online.
20. App does not crash.
21. Core analytics events are tracked.
22. Sentry captures errors.
23. Basic accessibility works.
24. App is ready for closed beta.

---

# 5. Architecture Principles

## 5.1 General architecture

Use feature-based architecture.

Recommended structure:

```text
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme/
      app_theme.dart
      app_colors.dart
      app_text_styles.dart
    localization/
      app_localizations.dart
  core/
    constants/
    errors/
    result/
    utils/
    logging/
    analytics/
    platform/
  data/
    local/
      app_database.dart
      tables/
      daos/
    remote/
      supabase_client_provider.dart
      edge_functions/
    repositories/
  features/
    onboarding/
    auth/
    home/
    catalog/
    library/
    book_detail/
    import/
    reader/
      domain/
      data/
      presentation/
      widgets/
      normal_mode/
      fast_mode/
    profile/
    settings/
    notes/
    reviews/
    recommendations/
    sync/
  shared/
    widgets/
    models/
    services/
test/
integration_test/
maestro/
supabase/
  migrations/
  seed.sql
  policies/
docs/
```

## 5.2 Layering rules

Keep these layers separate:

- UI
- state management
- domain models
- repositories
- local database
- remote Supabase access
- file system services
- reader engine
- fast-mode engine
- sync engine
- analytics
- platform-specific services

Rules:

- UI must not call Supabase directly.
- UI must not call Drift DAOs directly.
- Repositories mediate between UI/state and data sources.
- Reader engine should not depend on UI widgets.
- Fast-mode engine should be testable without UI.
- Sync logic should not be mixed into UI widgets.

## 5.3 Repository interfaces

Create these repository interfaces:

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

Each repository should return typed domain models or typed failures.

---

# 6. Routes

Use these app routes:

```text
/onboarding
/auth
/home
/catalog
/library
/profile
/settings
/book/:bookId
/reader/:bookId
/import
```

Recommended tab structure:

```text
Home
Catalog
My Books
Profile
```

Settings can be opened from Profile and Reader menu.

---

# 7. UX Specification

## 7.1 Onboarding

Onboarding should be short and practical.

### Screen 1

Title:

```text
Two ways to read
```

Body:

```text
Read normally in portrait. Rotate your phone for focused fast reading.
```

### Screen 2

Title:

```text
Fast mode
```

Body:

```text
Tap the center to pause. Tap right to go faster. Tap left to slow down.
```

### Screen 3

Title:

```text
Control rotation
```

Body:

```text
Use mode lock when reading lying down or when you do not want accidental switching.
```

Acceptance criteria:

- User sees onboarding only once after completion.
- User can skip onboarding.
- Onboarding state is stored locally.
- Copy is localizable.
- Onboarding explains the rotation-based mode switch.

---

## 7.2 Home screen

Goal:

Help the user return to reading quickly.

Home should include:

1. Greeting
2. Continue Reading section
3. Daily goal card
4. Recommendation rails
5. Quick actions

Continue Reading:

- show one large current book
- show up to two smaller recent books
- show title, author, cover, progress percent, and last opened time

Goal card:

- daily reading goal
- current streak
- yearly progress if available

Recommendation rails:

- similar to current books
- popular in favorite categories
- good for fast mode
- continue series

Quick actions:

- import book
- open catalog
- open library

Acceptance criteria:

- Home loads cached/local data first.
- Home refreshes from Supabase when online.
- Empty state appears when the user has no books.
- Continue Reading opens the reader at the last saved locator.
- Import action opens file picker.

---

## 7.3 Catalog screen

Goal:

Let users discover books.

MVP catalog supports:

1. List of catalog books
2. Search by title and author
3. Category filtering
4. Language filtering
5. Format filtering
6. Book detail navigation

Acceptance criteria:

- Catalog loads books from Supabase.
- Search works using Postgres full-text search.
- Filters can combine category, language, and format.
- Pagination works.
- Empty state appears for no results.
- Book cards show cover, title, author, format, and rating if available.

---

## 7.4 My Books screen

Goal:

Give the user a personal library workspace.

Required internal statuses:

```text
reading
finished
abandoned
want_to_read
```

Localized Russian labels:

```text
Читаю
Прочитал
Брошено
Хочу прочитать
```

Screen includes:

1. Status tabs
2. Grid/list toggle
3. Search within personal library
4. Sort by recent, title, author, progress
5. Import button
6. Book cards

Book card fields:

- cover
- title
- author
- status
- progress percent
- last opened time
- notes indicator if notes exist
- format badge: EPUB, TXT, PDF

Acceptance criteria:

- User can switch book status.
- User can filter by status.
- User can sort the list.
- Imported books appear immediately.
- Offline books are available without network.
- Deleting a local file does not delete cloud metadata unless explicitly confirmed.

---

## 7.5 Book detail screen

Book detail should include:

- cover
- title
- subtitle if available
- author
- description
- categories
- language
- format
- reading status
- rating if available
- CTA: Start / Continue / Add to My Books
- reviews section placeholder

Acceptance criteria:

- Book detail opens from Catalog, Home, and My Books.
- CTA changes depending on book state.
- User can add book to personal library.
- User can start or continue reading.

---

# 8. Reader Specification

## 8.1 Reader principles

The reader must:

1. Preserve position across normal and fast modes.
2. Work offline.
3. Save progress reliably.
4. Avoid visual clutter.
5. Be comfortable for long reading.
6. Handle rotation carefully.
7. Avoid global orientation lock.
8. Keep fast mode optional and reversible.

---

## 8.2 Portrait normal reader

Portrait reader contains:

1. Full text page
2. Left tap zone for previous page
3. Right tap zone for next page
4. Bottom progress bar
5. Bottom-left mode lock icon
6. Bottom-center progress percent
7. Bottom-right menu icon

Gestures:

- tap left = previous page
- tap right = next page
- optional swipe left/right = page navigation
- long press word/selection = note/highlight action if supported
- tap menu = open reader menu

Reader menu contains:

1. Table of contents
2. Search in book
3. Font settings
4. Theme settings
5. Notes
6. Bookmarks
7. Exit reader

Acceptance criteria:

- EPUB opens in portrait reader.
- TXT opens in portrait reader.
- PDF opens in normal PDF viewer.
- Tap left/right navigation works.
- Progress bar updates.
- Progress is saved locally.
- Reader restores last position after closing and reopening.
- Reader state survives app pause/resume.

---

## 8.3 Landscape fast mode

Fast mode contains:

1. Center current word or phrase.
2. Dimmed previous word or phrase.
3. Dimmed next word or phrase.
4. Bottom-left mode lock.
5. Bottom-center WPM.
6. Bottom-right progress or menu.
7. Temporary speed feedback overlay.

Gestures:

- tap center = pause/play
- tap right = increase speed by 25 WPM
- tap left = decrease speed by 25 WPM
- long press right = gradually increase WPM
- long press left = gradually decrease WPM
- tap WPM indicator = open precise speed control
- rotate back to portrait = return to normal reader

WPM rules:

```text
Default WPM: 275
Minimum WPM: 150
Maximum WPM: 700
Step: 25
Presets: 200, 275, 350, 425
```

Fast mode behavior:

- Fast mode starts paused the first time a user enters it for a book.
- After first successful use, remember user preference if needed.
- After app interruption, restore as paused, not playing.
- Speed changes show feedback for 500–800 ms.
- WPM is saved globally and optionally per book.
- Fast mode is disabled for content without extractable linear text.

Acceptance criteria:

- Rotating to landscape enters fast mode only inside Reader.
- App shell outside Reader does not switch modes.
- Mode lock prevents automatic switching.
- Fast mode starts from the same reading position.
- Returning to portrait returns to approximately the same text position.
- WPM controls work.
- Pause/play works.
- Progress saves during fast mode.
- App does not rapidly switch modes during unstable rotation.
- Add a 400–700 ms stability threshold before switching mode.

---

## 8.4 Mode lock

Mode lock controls whether Reader responds to orientation changes.

States:

```text
mode_lock_enabled = true
mode_lock_enabled = false
```

When enabled:

- Portrait remains normal reader even if device rotates.
- Landscape remains current mode unless user manually changes mode.
- Visual lock state is shown.

When disabled:

- Portrait uses normal reader.
- Landscape uses fast mode.

Acceptance criteria:

- User can toggle mode lock from reader bottom bar.
- Mode lock setting persists.
- Mode lock state is included in reader settings.
- Mode lock affects Reader only.
- Mode lock does not affect the rest of the app.

---

## 8.5 Speed lock

Speed lock is not a main visible MVP control.

Implement data model and settings support.

When speed lock is enabled:

- tap left/right does not change WPM
- center tap still pauses/plays
- WPM dial is disabled or requires unlock
- feedback message appears: `Speed locked`

Acceptance criteria:

- Speed lock exists in settings.
- Fast mode respects speed lock.
- Speed lock can be toggled.
- Speed lock does not block pause/play.

---

## 8.6 Text tokenization

Token model:

```text
token_id
book_id
chapter_index
paragraph_index
token_index
raw_text
normalized_text
start_offset
end_offset
locator
```

MVP tokenization:

1. chapters
2. paragraphs
3. words
4. phrase chunks later

Start with word-level display.

Acceptance criteria:

- EPUB text can be tokenized.
- TXT text can be tokenized.
- PDF text can be tokenized only when text layer exists.
- Tokenization preserves mapping back to locator.
- Fast mode can resume from token index.
- Tokenizer handles punctuation.
- Tokenizer handles Cyrillic and Latin text.
- Tokenizer is unit-tested.

---

# 9. Book Import Specification

## 9.1 Supported import formats

Allowed extensions:

```text
.epub
.txt
.pdf
```

## 9.2 Import pipeline

1. User taps Import.
2. System file picker opens.
3. User selects file.
4. App validates file extension and MIME type.
5. App copies file to app-controlled local storage.
6. App computes checksum.
7. App extracts metadata.
8. App extracts cover if possible.
9. App creates local book record.
10. App uploads file to Supabase Storage if user is logged in and sync is enabled.
11. App creates or updates cloud book metadata.
12. App shows success state.

## 9.3 Import statuses

Use these statuses:

```text
selected
copying
validating
extracting_metadata
extracting_cover
saving_local
uploading_cloud
ready
failed
```

## 9.4 Required fail states

Handle:

- unsupported file
- file too large
- corrupted file
- metadata extraction failed but file can still be imported
- cloud upload failed but local import succeeded
- PDF has no text layer, so fast mode is unavailable

Acceptance criteria:

- EPUB import works.
- TXT import works.
- PDF import works.
- Unsupported formats show clear error.
- Corrupted file does not crash app.
- Local import works offline.
- Cloud upload retries later if offline.
- Duplicate files are detected by checksum.
- PDF with no text layer is still readable in normal mode but fast mode is disabled.

---

# 10. Data Model

## 10.1 Supabase tables

Create the following tables.

### profiles

```sql
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  username text unique,
  avatar_url text,
  locale text default 'ru-RU',
  timezone text,
  goal_daily_minutes int default 20,
  goal_books_year int default 12,
  privacy_settings jsonb default '{}',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

### books

```sql
create table books (
  id uuid primary key default gen_random_uuid(),
  source_type text check (source_type in ('catalog', 'upload')),
  format text check (format in ('epub', 'txt', 'pdf')),
  title text not null,
  subtitle text,
  description text,
  language text,
  publisher text,
  published_at date,
  cover_url text,
  rights_scope text default 'user_upload',
  is_fast_mode_supported boolean default false,
  text_ready_status text default 'pending',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

### authors

```sql
create table authors (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique,
  bio text,
  photo_url text,
  created_at timestamptz default now()
);
```

### categories

```sql
create table categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique,
  parent_id uuid references categories(id),
  created_at timestamptz default now()
);
```

### book_authors

```sql
create table book_authors (
  book_id uuid references books(id) on delete cascade,
  author_id uuid references authors(id) on delete cascade,
  sort_order int default 0,
  primary key(book_id, author_id)
);
```

### book_categories

```sql
create table book_categories (
  book_id uuid references books(id) on delete cascade,
  category_id uuid references categories(id) on delete cascade,
  primary key(book_id, category_id)
);
```

### book_files

```sql
create table book_files (
  id uuid primary key default gen_random_uuid(),
  book_id uuid references books(id) on delete cascade,
  owner_id uuid references auth.users(id) on delete cascade,
  storage_path text,
  mime_type text,
  size_bytes bigint,
  checksum_sha256 text,
  ingest_status text default 'pending',
  text_extraction_status text default 'pending',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

### user_bookshelf

```sql
create table user_bookshelf (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  book_id uuid references books(id) on delete cascade,
  status text check (status in ('reading', 'finished', 'abandoned', 'want_to_read')),
  rating int check (rating >= 1 and rating <= 5),
  started_at timestamptz,
  finished_at timestamptz,
  added_at timestamptz default now(),
  last_opened_at timestamptz,
  unique(user_id, book_id)
);
```

### reading_progress

```sql
create table reading_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  book_id uuid references books(id) on delete cascade,
  locator_type text,
  locator_value text,
  chapter_href text,
  chapter_index int,
  page_number int,
  paragraph_index int,
  token_index int,
  percent numeric,
  mode text check (mode in ('normal', 'fast')),
  wpm int,
  device_id text,
  revision int default 1,
  updated_at timestamptz default now(),
  unique(user_id, book_id)
);
```

### reading_sessions

```sql
create table reading_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  book_id uuid references books(id) on delete cascade,
  mode text check (mode in ('normal', 'fast')),
  started_at timestamptz default now(),
  ended_at timestamptz,
  duration_seconds int,
  words_read int,
  avg_wpm int,
  device_id text,
  created_at timestamptz default now()
);
```

### bookmarks

```sql
create table bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  book_id uuid references books(id) on delete cascade,
  locator_type text,
  locator_value text,
  chapter_index int,
  paragraph_index int,
  token_index int,
  label text,
  created_at timestamptz default now(),
  deleted_at timestamptz
);
```

### notes

```sql
create table notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  book_id uuid references books(id) on delete cascade,
  locator_type text,
  locator_value text,
  selected_text text,
  note_text text,
  color text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz
);
```

### reviews

```sql
create table reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  book_id uuid references books(id) on delete cascade,
  rating int check (rating >= 1 and rating <= 5),
  title text,
  body text,
  status text default 'pending',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz,
  unique(user_id, book_id)
);
```

### review_reports

```sql
create table review_reports (
  id uuid primary key default gen_random_uuid(),
  review_id uuid references reviews(id) on delete cascade,
  reporter_user_id uuid references auth.users(id) on delete cascade,
  reason text,
  status text default 'open',
  created_at timestamptz default now(),
  resolved_at timestamptz
);
```

### badges

```sql
create table badges (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  title text not null,
  description text,
  icon_url text,
  rule_json jsonb,
  created_at timestamptz default now()
);
```

### user_badges

```sql
create table user_badges (
  user_id uuid references auth.users(id) on delete cascade,
  badge_id uuid references badges(id) on delete cascade,
  awarded_at timestamptz default now(),
  context_json jsonb default '{}',
  primary key(user_id, badge_id)
);
```

### uploads

```sql
create table uploads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  book_id uuid references books(id) on delete set null,
  original_file_name text,
  file_type text,
  storage_path text,
  checksum_sha256 text,
  ocr_needed boolean default false,
  ingest_status text default 'pending',
  error_message text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

---

## 10.2 Local Drift tables

Create local equivalents for offline-first reading.

### local_books

Fields:

```text
id text primary key
cloud_book_id text nullable
source_type text
format text
title text
author_display text
language text
cover_local_path text nullable
file_local_path text not null
checksum_sha256 text
is_fast_mode_supported bool
text_ready_status text
created_at text
updated_at text
last_opened_at text nullable
sync_status text
```

### local_bookshelf

Fields:

```text
book_id text primary key
status text
rating int nullable
started_at text nullable
finished_at text nullable
added_at text
last_opened_at text nullable
sync_status text
```

### local_reading_progress

Fields:

```text
book_id text primary key
locator_type text
locator_value text
chapter_href text nullable
chapter_index int nullable
page_number int nullable
paragraph_index int nullable
token_index int nullable
percent real
mode text
wpm int nullable
device_id text
revision int
updated_at text
sync_status text
```

### local_reader_settings

Fields:

```text
id int primary key
theme text
font_family text
font_size int
line_height real
letter_spacing real
page_animation text
mode_lock_enabled bool
speed_lock_enabled bool
auto_fast_mode_enabled bool
reduced_motion bool
locale text
page_turn_direction text
updated_at text
```

### local_fast_settings

Fields:

```text
id int primary key
default_wpm int
min_wpm int
max_wpm int
wpm_step int
show_adjacent_context bool
chunk_mode text
updated_at text
```

### local_reading_sessions

Fields:

```text
id text primary key
book_id text
mode text
started_at text
ended_at text nullable
duration_seconds int nullable
words_read int nullable
avg_wpm int nullable
sync_status text
```

### local_bookmarks

Fields:

```text
id text primary key
book_id text
locator_type text
locator_value text
chapter_index int nullable
paragraph_index int nullable
token_index int nullable
label text nullable
created_at text
deleted_at text nullable
sync_status text
```

### local_notes

Fields:

```text
id text primary key
book_id text
locator_type text
locator_value text
selected_text text nullable
note_text text
color text nullable
created_at text
updated_at text
deleted_at text nullable
sync_status text
```

### sync_queue

Fields:

```text
id text primary key
entity_type text
entity_id text
operation text
payload_json text
attempt_count int
last_attempt_at text nullable
next_attempt_at text nullable
status text
created_at text
```

---

# 11. Supabase Security and Storage

## 11.1 RLS requirements

Enable RLS on all user-owned tables.

Private user data:

- profiles
- user_bookshelf
- reading_progress
- reading_sessions
- bookmarks
- notes
- uploads
- private book_files

Public readable data:

- catalog books
- authors
- categories
- approved reviews
- badges

Acceptance criteria:

- User can only read/write their own private data.
- Public catalog is readable.
- Approved reviews are visible.
- Pending/deleted reviews are not public.
- Uploaded file storage paths are private.
- RLS policies are included in migrations.

## 11.2 Storage buckets

Create these buckets:

```text
book-files-private
book-covers-public
avatars-public
```

Rules:

book-files-private:

- private bucket
- users can access only their own uploads
- signed URLs for temporary access

book-covers-public:

- public bucket
- service role or owner can upload
- anyone can read

avatars-public:

- public bucket
- users can upload/update their own avatar path

Acceptance criteria:

- Book files are not publicly accessible.
- Covers load without signed URL.
- User uploads cannot overwrite another user’s files.
- Storage path includes user ID.

---

# 12. Sync Specification

## 12.1 Sync model

Use offline-first sync with explicit versioning.

Every progress record should include:

```text
device_id
revision
updated_at
last_known_server_revision
```

## 12.2 Sync queue operations

Supported operations:

```text
create
update
delete
upload_file
```

## 12.3 Sync triggers

Run sync:

- app start
- login
- book import
- progress save
- app resume
- manual refresh
- network reconnect

## 12.4 Progress conflict behavior

If local and cloud progress differ significantly, show a clear choice.

Example:

```text
We found two reading positions:
This device: Chapter 8, 42%
Cloud: Chapter 9, 47%
Continue from later position?
```

## 12.5 Acceptance criteria

- Progress syncs to Supabase.
- Offline progress queues locally.
- Reconnect sync works.
- Sync conflicts do not silently overwrite major progress.
- Notes and bookmarks sync.
- Imported book metadata syncs.
- Cloud upload failure does not break local reading.

---

# 13. Accessibility Specification

Support:

- system text scaling
- in-book text scaling
- light, sepia, and dark themes
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

Acceptance criteria:

- Reader settings persist.
- Theme changes apply immediately.
- Font size changes apply immediately.
- Fast mode supports larger central word.
- Reduced motion works.
- All fast-mode controls have accessibility labels.
- App remains usable with large text.

---

# 14. Analytics Specification

## 14.1 Events

Navigation events:

```text
screen_view_home
screen_view_catalog
screen_view_library
screen_view_profile
screen_view_reader_portrait
screen_view_reader_landscape
```

Import events:

```text
book_upload_started
book_upload_completed
book_upload_failed
```

Catalog events:

```text
catalog_search_performed
catalog_filter_applied
book_detail_opened
recommendation_clicked
```

Reading events:

```text
book_opened
reading_session_started
reading_session_ended
reader_mode_changed
mode_switch_portrait_to_fast
mode_switch_fast_to_portrait
wpm_changed
wpm_increased
wpm_decreased
pause_play_toggled
mode_lock_toggled
speed_lock_toggled
progress_checkpoint_saved
```

Retention events:

```text
book_completed
status_changed
note_created
bookmark_created
review_submitted
goal_completed_daily
streak_extended
```

## 14.2 KPIs

Track:

- crash-free sessions
- successful imports
- median time to first read
- percentage of users who enter fast mode
- percentage of users who return from fast mode to normal mode
- average WPM
- WPM change frequency
- reading sessions per user
- D1 retention
- D7 retention
- sync success rate
- search result click-through rate

Acceptance criteria:

- Analytics can be disabled in dev.
- Events do not include private book text.
- Sentry captures crashes.
- Sentry includes app version and device info.
- Reader errors are logged without leaking content.

---

# 15. Testing Plan

## 15.1 Unit tests

Cover:

- tokenizer
- WPM timing
- WPM boundaries
- progress calculation
- locator mapping
- sync conflict rules
- file validation
- status transitions
- settings persistence

## 15.2 Widget tests

Cover:

- Home empty state
- My Books status tabs
- Reader bottom bar
- WPM control
- Mode lock control
- Import status UI
- Settings UI

## 15.3 Integration tests

Cover:

1. Import EPUB
2. Open EPUB
3. Navigate pages
4. Save progress
5. Reopen book
6. Enter fast mode
7. Change WPM
8. Return to portrait
9. Confirm position continuity

## 15.4 Maestro E2E tests

Create flows:

```text
signup_delete_account.yaml
import_epub_read_resume.yaml
open_pdf.yaml
rotate_to_fast_mode.yaml
change_wpm.yaml
offline_read_reconnect_sync.yaml
change_book_status.yaml
create_note_bookmark.yaml
submit_review_report_review.yaml
```

## 15.5 Manual QA checklist

Test on:

- small Android phone
- mid-range Android phone
- iPhone SE-sized screen
- modern iPhone
- tablet if available
- dark mode
- large text
- offline mode
- slow network
- app background/resume
- system orientation lock
- corrupted file
- large file

Acceptance criteria:

- Critical E2E flows pass.
- App does not crash on bad files.
- Reading progress is not lost.
- Fast mode does not auto-switch repeatedly.
- Import and reader work offline.
- Crash-free sessions target is realistic for beta.

---

# 16. Implementation Phases and Tasks

## Phase 0: Project foundation

Goal:

Create a clean Flutter project ready for feature development.

### TASK-0001: Create Flutter project

Steps:

1. Create new Flutter app.
2. Enable iOS and Android targets.
3. Configure app name.
4. Configure package ID.
5. Add basic README.

Acceptance criteria:

- App builds on iOS simulator.
- App builds on Android emulator.
- No feature logic exists yet.

### TASK-0002: Add core packages

Add packages for:

- Riverpod
- Drift
- SQLite
- Supabase
- file picker
- path provider
- Sentry
- analytics
- localization
- routing
- testing

Acceptance criteria:

- Packages install correctly.
- App still builds.
- No unused experimental architecture is added.

### TASK-0003: Create folder structure

Create the feature-based folder structure defined in this plan.

Acceptance criteria:

- Folder structure exists.
- Empty placeholder files are used only where helpful.
- Structure matches this plan.

### TASK-0004: Configure routing

Create routes for:

```text
/onboarding
/auth
/home
/catalog
/library
/profile
/settings
/book/:bookId
/reader/:bookId
/import
```

Acceptance criteria:

- Placeholder screens are navigable.
- Bottom tabs work.
- Unknown route is handled.

### TASK-0005: Configure app theme

Create:

- light theme
- sepia reader theme
- dark theme
- typography scale
- spacing tokens
- radius tokens

Acceptance criteria:

- App uses theme values.
- Reader themes are represented.
- Theme code is centralized.

### TASK-0006: Configure localization

Set up:

- ru-RU
- en-US fallback
- localizable strings
- locale provider

Acceptance criteria:

- App can switch locale.
- Main placeholder strings are localized.
- Hardcoded user-facing strings are avoided.

### TASK-0007: Configure environment variables

Support:

```text
dev
staging
production
```

Variables:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
SENTRY_DSN
ANALYTICS_ENABLED
```

Acceptance criteria:

- Environment values are not hardcoded into source.
- Missing environment values fail clearly in dev.

---

## Phase 1: Supabase backend foundation

Goal:

Create backend schema, storage, and security.

### TASK-0101: Create Supabase project

Steps:

1. Create dev Supabase project.
2. Configure environment keys.
3. Document setup.

Acceptance criteria:

- Flutter can connect to dev Supabase.
- Setup is documented.

### TASK-0102: Create database migrations

Create migrations for all Supabase tables in this plan.

Acceptance criteria:

- Migrations run cleanly.
- Tables match schema.
- Constraints exist.

### TASK-0103: Add RLS policies

Add policies for:

- private user data
- public catalog data
- approved reviews
- private uploads

Acceptance criteria:

- RLS is enabled.
- Users cannot access other users' private data.
- Public catalog data is readable.

### TASK-0104: Create storage buckets

Create:

```text
book-files-private
book-covers-public
avatars-public
```

Acceptance criteria:

- Buckets exist.
- Access rules match this plan.

### TASK-0105: Add seed data

Add seed data for:

- sample authors
- sample categories
- sample public-domain book metadata
- starter badges

Acceptance criteria:

- Catalog has usable test data.
- Seed can be rerun safely if designed that way.

### TASK-0106: Create Supabase client provider

Steps:

1. Initialize Supabase.
2. Support environment config.
3. Add auth state stream.

Acceptance criteria:

- Flutter app connects to Supabase.
- App does not expose service role key.

---

## Phase 2: Local database and offline foundation

Goal:

Prepare the app for offline-first reading.

### TASK-0201: Create Drift database

Implement local tables:

- local_books
- local_bookshelf
- local_reading_progress
- local_reader_settings
- local_fast_settings
- local_reading_sessions
- local_bookmarks
- local_notes
- sync_queue

Acceptance criteria:

- Local database opens.
- Migrations work.

### TASK-0202: Create DAOs

Create:

- BooksDao
- BookshelfDao
- ProgressDao
- SettingsDao
- SessionsDao
- NotesDao
- SyncQueueDao

Acceptance criteria:

- DAOs support basic CRUD.
- Unit tests cover insert/update where practical.

### TASK-0203: Create local data models

Create typed local models and mapping extensions.

Acceptance criteria:

- Local database models map to domain models.
- Mapping logic is testable.

### TASK-0204: Create repository interfaces

Create abstract repository classes listed in this plan.

Acceptance criteria:

- Interfaces compile.
- UI can depend on interfaces, not implementations.

### TASK-0205: Create sync status system

Use statuses:

```text
local_only
pending_upload
pending_update
synced
failed
deleted
```

Acceptance criteria:

- Sync status is represented consistently across local tables.

### TASK-0206: Create device ID service

Generate and persist stable device ID.

Acceptance criteria:

- Device ID persists across app restarts.
- Device ID is available to progress and sync logic.

---

## Phase 3: Auth and profile

Goal:

Allow users to create accounts and manage profile.

### TASK-0301: Build auth UI

Screens:

- sign in
- sign up
- forgot password
- auth loading state

Acceptance criteria:

- Auth screens render.
- Validation errors are shown clearly.
- Strings are localizable.

### TASK-0302: Implement Supabase Auth

Support:

- email/password sign up
- email/password sign in
- sign out
- auth state listener

Acceptance criteria:

- User can sign up.
- User can sign in.
- User can sign out.
- Auth state persists across restart.

### TASK-0303: Create profile on signup

When user signs up:

- create profile row
- set default locale
- set default goals

Acceptance criteria:

- Profile row exists after signup.
- Failure is handled.

### TASK-0304: Build profile screen MVP

Show:

- avatar placeholder
- display name
- books read
- current books
- reading streak placeholder
- average WPM placeholder
- badges section placeholder
- settings entry

Acceptance criteria:

- Profile screen loads current user data.
- Empty stats do not break UI.

### TASK-0305: Implement account deletion path

Add UI and repository method for account deletion.

Acceptance criteria:

- Account deletion entry exists.
- User is asked for confirmation.
- Actual deletion workflow can be completed later if needed.

---

## Phase 4: App shell and static screens

Goal:

Build navigable app shell before advanced logic.

### TASK-0401: Build bottom tab navigation

Tabs:

- Home
- Catalog
- My Books
- Profile

Acceptance criteria:

- Tabs work.
- Tab state does not reset unnecessarily.

### TASK-0402: Build Home UI

Include:

- Continue Reading
- Goals
- Recommendations
- Quick actions

Acceptance criteria:

- Home layout matches product direction.
- Empty states exist.

### TASK-0403: Build Catalog UI

Include:

- search bar
- filters
- book list/grid
- empty state

Acceptance criteria:

- Catalog screen works with mock data.
- UI can later connect to repository.

### TASK-0404: Build My Books UI

Include:

- status tabs
- grid/list toggle
- import button
- empty states

Acceptance criteria:

- Status tabs are visible.
- Import button opens placeholder route/action.

### TASK-0405: Build Book Detail UI

Include:

- cover
- title
- author
- description
- format
- add/start button
- reviews placeholder

Acceptance criteria:

- Book detail renders mock data.
- CTA has placeholder action.

### TASK-0406: Build Settings UI

Include:

- theme
- font size
- line height
- mode lock
- speed lock
- default WPM
- reduced motion
- language

Acceptance criteria:

- Settings screen renders.
- Settings are ready to connect to local database.

---

## Phase 5: Catalog and library data

Goal:

Connect Home, Catalog, Book Detail, and My Books to real data.

### TASK-0501: Implement CatalogRepository

Functions:

```text
searchBooks
getBookDetails
getBooksByCategory
getBooksByAuthor
```

Acceptance criteria:

- Repository loads catalog books from Supabase.
- Search and filters work.

### TASK-0502: Implement LibraryRepository

Functions:

```text
getMyBooks
addBookToLibrary
updateBookStatus
removeBookFromLibrary
getContinueReading
```

Acceptance criteria:

- User can add book to library.
- My Books loads real data.
- Status updates work.

### TASK-0503: Connect Catalog UI

Acceptance criteria:

- Catalog shows real Supabase data.
- Pagination works.
- Empty state works.

### TASK-0504: Connect Book Detail UI

Acceptance criteria:

- Book details load.
- Add/start action works.
- Status is reflected.

### TASK-0505: Connect My Books UI

Acceptance criteria:

- Local data loads first.
- Cloud refresh works when online.
- Sorting and filtering work.

### TASK-0506: Connect Home UI

Acceptance criteria:

- Continue Reading uses local progress.
- Recommendation rails use repository rules.

---

## Phase 6: Book import

Goal:

Allow user-owned book imports.

### TASK-0601: Implement file picker

Use system picker.

Allowed extensions:

```text
.epub
.txt
.pdf
```

Acceptance criteria:

- File picker opens.
- User can select supported files.

### TASK-0602: Implement file validator

Validate:

- extension
- MIME type when available
- max size
- readable file path
- duplicate checksum

Acceptance criteria:

- Unsupported files show clear error.
- Duplicate files are handled.

### TASK-0603: Implement local file copy

Copy selected file into app-controlled storage.

Acceptance criteria:

- File remains available offline.
- App does not rely on external file path.

### TASK-0604: Implement checksum service

Compute SHA-256.

Acceptance criteria:

- Checksum is stored.
- Duplicate detection can use checksum.

### TASK-0605: Implement metadata extraction

For EPUB:

- title
- author
- language
- cover if possible
- table of contents if possible

For TXT:

- file name as title
- unknown author
- language if detectable later

For PDF:

- title if metadata exists
- page count if available
- cover thumbnail later if possible

Acceptance criteria:

- Metadata extraction does not block import if partial.
- Failed metadata extraction is not fatal.

### TASK-0606: Create local book record

Insert into:

- local_books
- local_bookshelf
- local_reading_progress initial row

Acceptance criteria:

- Book appears in My Books after import.
- Initial progress exists.

### TASK-0607: Implement optional cloud upload

If logged in and sync enabled:

- upload to Supabase Storage
- create books row
- create book_files row
- create user_bookshelf row

Acceptance criteria:

- Upload works online.
- Upload failure queues retry.
- Local import still succeeds if upload fails.

### TASK-0608: Build import progress UI

Show statuses:

- validating
- extracting metadata
- saving
- uploading
- ready
- failed

Acceptance criteria:

- User sees progress.
- Errors are understandable.

---

## Phase 7: Normal reader MVP

Goal:

Build the portrait reading experience.

### TASK-0701: Define Reader domain models

Create:

```text
BookDocument
BookChapter
BookPage
ReaderLocator
ReaderProgress
ReaderMode
ReaderSettings
```

Acceptance criteria:

- Reader models compile.
- Models are independent from UI.

### TASK-0702: Implement TXT reader

Steps:

1. Load TXT file.
2. Split into paragraphs.
3. Paginate by screen size and font settings.
4. Support next/previous page.
5. Save locator.

Acceptance criteria:

- TXT book opens.
- Navigation works.
- Progress saves.

### TASK-0703: Implement EPUB reader pipeline

Start with simple EPUB text extraction and Flutter rendering path.

Acceptance criteria:

- Simple EPUB opens.
- Text is readable.
- Progress can be tracked.

### TASK-0704: Implement PDF normal reader

Use stable PDF viewer approach.

Acceptance criteria:

- PDF opens.
- PDF page navigation works.
- PDF progress saves by page number.

### TASK-0705: Build portrait reader UI

Elements:

- text area
- left/right tap zones
- bottom bar
- progress bar
- lock icon
- menu icon

Acceptance criteria:

- Portrait reader UI is calm and minimal.
- Tap zones work.

### TASK-0706: Implement progress saving

Save progress:

- on page change
- every 10–15 seconds while reading
- on app pause
- on reader exit
- before mode switch

Acceptance criteria:

- Progress is not lost.
- Resume works after app restart.

### TASK-0707: Implement resume

Open book from last locator.

Acceptance criteria:

- User returns to saved position.
- Unsupported/missing locator has safe fallback.

---

## Phase 8: Fast mode engine

Goal:

Build the core fast-reading system independent from UI.

### TASK-0801: Create tokenizer

Implement tokenizer for:

- TXT
- extracted EPUB text
- PDF text if available

Acceptance criteria:

- Tokenizer handles Cyrillic and Latin.
- Tokenizer handles punctuation.
- Tokenizer has unit tests.

### TASK-0802: Create token stream model

Each token maps back to:

- book ID
- chapter index
- paragraph index
- token index
- locator
- character offset

Acceptance criteria:

- Token stream can resume from token index.
- Tokens map back to normal reader location.

### TASK-0803: Create FastModeController

States:

```text
idle
ready
playing
paused
completed
error
```

Fields:

```text
currentTokenIndex
currentToken
previousToken
nextToken
wpm
isPlaying
isPaused
progressPercent
elapsedTime
wordsRead
```

Acceptance criteria:

- Controller works without UI.
- State transitions are predictable.

### TASK-0804: Implement WPM timer

Formula:

```text
millisecondsPerToken = 60000 / wpm
```

For phrase chunks later:

```text
milliseconds = 60000 * wordCountInChunk / wpm
```

Acceptance criteria:

- Timer respects WPM.
- WPM boundaries are enforced.

### TASK-0805: Implement controls

Functions:

```text
play
pause
togglePlayPause
increaseWpm
decreaseWpm
setWpm
seekToToken
savePosition
```

Acceptance criteria:

- Controls work.
- Speed lock is respected.

### TASK-0806: Implement progress mapping

Map token index back to reader locator.

Acceptance criteria:

- Fast mode position can restore normal reader position.

### TASK-0807: Add unit tests

Test:

- tokenization
- WPM timing
- WPM boundaries
- speed lock
- pause/resume
- progress calculation
- locator mapping

Acceptance criteria:

- Core fast-mode engine has test coverage.

---

## Phase 9: Landscape fast mode UI

Goal:

Connect fast mode engine to landscape reader UI.

### TASK-0901: Detect orientation inside Reader

Acceptance criteria:

- Reader detects orientation.
- App does not globally lock orientation.
- Other screens do not auto-switch behavior.

### TASK-0902: Add stability threshold

Use threshold:

```text
400–700 ms
```

Acceptance criteria:

- App avoids rapid switching due to unstable rotation.

### TASK-0903: Implement mode switching

Rules:

- portrait -> normal reader
- landscape -> fast mode
- mode lock disables auto-switch
- returning to portrait restores normal reader at mapped locator

Acceptance criteria:

- Mode switching works.
- Position continuity works.

### TASK-0904: Build fast mode UI

Elements:

- previous token dimmed
- current token centered
- next token dimmed
- left speed zone
- center pause zone
- right speed zone
- bottom WPM/progress/lock bar

Acceptance criteria:

- Fast mode UI is readable.
- Tap zones are clear but not visually noisy.

### TASK-0905: Implement tap controls

- center tap toggles pause/play
- right tap increases WPM
- left tap decreases WPM

Acceptance criteria:

- Tap controls work reliably.

### TASK-0906: Implement transient feedback

Show:

```text
+25 WPM
-25 WPM
Speed locked
Paused
```

Duration:

```text
500–800 ms
```

Acceptance criteria:

- Feedback appears and disappears cleanly.

### TASK-0907: Implement precise WPM control

MVP can use bottom sheet slider.

Circular dial can be V1.

Acceptance criteria:

- User can set WPM precisely.
- WPM stays within allowed range.

### TASK-0908: Implement mode lock UI

Acceptance criteria:

- Lock icon toggles mode lock.
- Setting persists.
- UI shows lock state.

---

## Phase 10: Reader settings and accessibility

Goal:

Make reading comfortable and accessible.

### TASK-1001: Implement reader settings panel

Settings:

- theme
- font size
- font family
- line height
- letter spacing
- page animation
- default WPM
- mode lock
- speed lock
- reduced motion

Acceptance criteria:

- Settings persist.
- Settings apply to reader.

### TASK-1002: Implement themes

Themes:

```text
light
sepia
dark
```

Acceptance criteria:

- Themes apply immediately.
- Themes are readable.

### TASK-1003: Implement readability profiles

Profiles:

```text
standard
high_readability
dyslexia
low_vision
```

Acceptance criteria:

- Profiles adjust text settings.
- User can customize after applying profile.

### TASK-1004: Implement system text scaling support

Acceptance criteria:

- App remains usable with larger system text.

### TASK-1005: Implement reduced motion

Acceptance criteria:

- Reduced motion reduces transitions.
- Fast mode defaults to safer behavior.

### TASK-1006: Add accessibility labels

Add labels for:

- left tap zone
- right tap zone
- center pause zone
- WPM control
- lock button
- menu
- progress bar

Acceptance criteria:

- Screen readers can identify controls.

### TASK-1007: Add haptics

Use subtle haptic feedback for:

- WPM change
- mode lock toggle
- entering fast mode
- reaching book completion

Acceptance criteria:

- Haptics are optional/respect platform behavior.

---

## Phase 11: Notes and bookmarks

Goal:

Add basic retention and utility features.

### TASK-1101: Add bookmark creation

From reader menu:

- create bookmark at current locator
- optional label

Acceptance criteria:

- Bookmark can be created.
- Bookmark stores locator.

### TASK-1102: Add notes MVP

From reader menu or text selection if supported:

- create note at current locator
- save note text
- show notes list

Acceptance criteria:

- Note can be created.
- Note stores locator.

### TASK-1103: Build notes/bookmarks screen

Show:

- book title
- note text
- selected text if available
- created date
- tap to jump to location

Acceptance criteria:

- User can view notes and bookmarks.
- User can jump to a saved location.

### TASK-1104: Sync notes/bookmarks

Use sync queue and soft deletes.

Acceptance criteria:

- Notes work offline.
- Notes sync when online.
- Deleted notes use soft delete.

---

## Phase 12: Sync system

Goal:

Make local-first data sync with Supabase.

### TASK-1201: Implement sync queue processor

Operations:

```text
create
update
delete
upload_file
```

Acceptance criteria:

- Queue processes pending operations.
- Failed operations retry.

### TASK-1202: Implement progress sync

Rules:

- use device_id
- use revision
- use updated_at
- prefer newest valid revision
- avoid silently jumping backwards

Acceptance criteria:

- Progress syncs reliably.
- Major conflicts are detected.

### TASK-1203: Implement conflict detection

Acceptance criteria:

- User sees clear choice when conflict is significant.
- Minor updates resolve automatically.

### TASK-1204: Implement sync triggers

Run sync on:

- app start
- login
- book import
- progress save
- app resume
- manual refresh
- network reconnect

Acceptance criteria:

- Sync happens without user micromanagement.
- Manual refresh exists where useful.

### TASK-1205: Implement offline indicators

Show subtle state:

- offline
- syncing
- synced
- sync failed

Acceptance criteria:

- User understands sync state.
- Reading is not blocked by sync issues.

---

## Phase 13: Reviews and ratings

Reviews are optional for MVP.

If implemented, keep them simple and moderated.

### TASK-1301: Add rating on bookshelf

Acceptance criteria:

- User can privately rate a book 1–5.

### TASK-1302: Add public review composer

Fields:

- rating
- title
- body

Acceptance criteria:

- User can submit review.

### TASK-1303: Add review status

Statuses:

```text
pending
approved
rejected
deleted
```

Acceptance criteria:

- Only approved reviews are public.

### TASK-1304: Add report review action

Reasons:

- spam
- abuse
- offensive
- copyright
- other

Acceptance criteria:

- User can report review.
- Report is stored.

### TASK-1305: Show approved reviews only

Acceptance criteria:

- Book detail shows approved reviews.
- Deleted/rejected reviews are hidden.

---

## Phase 14: Recommendations

Goal:

Add simple explainable recommendation rails.

### MVP recommendation rules

Generate recommendations by:

1. same author
2. same category
3. same language
4. popular in user’s categories
5. continue series
6. good for fast mode
7. return to abandoned book

### TASK-1401: Create RecommendationRepository

Functions:

```text
getHomeRecommendationRails
getSimilarBooks
getGoodForFastMode
getReturnToAbandoned
```

Acceptance criteria:

- Recommendations are generated without ML.
- Rails are explainable.

### TASK-1402: Add recommendation reasons

Examples:

```text
Because you read ...
Same author
Popular in ...
Good for fast mode
Continue the series
```

Acceptance criteria:

- Every recommendation has a reason.

### TASK-1403: Track clicks

Acceptance criteria:

- Recommendation impressions and clicks are tracked.

---

## Phase 15: Analytics and crash reporting

Goal:

Measure whether the product works.

### TASK-1501: Add analytics service

Acceptance criteria:

- Events from this plan can be logged.
- Analytics can be disabled in dev.
- No private book text is sent.

### TASK-1502: Add Sentry

Acceptance criteria:

- Crashes are captured.
- Reader errors are logged safely.
- App version and device info are included.

### TASK-1503: Track reader events

Acceptance criteria:

- Mode changes are tracked.
- WPM changes are tracked.
- Progress checkpoints are tracked.

### TASK-1504: Track import events

Acceptance criteria:

- Import start/success/failure are tracked.
- Failure reason is tracked without private content.

---

## Phase 16: QA and automated testing

Goal:

Protect the core reading loop.

### TASK-1601: Add unit tests

Acceptance criteria:

- Tokenizer, WPM, progress, sync, and validation logic are tested.

### TASK-1602: Add widget tests

Acceptance criteria:

- Critical UI components have basic tests.

### TASK-1603: Add integration tests

Acceptance criteria:

- Import/open/read/resume flow is covered.

### TASK-1604: Add Maestro flows

Acceptance criteria:

- Critical E2E flows exist.
- Documentation explains how to run them.

### TASK-1605: Manual QA pass

Acceptance criteria:

- App is tested on multiple devices/screen sizes.
- Offline and rotation edge cases are tested.

---

## Phase 17: Release preparation

Goal:

Prepare closed beta and store submission.

### TASK-1701: Prepare closed beta build

Acceptance criteria:

- App can be distributed through TestFlight.
- Android internal testing build works.

### TASK-1702: Prepare privacy and data safety

Acceptance criteria:

- Privacy policy exists.
- Data safety information is prepared.
- Account deletion path exists.

### TASK-1703: Prepare store assets

Acceptance criteria:

- App icon exists.
- Screenshots exist.
- Description avoids misleading speed-reading claims.

### TASK-1704: Beta feedback checklist

Ask testers:

1. Did you understand rotation-based fast mode?
2. Did accidental rotation annoy you?
3. Was WPM control comfortable?
4. Did you trust the app to save progress?
5. Would you use this for real reading?

Acceptance criteria:

- Feedback is collected.
- Critical issues are prioritized.

---

# 17. Claude Prompt Sequence

## Prompt 1: Project foundation

```text
You are helping me build a Flutter mobile app: a hybrid e-reader for iOS and Android.

Before coding, read:
- CLAUDE.md
- docs/00_PROJECT_CONTEXT.md
- docs/01_DEVELOPMENT_TASK_PLAN.md

Use CLAUDE.md and 01_DEVELOPMENT_TASK_PLAN.md as the source of truth. The deep research documents are background only. If there is a conflict, follow CLAUDE.md and the final task plan.

The app has two reading modes:
1. Portrait orientation = normal ebook reading.
2. Landscape orientation = fast-reading mode with centered word/phrase display.

The app must be a serious reader first, not a speed-reading gimmick. The core loop is:
import/open book → read normally → rotate to landscape for fast mode → adjust WPM → return to portrait without losing position → resume later.

Final stack:
- Flutter + Dart
- Riverpod
- Drift/SQLite
- Supabase Auth/Postgres/Storage/Edge Functions
- Sentry
- Firebase Analytics or Amplitude
- Maestro for E2E tests

MVP formats:
- EPUB
- TXT
- PDF

PDF fast mode is only available if a usable text layer exists.

Do not implement DRM, OCR, in-app store, subscriptions, ML recommendations, or social feed in MVP.

Your first task:
Create the initial Flutter project architecture and folder structure for this app.

Requirements:
1. Use feature-based architecture.
2. Add routing structure for onboarding, auth, home, catalog, library, profile, settings, book detail, reader, and import.
3. Add theme structure with light, sepia, and dark reader themes.
4. Add localization structure with ru-RU and en-US fallback.
5. Add placeholder repository interfaces for auth, books, catalog, library, import, reader, progress, settings, sync, analytics, notes, reviews, and recommendations.
6. Add environment config structure for dev, staging, and production.
7. Do not implement real reader logic yet.
8. Keep code clean, modular, and ready for later phases.

Before coding, briefly inspect the existing project files if any. Then implement only this foundation step.
```

## Prompt 2: Local database

```text
Continue the Flutter hybrid e-reader project.

Now implement the local database foundation using Drift/SQLite.

Create local tables for:
- local_books
- local_bookshelf
- local_reading_progress
- local_reader_settings
- local_fast_settings
- local_reading_sessions
- local_bookmarks
- local_notes
- sync_queue

Requirements:
1. Add Drift database setup.
2. Add DAOs for books, bookshelf, progress, settings, sessions, notes, and sync queue.
3. Add typed models or mapping extensions where useful.
4. Add default reader settings:
   - theme: light
   - font size: 18
   - line height: 1.5
   - mode lock: false
   - speed lock: false
   - auto fast mode: true
   - default WPM: 275
   - min WPM: 150
   - max WPM: 700
   - WPM step: 25
5. Add a persistent device ID service.
6. Add basic unit tests for inserting and updating books, settings, and reading progress.

Do not implement Supabase sync yet. Keep this local-first.
```

## Prompt 3: Supabase backend

```text
Continue the Flutter hybrid e-reader project.

Now implement Supabase backend integration.

Requirements:
1. Add Supabase client initialization using environment config.
2. Create SQL migrations for:
   - profiles
   - books
   - authors
   - categories
   - book_authors
   - book_categories
   - book_files
   - user_bookshelf
   - reading_progress
   - reading_sessions
   - bookmarks
   - notes
   - reviews
   - review_reports
   - badges
   - user_badges
   - uploads
3. Enable RLS on user-owned tables.
4. Add policies so users can only access their own private data.
5. Allow public read access for catalog books, authors, categories, badges, and approved reviews.
6. Add storage bucket setup instructions for:
   - book-files-private
   - book-covers-public
   - avatars-public
7. Implement AuthRepository with sign up, sign in, sign out, get current user, and auth state stream.
8. Create profile row after sign up.

Do not implement reader logic yet.
```

---

# 18. Development Notes for Claude

Claude should follow these rules for every task:

1. Inspect existing files first.
2. Implement only the requested task.
3. Avoid unrelated refactors.
4. Keep files small and readable.
5. Add tests where reasonable.
6. Explain what changed.
7. Mention assumptions or skipped items.
8. Do not invent new features outside this plan.
9. Do not change final stack unless explicitly instructed.
10. Keep the reader and fast-mode engine modular and testable.

---

# 19. Final Reminder

The project succeeds only if the reader experience feels reliable.

The most important technical risks are:

1. losing reading progress
2. poor orientation switching
3. bad EPUB parsing
4. weak offline behavior
5. accidental fast-mode activation
6. unreliable WPM timing
7. messy sync conflicts

Prioritize these risks before adding secondary features.
