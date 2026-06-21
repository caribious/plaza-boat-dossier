"use server";
import { createAdminClient } from "@/lib/supabase/admin";
import { headers } from "next/headers";
import { revalidatePath } from "next/cache";

export type InviteState = { status: "idle" | "ok" | "error"; message?: string; email?: string };

export async function inviteUser(_prev: InviteState, formData: FormData): Promise<InviteState> {
  const email = String(formData.get("email") || "").trim();
  const full_name = String(formData.get("full_name") || "").trim();
  const role = String(formData.get("role") || "student");
  if (!email) return { status: "error", message: "E-mail is verplicht." };

  const h = headers();
  const proto = h.get("x-forwarded-proto") ?? "https";
  const host = h.get("host");
  const origin = host ? `${proto}://${host}` : "";
  const redirectTo = origin ? `${origin}/auth/callback?next=/reset-password` : undefined;

  const admin = createAdminClient();
  const { error } = await admin.auth.admin.inviteUserByEmail(email, {
    data: { full_name, role },
    redirectTo,
  });
  if (error) return { status: "error", message: error.message };
  revalidatePath("/admin/users");
  return { status: "ok", email };
}
