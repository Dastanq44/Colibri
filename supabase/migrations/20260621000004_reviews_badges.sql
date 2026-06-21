-- Phase 1 — TASK-0102
-- Reviews (moderated), review reports, badges and awarded user badges.

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  book_id uuid references public.books(id) on delete cascade,
  rating int check (rating >= 1 and rating <= 5),
  title text,
  body text,
  status text default 'pending',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  deleted_at timestamptz,
  unique (user_id, book_id)
);

create table public.review_reports (
  id uuid primary key default gen_random_uuid(),
  review_id uuid references public.reviews(id) on delete cascade,
  reporter_user_id uuid references auth.users(id) on delete cascade,
  reason text,
  status text default 'open',
  created_at timestamptz default now(),
  resolved_at timestamptz
);

create table public.badges (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  title text not null,
  description text,
  icon_url text,
  rule_json jsonb,
  created_at timestamptz default now()
);

create table public.user_badges (
  user_id uuid references auth.users(id) on delete cascade,
  badge_id uuid references public.badges(id) on delete cascade,
  awarded_at timestamptz default now(),
  context_json jsonb default '{}',
  primary key (user_id, badge_id)
);

create index idx_reviews_book_status on public.reviews (book_id, status);
create index idx_review_reports_review on public.review_reports (review_id);

create trigger trg_reviews_updated_at
  before update on public.reviews
  for each row execute function public.set_updated_at();
