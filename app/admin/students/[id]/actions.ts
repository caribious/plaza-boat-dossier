"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

// Module-status bijwerken (RLS staat dit alleen toe voor staff).
export async function updateModuleStatus(formData: FormData) {
  const progressId = String(formData.get("progress_id"));
  const status = String(formData.get("status"));
  const studentId = String(formData.get("student_id"));

  const supabase = createClient();
  await supabase
    .from("module_progress")
    .update({
      status,
      completed_at: status === "completed" ? new Date().toISOString() : null,
      updated_at: new Date().toISOString(),
    })
    .eq("id", progressId);

  revalidatePath(`/admin/students/${studentId}`);
}

// Examenuitslag bijwerken.
export async function updateExamOutcome(formData: FormData) {
  const examId = String(formData.get("exam_id"));
  const outcome = String(formData.get("outcome"));
  const studentId = String(formData.get("student_id"));

  // Bij 'passed': geslaagd deel 1 jaar geldig (SCV Code X/8.3)
  let valid_until: string | null = null;
  if (outcome === "passed") {
    const d = new Date();
    d.setFullYear(d.getFullYear() + 1);
    valid_until = d.toISOString().slice(0, 10);
  }

  const supabase = createClient();
  await supabase
    .from("exam_results")
    .update({ outcome, valid_until })
    .eq("id", examId);

  revalidatePath(`/admin/students/${studentId}`);
}

// Cursistgegevens bijwerken.
export async function updateStudent(formData: FormData) {
  const studentId = String(formData.get("student_id"));
  const supabase = createClient();
  await supabase
    .from("students")
    .update({
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
      updated_at: new Date().toISOString(),
    })
    .eq("id", studentId);
  revalidatePath(`/admin/students/${studentId}`);
}

// Nieuw certificaat toevoegen aan het register.
export async function addCertificate(formData: FormData) {
  const studentId = String(formData.get("student_id"));
  const supabase = createClient();
  await supabase.from("certificates").insert({
    student_id: studentId,
    certificate_number: String(formData.get("certificate_number")),
    title: String(formData.get("title")),
    regulatory_reference: String(formData.get("regulatory_reference") || "") || null,
    issued_date: String(formData.get("issued_date") || "") || null,
    expiry_date: String(formData.get("expiry_date") || "") || null,
  });
  revalidatePath(`/admin/students/${studentId}`);
}

// PDF uploaden voor een bestaand certificaat (naar Supabase Storage).
export async function uploadCertificateFile(formData: FormData) {
  const studentId = String(formData.get("student_id"));
  const certId = String(formData.get("certificate_id"));
  const file = formData.get("file") as File | null;
  if (!file || file.size === 0) {
    revalidatePath(`/admin/students/${studentId}`);
    return;
  }

  const path = `${studentId}/${certId}.pdf`;
  const supabase = createClient();
  const { error } = await supabase.storage
    .from("certificates")
    .upload(path, file, { upsert: true, contentType: "application/pdf" });

  if (!error) {
    await supabase.from("certificates").update({ file_path: path }).eq("id", certId);
  }
  revalidatePath(`/admin/students/${studentId}`);
}
