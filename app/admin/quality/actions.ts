"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

// Eigen invulling van een ISO-hoofdstuk bijwerken (werkend document).
export async function updateClause(formData: FormData) {
  const id = String(formData.get("clause_id"));
  const supabase = createClient();
  await supabase
    .from("qms_clauses")
    .update({ pbc_approach: String(formData.get("pbc_approach") || ""), updated_at: new Date().toISOString() })
    .eq("id", id);
  revalidatePath("/admin/quality");
}

// Document toevoegen aan de bibliotheek.
export async function addDocument(formData: FormData) {
  const supabase = createClient();
  await supabase.from("qms_documents").insert({
    title: String(formData.get("title")),
    doc_type: String(formData.get("doc_type") || "") || null,
    reference: String(formData.get("reference") || "") || null,
    clause_number: String(formData.get("clause_number") || "") || null,
  });
  revalidatePath("/admin/quality");
}

// PDF uploaden voor een document.
export async function uploadDocFile(formData: FormData) {
  const docId = String(formData.get("document_id"));
  const file = formData.get("file") as File | null;
  if (!file || file.size === 0) {
    revalidatePath("/admin/quality");
    return;
  }
  const path = `${docId}.pdf`;
  const supabase = createClient();
  const { error } = await supabase.storage
    .from("qms-documents")
    .upload(path, file, { upsert: true, contentType: "application/pdf" });
  if (!error) {
    await supabase.from("qms_documents").update({ file_path: path }).eq("id", docId);
  }
  revalidatePath("/admin/quality");
}
