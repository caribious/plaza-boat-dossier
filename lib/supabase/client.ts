import { createBrowserClient } from "@supabase/ssr";

// Supabase-client voor gebruik in de browser (client components).
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
