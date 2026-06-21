-- Phase 1 — TASK-0104
-- Storage buckets and their access policies.
--
-- Path convention: private/per-user objects live under a folder named after
-- the owner's user id, e.g. `book-files-private/<user_id>/<book_id>.epub`.
-- Policies enforce that the first path segment equals auth.uid().

insert into storage.buckets (id, name, public)
values
  ('book-files-private', 'book-files-private', false),
  ('book-covers-public', 'book-covers-public', true),
  ('avatars-public', 'avatars-public', true)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- book-files-private: a user can only access objects under their own folder.
-- ---------------------------------------------------------------------------
create policy "book_files_private_select_own" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'book-files-private'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "book_files_private_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'book-files-private'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "book_files_private_update_own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'book-files-private'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "book_files_private_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'book-files-private'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------------
-- book-covers-public: anyone can read; authenticated users may write only
-- under their own folder. Catalog covers are managed by the service role.
-- ---------------------------------------------------------------------------
create policy "book_covers_public_read" on storage.objects
  for select using (bucket_id = 'book-covers-public');
create policy "book_covers_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'book-covers-public'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "book_covers_update_own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'book-covers-public'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "book_covers_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'book-covers-public'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------------
-- avatars-public: anyone can read; users manage only their own avatar folder.
-- ---------------------------------------------------------------------------
create policy "avatars_public_read" on storage.objects
  for select using (bucket_id = 'avatars-public');
create policy "avatars_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars-public'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "avatars_update_own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars-public'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "avatars_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars-public'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
