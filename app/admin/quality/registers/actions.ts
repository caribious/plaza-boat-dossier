"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

// Mapping register -> tabel + ref-prefix
const TABLES = {
  incidents: { table: "qms_incidents", prefix: "INC" },
  complaints: { table: "qms_complaints", prefix: "KL" },
  improvements: { table: "qms_improvements", prefix: "VB" },
} as const;

type RegisterKey = keyof typeof TABLES;

// Lege string -> null (voor optionele velden / datums).
function nn(v: FormDataEntryValue | null): string | null {
  const s = String(v ?? "").trim();
  return s === "" ? null : s;
}

// Genereer het volgende referentienummer, bv. INC-2026-001.
// Server-side: telt bestaande rijen van dit kalenderjaar voor dit register.
async function nextRef(supabase: any, register: RegisterKey): Promise<string> {
  const { table, prefix } = TABLES[register];
  const year = new Date().getFullYear();
  const like = `${prefix}-${year}-%`;
  const { data } = await supabase.from(table).select("ref").like("ref", like);
  let max = 0;
  for (const row of (data as any[]) ?? []) {
    const m = String(row.ref ?? "").match(/-(\d+)$/);
    if (m) max = Math.max(max, parseInt(m[1], 10));
  }
  const seq = String(max + 1).padStart(3, "0");
  return `${prefix}-${year}-${seq}`;
}

// --- INCIDENTEN / BIJNA-ONGEVALLEN ---------------------------------
export async function saveIncident(formData: FormData) {
  const supabase = createClient();
  const id = nn(formData.get("id"));
  const payload: Record<string, any> = {
    kind: String(formData.get("kind") || "ongeval"),
    report_date: nn(formData.get("report_date")),
    reporter_name: nn(formData.get("reporter_name")),
    course_code: nn(formData.get("course_code")),
    location: nn(formData.get("location")),
    description: nn(formData.get("description")),
    severity: nn(formData.get("severity")),
    immediate_action: nn(formData.get("immediate_action")),
    root_cause: nn(formData.get("root_cause")),
    corrective_action: nn(formData.get("corrective_action")),
    owner: nn(formData.get("owner")),
    due_date: nn(formData.get("due_date")),
    status: String(formData.get("status") || "open"),
    closed_date: nn(formData.get("closed_date")),
  };
  if (id) {
    await supabase.from("qms_incidents").update(payload).eq("id", id);
  } else {
    payload.ref = await nextRef(supabase, "incidents");
    await supabase.from("qms_incidents").insert(payload);
  }
  revalidatePath("/admin/quality/registers");
}

// --- KLACHTEN ------------------------------------------------------
export async function saveComplaint(formData: FormData) {
  const supabase = createClient();
  const id = nn(formData.get("id"));
  const payload: Record<string, any> = {
    report_date: nn(formData.get("report_date")),
    complainant: nn(formData.get("complainant")),
    course_code: nn(formData.get("course_code")),
    channel: nn(formData.get("channel")),
    description: nn(formData.get("description")),
    category: nn(formData.get("category")),
    action: nn(formData.get("action")),
    owner: nn(formData.get("owner")),
    due_date: nn(formData.get("due_date")),
    status: String(formData.get("status") || "open"),
    closed_date: nn(formData.get("closed_date")),
  };
  if (id) {
    await supabase.from("qms_complaints").update(payload).eq("id", id);
  } else {
    payload.ref = await nextRef(supabase, "complaints");
    await supabase.from("qms_complaints").insert(payload);
  }
  revalidatePath("/admin/quality/registers");
}

// --- VERBETERINGEN (CAPA) ------------------------------------------
export async function saveImprovement(formData: FormData) {
  const supabase = createClient();
  const id = nn(formData.get("id"));
  const payload: Record<string, any> = {
    raised_date: nn(formData.get("raised_date")),
    source: nn(formData.get("source")),
    course_code: nn(formData.get("course_code")),
    description: nn(formData.get("description")),
    type: nn(formData.get("type")),
    action: nn(formData.get("action")),
    owner: nn(formData.get("owner")),
    due_date: nn(formData.get("due_date")),
    status: String(formData.get("status") || "open"),
    effectiveness_check: nn(formData.get("effectiveness_check")),
    closed_date: nn(formData.get("closed_date")),
  };
  if (id) {
    await supabase.from("qms_improvements").update(payload).eq("id", id);
  } else {
    payload.ref = await nextRef(supabase, "improvements");
    await supabase.from("qms_improvements").insert(payload);
  }
  revalidatePath("/admin/quality/registers");
}
