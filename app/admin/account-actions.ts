"use server";

import { createAdminClient } from "@/lib/supabase/admin";
import { revalidatePath } from "next/cache";

export type LoginState = {
  status: "idle" | "ok" | "error";
  message?: string;
  email?: string;
  password?: string;
};

// Leesbaar tijdelijk wachtwoord, bv. PBC-7QF2-K9M8
function tempPassword() {
  const part = () => Math.random().toString(36).slice(2, 6).toUpperCase();
  return `PBC-${part()}-${part()}`;
}

// Inlogaccount aanmaken voor een cursist (rol: student).
export async function createStudentLogin(
  _prev: LoginState,
  formData: FormData
): Promise<LoginState> {
  const studentId = String(formData.get("student_id"));
  const email = String(formData.get("email") || "").trim();
  if (!email) return { status: "error", message: "E-mail is verplicht." };

  const admin = createAdminClient();
  const { data: student } = await admin
    .from("students")
    .select("first_name, last_name, profile_id")
    .eq("id", studentId)
    .single();

  if (student?.profile_id) {
    return { status: "error", message: "Deze cursist heeft al een inlog." };
  }

  const password = tempPassword();
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      full_name: `${student?.first_name ?? ""} ${student?.last_name ?? ""}`.trim(),
      role: "student",
    },
  });
  if (error || !data.user) {
    return { status: "error", message: error?.message ?? "Aanmaken mislukt." };
  }

  await admin.from("students").update({ profile_id: data.user.id }).eq("id", studentId);
  revalidatePath(`/admin/students/${studentId}`);
  return { status: "ok", email, password };
}

// Inlogaccount aanmaken voor een instructeur (rol: instructor — volledige rechten).
export async function createInstructorLogin(
  _prev: LoginState,
  formData: FormData
): Promise<LoginState> {
  const instructorId = String(formData.get("instructor_id"));
  const email = String(formData.get("email") || "").trim();
  if (!email) return { status: "error", message: "E-mail is verplicht." };

  const admin = createAdminClient();
  const { data: ins } = await admin
    .from("instructors")
    .select("first_name, last_name, profile_id")
    .eq("id", instructorId)
    .single();

  if (ins?.profile_id) {
    return { status: "error", message: "Deze instructeur heeft al een inlog." };
  }

  const password = tempPassword();
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      full_name: `${ins?.first_name ?? ""} ${ins?.last_name ?? ""}`.trim(),
      role: "instructor",
    },
  });
  if (error || !data.user) {
    return { status: "error", message: error?.message ?? "Aanmaken mislukt." };
  }

  await admin.from("instructors").update({ profile_id: data.user.id }).eq("id", instructorId);
  revalidatePath("/admin/instructors");
  return { status: "ok", email, password };
}
