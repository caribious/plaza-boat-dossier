// Hulpfuncties voor de online cursus (e-learning).
import { createClient } from "@/lib/supabase/server";

// Normaliseert een opleidingscode: 'BM III' == 'BM-III' == 'bm3'.
export function normCode(s: string) {
  return (s || "").toUpperCase().replace(/[\s\-_.]/g, "");
}

export interface CourseRow {
  id: string;
  code: string;
  title: string;
  description: string | null;
}

export interface ModuleRow {
  id: string;
  sequence: number;
  code: string | null;
  title: string;
  required_hours: number | null;
  is_practical: boolean;
  reader_path: string | null;
  deck_path: string | null;
  summary: string | null;
  quiz_ids: string[] | null;
}

export interface QuestionRow {
  id: string;
  course_code: string;
  module_seq: number | null;
  ref: string | null;
  stem: string;
  opts: string[];
  correct: number;
  expl: string | null;
}

// Zoekt een course op via de (genormaliseerde) URL-parameter.
export async function findCourseByParam(param: string): Promise<CourseRow | null> {
  const supabase = createClient();
  const { data } = await supabase.from("courses").select("id, code, title, description");
  const list = (data as CourseRow[]) ?? [];
  const target = normCode(decodeURIComponent(param));
  return list.find((c) => normCode(c.code) === target) ?? null;
}

// Het cursistdossier (students-rij) van de ingelogde gebruiker (via RLS).
export async function getMyStudent() {
  const supabase = createClient();
  const { data } = await supabase.from("students").select("id, first_name, student_number").maybeSingle();
  return data as { id: string; first_name: string; student_number: string } | null;
}

// Signed URL voor een bestand in de course-content bucket (1 uur geldig).
export async function signedContentUrl(path: string | null): Promise<string | null> {
  if (!path) return null;
  const supabase = createClient();
  const { data } = await supabase.storage.from("course-content").createSignedUrl(path, 3600);
  return data?.signedUrl ?? null;
}
