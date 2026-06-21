# Policies

Row Level Security and storage policies are defined as **migrations** (so they
apply atomically with the schema), not as standalone files:

- Table RLS — `../migrations/20260621000005_rls.sql`
- Storage bucket policies — `../migrations/20260621000006_storage.sql`

This folder is kept as a documented pointer to match the planned project
structure. Add ad-hoc policy experiments here if useful, but the authoritative
policies live in the migrations above.
