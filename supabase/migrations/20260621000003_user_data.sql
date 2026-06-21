-- Phase 1 — TASK-0102
-- Per-user private data: profiles, book files, shelf, progress, sessions,
-- bookmarks, notes, uploads.

create table public.profiles (
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

create table public.book_files (
  id uuid primary key default gen_random_uuid(),
  book_id uuid references public.books(id) on delete cascade,
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

create table public.user_bookshelf (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  book_id uuid references public.books(id) on delete cascade,
  status text check (status in ('reading', 'finished', 'abandoned', 'want_to_read')),
  rating int check (rating >= 1 and rating <= 5),
  started_at timestamptz,
  finished_at timestamptz,
  added_at timestamptz default now(),
  last_opened_at timestamptz,
  unique (user_id, book_id)
);

create table public.reading_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  book_id uuid references public.books(id) on delete cascade,
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
  unique (user_id, book_id)
);

create table public.reading_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  book_id uuid references public.books(id) on delete cascade,
  mode text check (mode in ('normal', 'fast')),
  started_at timestamptz default now(),
  ended_at timestamptz,
  duration_seconds int,
  words_read int,
  avg_wpm int,
  device_id text,
  created_at timestamptz default now()
);

create table public.bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  book_id uuid references public.books(id) on delete cascade,
  locator_type text,
  locator_value text,
  chapter_index int,
  paragraph_index int,
  token_index int,
  label text,
  created_at timestamptz default now(),
  deleted_at timestamptz
);

create table public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  book_id uuid references public.books(id) on delete cascade,
  locator_type text,
  locator_value text,
  selected_text text,
  note_text text,
  color text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz
);

create table public.uploads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  book_id uuid references public.books(id) on delete set null,
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

-- Indexes supporting RLS predicates and common per-user lookups.
create index idx_book_files_owner on public.book_files (owner_id);
create index idx_book_files_book on public.book_files (book_id);
create index idx_user_bookshelf_user on public.user_bookshelf (user_id);
create index idx_reading_progress_user on public.reading_progress (user_id);
create index idx_reading_sessions_user on public.reading_sessions (user_id);
create index idx_reading_sessions_book on public.reading_sessions (book_id);
create index idx_bookmarks_user_book on public.bookmarks (user_id, book_id);
create index idx_notes_user_book on public.notes (user_id, book_id);
create index idx_uploads_user on public.uploads (user_id);

-- updated_at triggers.
create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger trg_book_files_updated_at
  before update on public.book_files
  for each row execute function public.set_updated_at();
create trigger trg_reading_progress_updated_at
  before update on public.reading_progress
  for each row execute function public.set_updated_at();
create trigger trg_notes_updated_at
  before update on public.notes
  for each row execute function public.set_updated_at();
create trigger trg_uploads_updated_at
  before update on public.uploads
  for each row execute function public.set_updated_at();
