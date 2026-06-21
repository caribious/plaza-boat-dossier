import Link from "next/link";
import { notFound } from "next/navigation";
import { createAdminClient } from "@/lib/supabase/admin";
import { findCourseByParam, normCode, ModuleRow, QuestionRow } from "@/lib/learn";
import { t } from "@/lib/i18n";
import ModuleTabs from "@/components/ModuleTabs";

export const dynamic = "force-dynamic";

async function adminSignedUrl(path: string | null) {
  if (!path) return null;
  const admin = createAdminClient();
  const { data } = await admin.storage.from("course-content").createSignedUrl(path, 3600);
  return data?.signedUrl ?? null;
}

export default async function AdminModuleDetail({ params }: { params: { course: string; seq: string } }) {
  const T = t();
  const course = await findCourseByParam(params.course);
  if (!course) notFound();
  const seq = parseInt(params.seq, 10);
  if (Number.isNaN(seq)) notFound();

  const admin = createAdminClient();
  const { data: modData } = await admin
    .from("modules")
    .select("id, sequence, code, title, required_hours, is_practical, reader_path, deck_path, summary, quiz_ids")
    .eq("course_id", course.id)
    .eq("sequence", seq)
    .maybeSingle();
  const mod = modData as ModuleRow | null;
  if (!mod) notFound();

  let questions: QuestionRow[] = [];
  if (mod.quiz_ids && mod.quiz_ids.length) {
    const { data } = await admin.from("questions")
      .select("id, course_code, module_seq, ref, stem, opts, correct, expl").in("id", mod.quiz_ids);
    const byId: Record<string, QuestionRow> = {};
    for (const q of (data as QuestionRow[]) ?? []) byId[q.id] = q;
    questions = mod.quiz_ids.map((id) => byId[id]).filter(Boolean);
  } else {
    const { data } = await admin.from("questions")
      .select("id, course_code, module_seq, ref, stem, opts, correct, expl").eq("module_seq", seq).order("id");
    questions = (data as QuestionRow[]) ?? [];
  }

  const readerUrl = await adminSignedUrl(mod.reader_path);
  const deckUrl = await adminSignedUrl(mod.deck_path);

  return (
    <>
      <p className="page-sub" style={{ marginBottom: 6 }}>
        <Link href="/admin/content">← {T.iln_content}</Link>
      </p>
      <h1 className="page-title">{mod.code ? `${mod.code} · ` : ""}{mod.title}</h1>
      <p className="page-sub">
        {course.code} — {course.title} · {questions.length} quizvragen{mod.is_practical ? " · praktijkmodule" : ""}
      </p>
      <ModuleTabs courseCode={course.code} moduleSeq={seq} readerUrl={readerUrl} deckUrl={deckUrl} questions={questions} preview />
    </>
  );
}
