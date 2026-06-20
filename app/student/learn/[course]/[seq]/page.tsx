import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import {
  findCourseByParam,
  normCode,
  signedContentUrl,
  ModuleRow,
  QuestionRow,
} from "@/lib/learn";
import ModuleTabs from "./ModuleTabs";

export const dynamic = "force-dynamic";

export default async function ModuleDetail({
  params,
}: {
  params: { course: string; seq: string };
}) {
  const supabase = createClient();
  const course = await findCourseByParam(params.course);
  if (!course) notFound();
  const seq = parseInt(params.seq, 10);
  if (Number.isNaN(seq)) notFound();
  const c = normCode(course.code);

  const { data: modData } = await supabase
    .from("modules")
    .select(
      "id, sequence, code, title, required_hours, is_practical, reader_path, deck_path, summary, quiz_ids"
    )
    .eq("course_id", course.id)
    .eq("sequence", seq)
    .maybeSingle();
  const mod = modData as ModuleRow | null;
  if (!mod) notFound();

  // Vragen voor deze module: gecureerde lijst (quiz_ids) of anders alle
  // vragen met dit module_seq.
  let questions: QuestionRow[] = [];
  if (mod.quiz_ids && mod.quiz_ids.length) {
    const { data } = await supabase
      .from("questions")
      .select("id, course_code, module_seq, ref, stem, opts, correct, expl")
      .in("id", mod.quiz_ids);
    const byId: Record<string, QuestionRow> = {};
    for (const q of (data as QuestionRow[]) ?? []) byId[q.id] = q;
    // bewaar de gecureerde volgorde
    questions = mod.quiz_ids.map((id) => byId[id]).filter(Boolean);
  } else {
    const { data } = await supabase
      .from("questions")
      .select("id, course_code, module_seq, ref, stem, opts, correct, expl")
      .eq("module_seq", seq)
      .order("id");
    questions = (data as QuestionRow[]) ?? [];
  }

  const readerUrl = await signedContentUrl(mod.reader_path);
  const deckUrl = await signedContentUrl(mod.deck_path);

  return (
    <>
      <p className="page-sub" style={{ marginBottom: 6 }}>
        <Link href={`/student/learn/${c}`}>← {course.title}</Link>
      </p>
      <h1 className="page-title">
        {mod.code ? `${mod.code} · ` : ""}
        {mod.title}
      </h1>
      <p className="page-sub">
        {questions.length} quizvragen
        {mod.is_practical ? " · praktijkmodule" : ""}
      </p>

      <ModuleTabs
        courseCode={course.code}
        moduleSeq={seq}
        readerUrl={readerUrl}
        deckUrl={deckUrl}
        questions={questions}
      />
    </>
  );
}
