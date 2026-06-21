-- Phase 1 — TASK-0103
-- Row Level Security. Private tables are scoped to the owning user; public
-- catalog data is world-readable; reviews are public only when approved.
--
-- Note: service_role bypasses RLS, so seeding and admin/edge-function writes
-- (catalog content, badge awards, review moderation) are unaffected.

-- ---------------------------------------------------------------------------
-- Public catalog (read-only for anon + authenticated; writes are service-role)
-- ---------------------------------------------------------------------------
alter table public.authors enable row level security;
alter table public.categories enable row level security;
alter table public.book_authors enable row level security;
alter table public.book_categories enable row level security;
alter table public.badges enable row level security;

create policy "authors_public_read" on public.authors
  for select using (true);
create policy "categories_public_read" on public.categories
  for select using (true);
create policy "book_authors_public_read" on public.book_authors
  for select using (true);
create policy "book_categories_public_read" on public.book_categories
  for select using (true);
create policy "badges_public_read" on public.badges
  for select using (true);

-- ---------------------------------------------------------------------------
-- books: catalog rows are public; uploaded rows are visible to their owner.
-- Owners may create/maintain their own uploaded book rows (used by import in
-- Phase 6). Catalog rows are managed by the service role.
-- ---------------------------------------------------------------------------
alter table public.books enable row level security;

create policy "books_read_catalog_or_owned" on public.books
  for select using (
    source_type = 'catalog'
    or exists (
      select 1 from public.book_files bf
      where bf.book_id = books.id and bf.owner_id = auth.uid()
    )
    or exists (
      select 1 from public.uploads u
      where u.book_id = books.id and u.user_id = auth.uid()
    )
  );

create policy "books_insert_upload" on public.books
  for insert to authenticated
  with check (source_type = 'upload');

create policy "books_update_owned_upload" on public.books
  for update to authenticated
  using (
    source_type = 'upload'
    and exists (
      select 1 from public.book_files bf
      where bf.book_id = books.id and bf.owner_id = auth.uid()
    )
  )
  with check (source_type = 'upload');

create policy "books_delete_owned_upload" on public.books
  for delete to authenticated
  using (
    source_type = 'upload'
    and exists (
      select 1 from public.book_files bf
      where bf.book_id = books.id and bf.owner_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------------
-- profiles: a user can only see and edit their own profile row.
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;

create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);
create policy "profiles_delete_own" on public.profiles
  for delete using (auth.uid() = id);

-- ---------------------------------------------------------------------------
-- book_files: owner-only (private uploads).
-- ---------------------------------------------------------------------------
alter table public.book_files enable row level security;

create policy "book_files_select_own" on public.book_files
  for select using (auth.uid() = owner_id);
create policy "book_files_insert_own" on public.book_files
  for insert with check (auth.uid() = owner_id);
create policy "book_files_update_own" on public.book_files
  for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "book_files_delete_own" on public.book_files
  for delete using (auth.uid() = owner_id);

-- ---------------------------------------------------------------------------
-- Per-user private tables scoped by user_id: identical 4-policy pattern.
-- ---------------------------------------------------------------------------
alter table public.user_bookshelf enable row level security;
create policy "user_bookshelf_select_own" on public.user_bookshelf
  for select using (auth.uid() = user_id);
create policy "user_bookshelf_insert_own" on public.user_bookshelf
  for insert with check (auth.uid() = user_id);
create policy "user_bookshelf_update_own" on public.user_bookshelf
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "user_bookshelf_delete_own" on public.user_bookshelf
  for delete using (auth.uid() = user_id);

alter table public.reading_progress enable row level security;
create policy "reading_progress_select_own" on public.reading_progress
  for select using (auth.uid() = user_id);
create policy "reading_progress_insert_own" on public.reading_progress
  for insert with check (auth.uid() = user_id);
create policy "reading_progress_update_own" on public.reading_progress
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "reading_progress_delete_own" on public.reading_progress
  for delete using (auth.uid() = user_id);

alter table public.reading_sessions enable row level security;
create policy "reading_sessions_select_own" on public.reading_sessions
  for select using (auth.uid() = user_id);
create policy "reading_sessions_insert_own" on public.reading_sessions
  for insert with check (auth.uid() = user_id);
create policy "reading_sessions_update_own" on public.reading_sessions
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "reading_sessions_delete_own" on public.reading_sessions
  for delete using (auth.uid() = user_id);

alter table public.bookmarks enable row level security;
create policy "bookmarks_select_own" on public.bookmarks
  for select using (auth.uid() = user_id);
create policy "bookmarks_insert_own" on public.bookmarks
  for insert with check (auth.uid() = user_id);
create policy "bookmarks_update_own" on public.bookmarks
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "bookmarks_delete_own" on public.bookmarks
  for delete using (auth.uid() = user_id);

alter table public.notes enable row level security;
create policy "notes_select_own" on public.notes
  for select using (auth.uid() = user_id);
create policy "notes_insert_own" on public.notes
  for insert with check (auth.uid() = user_id);
create policy "notes_update_own" on public.notes
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "notes_delete_own" on public.notes
  for delete using (auth.uid() = user_id);

alter table public.uploads enable row level security;
create policy "uploads_select_own" on public.uploads
  for select using (auth.uid() = user_id);
create policy "uploads_insert_own" on public.uploads
  for insert with check (auth.uid() = user_id);
create policy "uploads_update_own" on public.uploads
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "uploads_delete_own" on public.uploads
  for delete using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- reviews: public can read approved (non-deleted) reviews; owners manage own.
-- ---------------------------------------------------------------------------
alter table public.reviews enable row level security;

create policy "reviews_public_read_approved" on public.reviews
  for select using (status = 'approved' and deleted_at is null);
create policy "reviews_select_own" on public.reviews
  for select using (auth.uid() = user_id);
create policy "reviews_insert_own" on public.reviews
  for insert with check (auth.uid() = user_id);
create policy "reviews_update_own" on public.reviews
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "reviews_delete_own" on public.reviews
  for delete using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- review_reports: reporters can file and read their own reports.
-- ---------------------------------------------------------------------------
alter table public.review_reports enable row level security;

create policy "review_reports_insert_own" on public.review_reports
  for insert with check (auth.uid() = reporter_user_id);
create policy "review_reports_select_own" on public.review_reports
  for select using (auth.uid() = reporter_user_id);

-- ---------------------------------------------------------------------------
-- user_badges: a user can read the badges they have been awarded.
-- (Awards are written by the service role / an edge function.)
-- ---------------------------------------------------------------------------
alter table public.user_badges enable row level security;

create policy "user_badges_select_own" on public.user_badges
  for select using (auth.uid() = user_id);
