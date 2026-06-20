import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { findCourseByParam, normCode, ModuleRow } from "@/lib/learn";
import { progressBadge } from "@/lib/format";

export const dynamic = "force-dynamic";

export default async function CoursePage({ params }: { params: { course: string } }) {
  const supabase = createClient();
  const course = await findCourseByParam(params.course);
  if (!course) notFound();

  const c = normCode(course.code);

  // Modules van de opleiding.
  const { data: modData } = await supabase
    .from("modules")
    .select(
      "id, sequence, code, title, required_hours, is_practical, reader_path, deck_path, summary, quiz_ids"
    )
    .eq("course_id", course.id)
    .order("sequence");
  const modules = (modData as ModuleRow[]) ?? [];

  // Mijn inschrijving + voortgang voor deze opleiding.
  const { data: enr } = await supabase
    .from("enrollments")
    .select("id")
    .eq("course_id", course.id)
    .maybeSingle();

  const progressByModule: Record<string, string> = {};
  if (enr) {
    const { data: prog } = await supabase
      .from("module_progress")
      .select("module_id, status")
      .eq("enrollment_id", (enr as any).id);
    for (const p of (prog as any[]) ?? []) progressByModule[p.module_id] = p.status;
  }

  // Beste quizscore per module (uit quiz_attempts).
  const { data: attempts } = await supabase
    .from("quiz_attempts")
    .select("module_seq, score, max, kind")
    .eq("course_code", course.code)
    .eq("kind", "quiz");
  const bestBySeq: Record<number, { score: number; max: number }> = {};
  for (const a of (attempts as any[]) ?? []) {
    if (a.module_seq == null) continue;
    const cur = bestBySeq[a.module_seq];
    if (!cur || a.score > cur.score) bestBySeq[a.module_seq] = { score: a.score, max: a.max };
  }

  const done = modules.filter((m) => progressByModule[m.id] === "completed").length;
  const pct = modules.length ? Math.round((done / modules.length) * 100) : 0;

  return (
    <>
      <p className="page-sub" style={{ marginBottom: 6 }}>
        <Link href="/student/learn">← Mijn cursus</Link>
      </p>
      <h1 className="page-title">{course.title}</h1>
      <p className="page-sub">{course.description}</p>

      <div className="card">
        <h2>Voortgang</h2>
        <div className="progress-wrap" style={{ maxWidth: 360 }}>
          <div className="progress-bar" style={{ width: `${pct}%` }} />
        </div>
        <p className="muted small">
          {done} van {modules.length} modules afgerond ({pct}%).
        </p>
        <Link className="btn" href={`/student/learn/${c}/exam`}>
          Start oefenexamen (50 vragen)
        </Link>
      </div>

      <div className="card">
        <h2>Modules</h2>
        <table>
          <thead>
            <tr>
              <th>Module</th>
              <th>Quizscore</th>
              <th>Status</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {modules.map((m) => {
              const b = progressBadge(progressByModule[m.id] ?? "not_started");
              const best = bestBySeq[m.sequence];
              return (
                <tr key={m.id}>
                  <td>
                    <Link href={`/student/learn/${c}/${m.sequence}`}>
                      {m.code ? `${m.code} · ` : ""}
                      {m.title}
                    </Link>
                    {m.is_practical && (
                      <span className="muted small"> · praktijk</span>
                    )}
                  </td>
                  <td className="muted small">
                    {best ? `${best.score}/${best.max}` : "—"}
                  </td>
                  <td>
                    <span className={`badge ${b.cls}`}>{b.label}</span>
                  </td>
                  <td>
                    <Link className="small" href={`/student/learn/${c}/${m.sequence}`}>
                      Openen
                    </Link>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </>
  );
}
