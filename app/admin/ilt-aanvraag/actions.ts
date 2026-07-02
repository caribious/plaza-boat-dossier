"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

// Storage-key veilig maken: diakrieten/em-dashes/rare tekens eruit
function safeName(name: string) {
  return name
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[—–]/g, "-")
    .replace(/[^a-zA-Z0-9._() -]/g, "_")
    .replace(/\s+/g, " ")
    .trim();
}

export async function uploadIltFile(formData: FormData) {
  const folderId = String(formData.get("folder_id"));
  const courseCode = String(formData.get("course_code"));
  const componentNo = String(formData.get("component_no")).padStart(2, "0");
  const files = formData.getAll("file") as File[];
  const supabase = createClient();

  for (const file of files) {
    if (!file || file.size === 0) continue;
    const name = safeName(file.name);
    const path = `${courseCode}/${componentNo}/${name}`;
    const { error } = await supabase.storage
      .from("ilt-dossier")
      .upload(path, file, { upsert: true, contentType: file.type || "application/pdf" });
    if (!error) {
      // upsert in registratie: zelfde pad niet dubbel tonen
      await supabase.from("ilt_files").delete().eq("file_path", path);
      await supabase.from("ilt_files").insert({ folder_id: folderId, file_name: name, file_path: path });
    }
  }
  revalidatePath("/admin/ilt-aanvraag");
}

export async function deleteIltFile(formData: FormData) {
  const fileId = String(formData.get("file_id"));
  const supabase = createClient();
  const { data: row } = await supabase
    .from("ilt_files")
    .select("id, file_path")
    .eq("id", fileId)
    .single();
  if (row) {
    await supabase.storage.from("ilt-dossier").remove([row.file_path]);
    await supabase.from("ilt_files").delete().eq("id", row.id);
  }
  revalidatePath("/admin/ilt-aanvraag");
}
