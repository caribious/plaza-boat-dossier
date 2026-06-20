"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

// Lege string -> null (voor optionele velden / datums).
function nn(v: FormDataEntryValue | null): string | null {
  const s = String(v ?? "").trim();
  return s === "" ? null : s;
}

// Numeriek of null.
function ni(v: FormDataEntryValue | null): number | null {
  const s = String(v ?? "").trim();
  if (s === "") return null;
  const n = parseInt(s, 10);
  return Number.isNaN(n) ? null : n;
}

// Genereer het volgende referentienummer, bv. RIS-2026-001.
async function nextRef(supabase: any): Promise<string> {
  const year = new Date().getFullYear();
  const like = `RIS-${year}-%`;
  const { data } = await supabase.from("qms_risks").select("ref").like("ref", like);
  let max = 0;
  for (const row of (data as any[]) ?? []) {
    const m = String(row.ref ?? "").match(/-(\d+)$/);
    if (m) max = Math.max(max, parseInt(m[1], 10));
  }
  const seq = String(max + 1).padStart(3, "0");
  return `RIS-${year}-${seq}`;
}

// --- RISICO opslaan (insert/update) --------------------------------
export async function saveRisk(formData: FormData) {
  const supabase = createClient();
  const id = nn(formData.get("id"));

  const likelihood = ni(formData.get("likelihood"));
  const impact = ni(formData.get("impact"));
  const score =
    likelihood !== null && impact !== null ? likelihood * impact : null;

  const payload: Record<string, any> = {
    raised_date: nn(formData.get("raised_date")),
    context: nn(formData.get("context")),
    course_code: nn(formData.get("course_code")),
    description: nn(formData.get("description")),
    category: nn(formData.get("category")),
    likelihood,
    impact,
    score,
    response: nn(formData.get("response")),
    action: nn(formData.get("action")),
    owner: nn(formData.get("owner")),
    due_date: nn(formData.get("due_date")),
    status: String(formData.get("status") || "open"),
    closed_date: nn(formData.get("closed_date")),
  };

  if (id) {
    await supabase.from("qms_risks").update(payload).eq("id", id);
  } else {
    payload.ref = await nextRef(supabase);
    await supabase.from("qms_risks").insert(payload);
  }
  revalidatePath("/admin/quality/registers/risks");
}
