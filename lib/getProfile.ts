import { createClient } from "@/lib/supabase/server";

export type Role = "admin" | "instructor" | "student" | "auditor";

export interface Profile {
  id: string;
  role: Role;
  full_name: string;
  email: string | null;
}

// Haalt de ingelogde gebruiker + zijn profiel op (server-side).
export async function getProfile(): Promise<Profile | null> {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data } = await supabase
    .from("profiles")
    .select("id, role, full_name, email")
    .eq("id", user.id)
    .single();

  return (data as Profile) ?? null;
}
