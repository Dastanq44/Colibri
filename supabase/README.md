# Colibri — Supabase backend

Backend foundation for Phase 1: schema, RLS, storage buckets, and seed data.
This directory is the source of truth for the database; apply it to a Supabase
project you control.

> Nothing here assumes a project is already created or linked. Follow the setup
> below for your own project.

## Layout

```
supabase/
  migrations/   # ordered SQL migrations (schema, RLS, storage, triggers)
  seed.sql      # sample authors/categories/badges/catalog books (re-runnable)
  policies/     # pointer only — policies live in the RLS/storage migrations
```

Migration order:

1. `..._init_extensions.sql` — pgcrypto + `set_updated_at()` helper
2. `..._catalog.sql` — books, authors, categories, join tables
3. `..._user_data.sql` — profiles, book_files, shelf, progress, sessions, bookmarks, notes, uploads
4. `..._reviews_badges.sql` — reviews, review_reports, badges, user_badges
5. `..._rls.sql` — enable RLS + all policies
6. `..._storage.sql` — buckets + storage.objects policies
7. `..._profile_on_signup.sql` — auto-create a profile row on new auth user

## Prerequisites

- A Supabase project (cloud) **or** Docker for the local stack.
- The Supabase CLI: https://supabase.com/docs/guides/cli

## Option A — Local stack (recommended for development)

```bash
# One-time, if this folder isn't initialized as a CLI project yet:
supabase init        # keeps existing migrations/ and seed.sql

# Start the local Postgres/Studio/storage stack:
supabase start

# Apply all migrations + run seed.sql on a fresh local DB:
supabase db reset
```

`supabase start` prints local `API URL` and `anon key`. Put them in `.env.dev`
(see `../.env.example`) and run the app with
`flutter run --dart-define-from-file=.env.dev`.

## Option B — Hosted project

```bash
# Link this repo to your project (find the ref in the dashboard URL):
supabase login
supabase link --project-ref <your-project-ref>

# Push migrations to the linked remote database:
supabase db push

# Seed data is NOT auto-applied to remote. Run it manually if you want samples:
#   psql "<connection-string>" -f supabase/seed.sql
# (or paste seed.sql into the dashboard SQL editor)
```

Then copy the project's `Project URL` and `anon` key from
**Project Settings → API** into `.env.staging` / `.env.production`.

## Option C — Dashboard only (no CLI)

Open **SQL Editor** in the dashboard and run the files in
`migrations/` in filename order, then optionally `seed.sql`.

## Storage buckets

The buckets are created by `..._storage.sql`:

| Bucket               | Public | Who can write                                  |
| -------------------- | ------ | ---------------------------------------------- |
| `book-files-private` | no     | owner only, under `book-files-private/<uid>/…` |
| `book-covers-public` | yes    | owner under `<uid>/…`; catalog via service role |
| `avatars-public`     | yes    | owner under `avatars-public/<uid>/…`           |

Private downloads use signed URLs; public buckets are readable by URL. The
first path segment must equal the user's id for private/per-user writes.

## Security notes

- Only the **anon key** is used by the Flutter app. Never put the service role
  key in the client or in `.env.*` files consumed by the app.
- `service_role` bypasses RLS — use it only server-side (seeding, edge
  functions, admin tools) for catalog content, badge awards, and review
  moderation.
- RLS is enabled on every user-owned table; verify with the dashboard's
  **Authentication → Policies** view after applying migrations.
