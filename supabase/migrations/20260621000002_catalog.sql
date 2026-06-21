-- Phase 1 — TASK-0102
-- Public catalog tables: books, authors, categories and their join tables.

create table public.books (
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

create table public.authors (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique,
  bio text,
  photo_url text,
  created_at timestamptz default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique,
  parent_id uuid references public.categories(id),
  created_at timestamptz default now()
);

create table public.book_authors (
  book_id uuid references public.books(id) on delete cascade,
  author_id uuid references public.authors(id) on delete cascade,
  sort_order int default 0,
  primary key (book_id, author_id)
);

create table public.book_categories (
  book_id uuid references public.books(id) on delete cascade,
  category_id uuid references public.categories(id) on delete cascade,
  primary key (book_id, category_id)
);

-- Indexes for catalog lookups / reverse joins.
create index idx_books_source_type on public.books (source_type);
create index idx_books_language on public.books (language);
create index idx_book_authors_author on public.book_authors (author_id);
create index idx_book_categories_category on public.book_categories (category_id);

-- Keep books.updated_at fresh.
create trigger trg_books_updated_at
  before update on public.books
  for each row execute function public.set_updated_at();
