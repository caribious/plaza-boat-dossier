"use server";

import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { sendInviteEmail } from "@/lib/email";
import { headers } from "next/headers";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

export async function createStudent(formData: FormData) {
  const supabase = createClient();

  // Cursistnummer automatisch genereren: PBC-<jaar>-<volgnr>
  const { count } = await supabase
    .from("students")
    .select("*", { count: "exact", head: true });
  const year = new Date().getFullYear();
  const studentNumber = `PBC-${year}-${String((count ?? 0) + 1).padStart(4, "0")}`;

  const firstName = String(formData.get("first_name"));
  const lastName = String(formData.get("last_name"));
  const email = String(formData.get("email") || "").trim();

  const { data: student, error } = await supabase
    .from("students")
    .insert({
      student_number: studentNumber,
      first_name: firstName,
      last_name: lastName,
      date_of_birth: String(formData.get("date_of_birth")),
      place_of_birth: String(formData.get("place_of_birth") || "") || null,
      email: email || null,
      phone: String(formData.get("phone") || "") || null,
      nationality: String(formData.get("nationality") || "") || null,
      address: String(formData.get("address") || "") || null,
      rya_number: String(formData.get("rya_number") || "") || null,
      identity_verified: formData.get("identity_verified") === "on",
      id_document_type: String(formData.get("id_document_type") || "") || null,
    })
    .select("id")
    .single();

  if (error || !student) {
    throw new Error("Aanmaken cursist mislukt: " + (error?.message ?? ""));
  }

  // Optioneel direct inschrijven op een opleiding + modulevoortgang aanmaken.
  // Cascade: een hogere graad omvat de lagere. BM-I → I+II+III, BM-II → II+III, BM-III → III.
  const courseId = String(formData.get("course_id") || "");
  if (courseId) {
    const CASCADE: Record<string, string[]> = {
      "BM-III": ["BM-III"],
      "BM-II": ["BM-III", "BM-II"],
      "BM-I": ["BM-III", "BM-II", "BM-I"],
    };
    const { data: allCourses } = await supabase.from("courses").select("id, code");
    const codeById = new Map((allCourses ?? []).map((c: any) => [c.id, c.code]));
    const idByCode = new Map((allCourses ?? []).map((c: any) => [c.code, c.id]));
    const chosenCode = codeById.get(courseId);
    // Lagere graden eerst aanmaken, gekozen (hoogste) graad als laatste → die is de "primaire" inschrijving.
    const codes = (chosenCode && CASCADE[chosenCode]) || (chosenCode ? [chosenCode] : []);

    for (const code of codes) {
      const cid = idByCode.get(code);
      if (!cid) continue;
      const { data: enrollment } = await supabase
        .from("enrollments")
        .insert({
          student_id: student.id,
          course_id: cid,
          status: "enrolled",
          start_date: new Date().toISOString().slice(0, 10),
        })
        .select("id")
        .single();

      if (enrollment) {
        const { data: modules } = await supabase
          .from("modules")
          .select("id")
          .eq("course_id", cid);
        if (modules && modules.length) {
          await supabase.from("module_progress").insert(
            modules.map((m: any) => ({
              enrollment_id: enrollment.id,
              module_id: m.id,
              status: "not_started",
            }))
          );
        }
      }
    }
  }

  // Optioneel: direct een e-mailuitnodiging sturen en de inlog aan dit dossier koppelen.
  let invite = "";
  if (formData.get("send_invite") === "on") {
    if (!email) {
      invite = "fail:Vul een e-mailadres in om te kunnen uitnodigen.";
    } else {
      const admin = createAdminClient();
      const h = headers();
      const proto = h.get("x-forwarded-proto") ?? "https";
      const host = h.get("host");
      const origin = host ? `${proto}://${host}` : "";
      const redirectTo = origin ? `${origin}/auth/callback?next=/reset-password` : undefined;
      const fullName = `${firstName} ${lastName}`.trim();

      const { data: linkData, error: linkErr } = await admin.auth.admin.generateLink({
        type: "invite",
        email,
        options: { data: { full_name: fullName, role: "student" }, redirectTo },
      });
      if (linkErr) {
        invite = "fail:" + linkErr.message;
      } else {
        const userId = linkData.user?.id;
        if (userId) {
          await admin.from("students").update({ profile_id: userId }).eq("id", student.id);
        }
        const link = linkData.properties?.action_link;
        if (!link) {
          invite = "fail:Kon geen activatielink genereren.";
        } else {
          const sent = await sendInviteEmail(email, fullName, link, "student");
          invite = sent.ok ? "ok" : "fail:" + sent.error;
        }
      }
    }
  }

  revalidatePath("/admin");
  redirect(`/admin/students/${student.id}${invite ? `?invite=${encodeURIComponent(invite)}` : ""}`);
}
