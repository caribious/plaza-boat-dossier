import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { findCourseByParam, normCode, QuestionRow } from "@/lib/learn";
import MockExam from "./MockExam";

export const dynamic = "force-dynamic";

const EXAM_SIZE = 50;

export default async function ExamPage({ params }: { params: { course: string } }) {
  const supabase = createClient();
  const course = await findCourseByParam(params.course);
  if (!course) notFound();
  const c = normCode(course.code);

  // Alle BM III-vragen ophalen en willekeurig 50 selecteren (server-side).
  const { data } = await supabase
    .from("questions")
    .select("id, course_code, module_seq, ref, stem, opts, correct, expl")
    .eq("course_code", course.code);
  const all = (data as QuestionRow[]) ?? [];

  // Fisher-Yates shuffle
  const pool = [...all];
  for (let i = pool.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [pool[i], pool[j]] = [pool[j], pool[i]];
  }
  const selected = pool.slice(0, Math.min(EXAM_SIZE, pool.length));

  return (
    <>
      <p className="page-sub" style={{ marginBottom: 6 }}>
        <Link href={`/student/learn/${c}`}>← {course.title}</Link>
      </p>
      <h1 className="page-title">Oefenexamen — {course.code}</h1>
      <p className="page-sub">
        {selected.length} vragen · 60 minuten · slagen vanaf 35/50 (70%). Het resultaat
        wordt in je dossier vastgelegd als kennistoets-oefenexamen.
      </p>

      {selected.length === 0 ? (
        <div className="card">
          <p className="muted small">
            Er zijn nog geen vragen geladen voor deze opleiding. Vraag de administratie om de
            vragenbank te seeden.
          </p>
        </div>
      ) : (
        <MockExam courseCode={course.code} questions={selected} durationMin={60} passMark={35} />
      )}
    </>
  );
}
