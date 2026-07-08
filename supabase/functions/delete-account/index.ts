// Account self-deletion (TASK-0305 / TASK-1702).
//
// Auth user deletion needs the service role, which must never ship in the
// app — so the app invokes this function with the caller's JWT, and the
// function deletes the verified caller only. All user-owned rows cascade
// from auth.users (see migrations); storage objects under the user's prefix
// are removed best-effort.
//
// Deploy: supabase functions deploy delete-account
// (SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are
// provided automatically by the platform.)
import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const anon = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: userData, error: userError } = await anon.auth.getUser();
  const user = userData?.user;
  if (userError || !user) {
    return json({ error: "unauthorized" }, 401);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Cleanup is best-effort but NOT silent: failures are collected and returned
  // so the client (or a sweep job) knows some data may remain, rather than
  // reporting a clean deletion that left files/rows behind.
  const warnings: string[] = [];
  const PAGE = 1000;

  // Lists an entire storage folder, paging past the 1000-item limit.
  async function listAll(
    bucket: ReturnType<typeof admin.storage.from>,
    prefix: string,
  ): Promise<string[]> {
    const names: string[] = [];
    for (let offset = 0; ; offset += PAGE) {
      const { data, error } = await bucket.list(prefix, {
        limit: PAGE,
        offset,
      });
      if (error) throw error;
      const batch = data ?? [];
      for (const item of batch) names.push(item.name);
      if (batch.length < PAGE) break;
    }
    return names;
  }

  // Private book files are stored NESTED as <user>/<book uuid>/<file>.
  try {
    const bucket = admin.storage.from("book-files-private");
    const dirs = await listAll(bucket, user.id);
    const paths: string[] = [];
    for (const dir of dirs) {
      for (const name of await listAll(bucket, `${user.id}/${dir}`)) {
        paths.push(`${user.id}/${dir}/${name}`);
      }
    }
    for (let i = 0; i < paths.length; i += PAGE) {
      const { error } = await bucket.remove(paths.slice(i, i + PAGE));
      if (error) throw error;
    }
  } catch (e) {
    warnings.push(`storage cleanup failed: ${e}`);
  }

  // Uploaded book METADATA rows don't cascade from auth.users (books has no
  // user column) — delete them explicitly via book_files.owner_id BEFORE the
  // user is deleted (which cascade-drops book_files, the only owner link).
  try {
    const { data: owned, error: selErr } = await admin
      .from("book_files")
      .select("book_id")
      .eq("owner_id", user.id);
    if (selErr) throw selErr;
    const ids = (owned ?? []).map((r: { book_id: string }) => r.book_id);
    if (ids.length > 0) {
      const { error: delErr } = await admin
        .from("books")
        .delete()
        .in("id", ids)
        .eq("source_type", "upload");
      if (delErr) throw delErr;
    }
  } catch (e) {
    warnings.push(`book metadata cleanup failed: ${e}`);
  }

  // The account deletion itself must succeed (it cascades all user-owned rows).
  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) {
    return json({ error: error.message }, 500);
  }
  return json(warnings.length > 0 ? { ok: true, warnings } : { ok: true }, 200);
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
