"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

function nn(v: FormDataEntryValue | null): string | null {
  const s = String(v ?? "").trim();
  return s === "" ? null : s;
}

const PREFIX: Record<string, string> = { interne_audit: "IA", directiebeoordeling: "MR" };

async function nextRef(supabase: any, kind: string): Promise<string> {
  const prefix = PREFIX[kind] ?? "RV";
  const year = new Date().getFullYear();
  const { data } = await supabase.from("qms_reviews").select("ref").like("ref", `${prefix}-${year}-%`);
  let max = 0;
  for (const row of (data as any[]) ?? []) {
    const m = String(row.ref ?? "").match(/-(\d+)$/);
    if (m) max = Math.max(max, parseInt(m[1], 10));
  }
  return `${prefix}-${year}-${String(max + 1).padStart(3, "0")}`;
}

// Plannen of bijwerken van een audit/directiebeoordeling.
export async function saveReview(formData: FormData) {
  const supabase = createClient();
  const id = nn(formData.get("id"));
  const kind = String(formData.get("kind") || "interne_audit");
  const payload: Record<string, any> = {
    kind,
    planned_date: nn(formData.get("planned_date")),
    scope: nn(formData.get("scope")),
    owner: nn(formData.get("owner")),
    status: String(formData.get("status") || "gepland"),
  };
  if (id) {
    await supabase.from("qms_reviews").update(payload).eq("id", id);
  } else {
    payload.ref = await nextRef(supabase, kind);
    await supabase.from("qms_reviews").insert(payload);
  }
  revalidatePath("/admin/quality/reviews");
  revalidatePath("/admin/quality/agenda");
}

// Afvinken: uitgevoerd + conclusies vastleggen.
export async function completeReview(formData: FormData) {
  const supabase = createClient();
  const id = String(formData.get("id"));
  await supabase
    .from("qms_reviews")
    .update({
      completed_date: nn(formData.get("completed_date")) ?? new Date().toISOString().slice(0, 10),
      summary: nn(formData.get("summary")),
      status: "afgerond",
    })
    .eq("id", id);
  revalidatePath("/admin/quality/reviews");
  revalidatePath("/admin/quality/agenda");
}
