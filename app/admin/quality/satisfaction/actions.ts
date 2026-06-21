"use server";
import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

function nn(v: FormDataEntryValue | null): string | null {
  const s = String(v ?? "").trim(); return s === "" ? null : s;
}
export async function saveSatisfaction(formData: FormData) {
  const supabase = createClient();
  await supabase.from("qms_satisfaction").insert({
    course_code: nn(formData.get("course_code")),
    period: nn(formData.get("period")),
    survey_date: nn(formData.get("survey_date")),
    respondents: formData.get("respondents") ? Number(formData.get("respondents")) : null,
    avg_score: formData.get("avg_score") ? Number(formData.get("avg_score")) : null,
    comments: nn(formData.get("comments")),
  });
  revalidatePath("/admin/quality/satisfaction");
}
