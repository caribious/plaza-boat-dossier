"use server";

import { createClient } from "@/lib/supabase/server";
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

  const { data: student, error } = await supabase
    .from("students")
    .insert({
      student_number: studentNumber,
      first_name: String(formData.get("first_name")),
      last_name: String(formData.get("last_name")),
      date_of_birth: String(formData.get("date_of_birth")),
      place_of_birth: String(formData.get("place_of_birth") || "") || null,
      email: String(formData.get("email") || "") || null,
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

  // Optioneel direct inschrijven op een opleiding + modulevoortgang aanmaken
  const courseId = String(formData.get("course_id") || "");
  if (courseId) {
    const { data: enrollment } = await supabase
      .from("enrollments")
      .insert({
        student_id: student.id,
        course_id: courseId,
        status: "enrolled",
        start_date: new Date().toISOString().slice(0, 10),
      })
      .select("id")
      .single();

    if (enrollment) {
      const { data: modules } = await supabase
        .from("modules")
        .select("id")
        .eq("course_id", courseId);
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

  revalidatePath("/admin");
  redirect(`/admin/students/${student.id}`);
}
