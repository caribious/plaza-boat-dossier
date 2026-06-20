"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";
import { normCode } from "@/lib/learn";

export interface AttemptAnswer {
  id: string;
  chosen: number;
  correct: number;
}

// Module afronden + quizpoging opslaan (via SECURITY DEFINER RPC, RLS-veilig).
export async function recordModuleQuiz(input: {
  courseCode: string;
  moduleSeq: number;
  score: number;
  max: number;
  passed: boolean;
  answers: AttemptAnswer[];
}): Promise<{ ok: boolean; error?: string }> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("record_module_quiz", {
    p_course_code: input.courseCode,
    p_module_sequence: input.moduleSeq,
    p_score: input.score,
    p_max: input.max,
    p_passed: input.passed,
    p_answers: input.answers,
  });
  if (error) return { ok: false, error: error.message };
  const res = data as { ok: boolean; error?: string } | null;
  if (res && res.ok === false) return { ok: false, error: res.error };

  const c = normCode(input.courseCode);
  revalidatePath(`/student/learn/${c}`);
  revalidatePath(`/student/learn/${c}/${input.moduleSeq}`);
  revalidatePath(`/student`);
  return { ok: true };
}

// Mock-examen opslaan (exam_results + quiz_attempt) via RPC.
export async function recordMockExam(input: {
  courseCode: string;
  score: number;
  max: number;
  passed: boolean;
  answers: AttemptAnswer[];
}): Promise<{ ok: boolean; error?: string; outcome?: string }> {
  const supabase = createClient();
  const { data, error } = await supabase.rpc("record_mock_exam", {
    p_course_code: input.courseCode,
    p_score: input.score,
    p_max: input.max,
    p_passed: input.passed,
    p_answers: input.answers,
  });
  if (error) return { ok: false, error: error.message };
  const res = data as { ok: boolean; error?: string; outcome?: string } | null;
  if (res && res.ok === false) return { ok: false, error: res.error };

  const c = normCode(input.courseCode);
  revalidatePath(`/student/learn/${c}`);
  revalidatePath(`/student`);
  return { ok: true, outcome: res?.outcome };
}
