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

  // Best-effort: private book files are stored NESTED as
  // <user id>/<book uuid>/<file>, and storage list() is per-folder — so
  // walk one level of book folders and remove their files.
  try {
    const bucket = admin.storage.from("book-files-private");
    const { data: bookDirs } = await bucket.list(user.id, { limit: 1000 });
    const paths: string[] = [];
    for (const dir of bookDirs ?? []) {
      const { data: files } = await bucket.list(`${user.id}/${dir.name}`, {
        limit: 1000,
      });
      for (const f of files ?? []) {
        paths.push(`${user.id}/${dir.name}/${f.name}`);
      }
    }
    if (paths.length > 0) await bucket.remove(paths);
  } catch (_) {
    // Row cleanup still proceeds; orphaned objects can be swept later.
  }

  // Uploaded book METADATA rows don't cascade from auth.users (books has no
  // user column) — delete them explicitly or titles of the user's uploads
  // would outlive the account. Catalog rows are untouched.
  try {
    const { data: owned } = await admin
      .from("book_files")
      .select("book_id")
      .eq("owner_id", user.id);
    const ids = (owned ?? []).map((r: { book_id: string }) => r.book_id);
    if (ids.length > 0) {
      await admin
        .from("books")
        .delete()
        .in("id", ids)
        .eq("source_type", "upload");
    }
  } catch (_) {
    // Non-fatal: rows become orphaned metadata; sweep later.
  }

  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) {
    return json({ error: error.message }, 500);
  }
  return json({ ok: true }, 200);
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
