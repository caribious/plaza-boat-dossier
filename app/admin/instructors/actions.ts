"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

export async function addInstructor(formData: FormData) {
  const supabase = createClient();
  await supabase.from("instructors").insert({
    first_name: String(formData.get("first_name")),
    last_name: String(formData.get("last_name")),
    title: String(formData.get("title") || "") || null,
    email: String(formData.get("email") || "") || null,
    phone: String(formData.get("phone") || "") || null,
    active: true,
  });
  revalidatePath("/admin/instructors");
}

export async function addInstructorCertificate(formData: FormData) {
  const supabase = createClient();
  await supabase.from("instructor_certificates").insert({
    instructor_id: String(formData.get("instructor_id")),
    cert_type: String(formData.get("cert_type")),
    certificate_number: String(formData.get("certificate_number") || "") || null,
    issuing_body: String(formData.get("issuing_body") || "") || null,
    issued_date: String(formData.get("issued_date") || "") || null,
    expiry_date: String(formData.get("expiry_date") || "") || null,
  });
  revalidatePath("/admin/instructors");
}

export async function uploadInstructorCertFile(formData: FormData) {
  const instructorId = String(formData.get("instructor_id"));
  const certId = String(formData.get("certificate_id"));
  const file = formData.get("file") as File | null;
  if (!file || file.size === 0) {
    revalidatePath("/admin/instructors");
    return;
  }
  const path = `${instructorId}/${certId}.pdf`;
  const supabase = createClient();
  const { error } = await supabase.storage
    .from("instructor-certificates")
    .upload(path, file, { upsert: true, contentType: "application/pdf" });
  if (!error) {
    await supabase
      .from("instructor_certificates")
      .update({ file_path: path })
      .eq("id", certId);
  }
  revalidatePath("/admin/instructors");
}
