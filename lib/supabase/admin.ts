import { createClient } from "@supabase/supabase-js";

// LET OP: deze client gebruikt de SERVICE ROLE key en omzeilt RLS.
// Uitsluitend server-side gebruiken (server actions) — NOOIT in de browser.
export function createAdminClient() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );
}
