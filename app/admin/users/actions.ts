"use server";
import { createAdminClient } from "@/lib/supabase/admin";
import { resendConfigured, sendInviteEmail } from "@/lib/email";
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
  // Uitnodigings-/herstellinks leveren de sessie als hash-fragment (implicit flow);
  // die verwerkt de client op /reset-password (detectSessionInUrl), niet de server-callback.
  const redirectTo = origin ? `${origin}/reset-password` : undefined;

  const admin = createAdminClient();

  // Met Resend: zelf de activatielink genereren en via onze eigen mailer sturen.
  if (resendConfigured()) {
    const { data, error } = await admin.auth.admin.generateLink({
      type: "invite",
      email,
      options: { data: { full_name, role }, redirectTo },
    });
    if (error) return { status: "error", message: error.message };
    const link = data.properties?.action_link;
    if (!link) return { status: "error", message: "Kon geen activatielink genereren." };
    const sent = await sendInviteEmail(email, full_name, link, role);
    if (!sent.ok) return { status: "error", message: `Versturen mislukt (${sent.error}).` };
    revalidatePath("/admin/users");
    return { status: "ok", email };
  }

  // Terugval: Supabase's ingebouwde mailer (vereist SMTP in Supabase Auth).
  const { error } = await admin.auth.admin.inviteUserByEmail(email, {
    data: { full_name, role },
    redirectTo,
  });
  if (error) return { status: "error", message: error.message };
  revalidatePath("/admin/users");
  return { status: "ok", email };
}

export type CreateState = { status: "idle" | "ok" | "error"; message?: string; email?: string; password?: string };

function tempPassword() {
  const part = () => Math.random().toString(36).slice(2, 6).toUpperCase();
  return `PBC-${part()}-${part()}`;
}

// Account direct aanmaken met een tijdelijk wachtwoord (geen e-mail).
export async function createUserWithPassword(_prev: CreateState, formData: FormData): Promise<CreateState> {
  const email = String(formData.get("email") || "").trim();
  const full_name = String(formData.get("full_name") || "").trim();
  const role = String(formData.get("role") || "student");
  const customPw = String(formData.get("password") || "").trim();
  if (!email) return { status: "error", message: "E-mail is verplicht." };
  const admin = createAdminClient();
  const password = customPw.length >= 6 ? customPw : tempPassword();
  const { data, error } = await admin.auth.admin.createUser({
    email, password, email_confirm: true,
    user_metadata: { full_name, role },
  });
  if (error || !data.user) return { status: "error", message: error?.message ?? "Aanmaken mislukt." };
  revalidatePath("/admin/users");
  return { status: "ok", email, password };
}
