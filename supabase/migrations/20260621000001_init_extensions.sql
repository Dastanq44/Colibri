-- Phase 1 — TASK-0102
-- Extensions and shared helpers used by later migrations.

-- gen_random_uuid()
create extension if not exists pgcrypto;

-- Trigger function that keeps `updated_at` fresh on row updates.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
