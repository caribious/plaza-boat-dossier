import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { normCode } from "@/lib/learn";
import { fmtDate } from "@/lib/format";
import { t } from "@/lib/i18n";

export const dynamic = "force-dynamic";

// Beheerpagina "Examens" — vragenbank-overzicht per opleiding + toetsresultaten
// per cursist. Valt onder /admin/* en is dus staff-gated via app/admin/layout.tsx
// (cursist -> /student, auditor -> /ilt). De questions-tabel met juiste
// antwoorden wordt hier alleen door staff geladen; deze route is nooit voor
// cursisten bereikbaar.
export default async function AdminExamsPage() {
  const T = t();
  const supabase = createClient();

  // Opleidingen + modulestructuur (voor titels + aantallen)
  const { data: coursesData } = await supabase
    .from("courses")
    .select("id, code, title, modules ( sequence, title )")
    .order("code");
  const courses = (coursesData as any[]) ?? [];

  // Alle vragen (alleen tel-velden): course_code + module_seq.
  const { data: qData } = await supabase
    .from("questions")
    .select("course_code, module_seq");
  const questions = (qData as { course_code: string; module_seq: number | null }[]) ?? [];

  // Toetsresultaten (pogingen). Student-naam erbij via relatie.
  const { data: aData } = await supabase
    .from("quiz_attempts")
    .select(
      `id, course_code, module_seq, kind, score, max, passed, created_at,
       students ( first_name, last_name, student_number )`
    )
    .order("created_at", { ascending: false });
  const attempts = (aData as any[]) ?? [];

  // Tel vragen per opleiding (genormaliseerde code) en per module.
  const qByCourse = new Map<string, number>();
  const qByCourseModule = new Map<string, Map<string | number, number>>();
  for (const q of questions) {
    const key = normCode(q.course_code);
    qByCourse.set(key, (qByCourse.get(key) ?? 0) + 1);
    if (!qByCourseModule.has(key)) qByCourseModule.set(key, new Map());
    const mk = q.module_seq ?? "none";
    const inner = qByCourseModule.get(key)!;
    inner.set(mk, (inner.get(mk) ?? 0) + 1);
  }

  return (
    <>
      <h1 className="page-title">{T.ex_title}</h1>
      <p className="page-sub">{T.ex_sub}</p>

      {/* Vragenbank-overzicht per opleiding */}
      <div className="card">
        <h2>{T.ex_bank_title}</h2>
        <p className="muted small" style={{ marginTop: -8 }}>{T.ex_bank_sub}</p>

        {courses.length === 0 ? (
          <p className="muted small">{T.ex_no_courses}</p>
        ) : (
          courses.map((c) => {
            const ckey = normCode(c.code);
            const total = qByCourse.get(ckey) ?? 0;
            const mods = (c.modules ?? [])
              .slice()
              .sort((a: any, b: any) => a.sequence - b.sequence);
            const moduleCounts = qByCourseModule.get(ckey);
            return (
              <div
                key={c.id}
                style={{ padding: "12px 0", borderTop: "1px solid var(--line)" }}
              >
                <div
                  style={{
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "baseline",
                    gap: 12,
                  }}
                >
                  <strong>
                    {c.code} — {c.title}
                  </strong>
                  <span className="muted small">
                    {total} {T.ex_questions} · {mods.length} {T.ex_modules}
                  </span>
                </div>

                {total === 0 ? (
                  <p className="muted small" style={{ margin: "6px 0 0" }}>
                    {T.ex_no_questions}
                  </p>
                ) : (
                  <>
                    <table style={{ marginTop: 8 }}>
                      <thead>
                        <tr>
                          <th>#</th>
                          <th>{T.ex_module}</th>
                          <th>{T.ex_questions}</th>
                        </tr>
                      </thead>
                      <tbody>
                        {mods.map((m: any) => (
                          <tr key={m.sequence}>
                            <td className="muted small">{m.sequence}</td>
                            <td>{m.title}</td>
                            <td className="muted small">
                              {moduleCounts?.get(m.sequence) ?? 0}
                            </td>
                          </tr>
                        ))}
                        {moduleCounts?.get("none") ? (
                          <tr>
                            <td className="muted small">—</td>
                            <td className="muted small">{T.ex_module_none}</td>
                            <td className="muted small">{moduleCounts.get("none")}</td>
                          </tr>
                        ) : null}
                      </tbody>
                    </table>
                    <p className="small" style={{ marginTop: 8 }}>
                      <Link href={`/admin/exams/${ckey}`}>{T.ex_open_bank} →</Link>
                    </p>
                  </>
                )}
              </div>
            );
          })
        )}
      </div>

      {/* Toetsresultaten per cursist */}
      <div className="card">
        <h2>{T.ex_results_title}</h2>
        <p className="muted small" style={{ marginTop: -8 }}>{T.ex_results_sub}</p>
        <table>
          <thead>
            <tr>
              <th>{T.ex_col_student}</th>
              <th>{T.course}</th>
              <th>{T.ex_col_kind}</th>
              <th>{T.ex_col_module}</th>
              <th>{T.ex_col_score}</th>
              <th>{T.ex_col_result}</th>
              <th>{T.ex_col_when}</th>
            </tr>
          </thead>
          <tbody>
            {attempts.length === 0 ? (
              <tr>
                <td colSpan={7} className="muted small">{T.ex_results_none}</td>
              </tr>
            ) : (
              attempts.map((a) => {
                const s = a.students;
                const name = s
                  ? `${s.last_name}, ${s.first_name}`
                  : "—";
                const modLabel =
                  a.kind === "mock"
                    ? T.ex_mock_full
                    : a.module_seq != null
                    ? `${T.ex_module} ${a.module_seq}`
                    : "—";
                return (
                  <tr key={a.id}>
                    <td>
                      {name}
                      {s?.student_number ? (
                        <span className="muted small"> · {s.student_number}</span>
                      ) : null}
                    </td>
                    <td className="muted small">{a.course_code}</td>
                    <td className="small">
                      {a.kind === "mock" ? T.ex_kind_mock : T.ex_kind_quiz}
                    </td>
                    <td className="muted small">{modLabel}</td>
                    <td className="small">
                      {a.score}/{a.max}
                    </td>
                    <td>
                      <span className={`badge ${a.passed ? "ok" : "warn"}`}>
                        {a.passed ? T.ex_passed : T.ex_failed}
                      </span>
                    </td>
                    <td className="muted small">{fmtDate(a.created_at)}</td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
