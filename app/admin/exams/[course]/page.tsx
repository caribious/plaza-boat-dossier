import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { findCourseByParam, normCode, QuestionRow } from "@/lib/learn";
import { t } from "@/lib/i18n";

export const dynamic = "force-dynamic";

// Vragenbank-detail per opleiding (beheer/ILT). Toont elke vraag met de
// antwoordopties, het JUISTE antwoord duidelijk gemarkeerd en de toelichting.
// Gegroepeerd per module. Staff-gated via app/admin/layout.tsx.
//
// LET OP: deze route hoort uitsluitend onder /admin/* — de juiste antwoorden
// mogen nooit in een cursist-route lekken. De cursist ziet correct/expl pas
// NA het inleveren van de quiz (MockExam.tsx). Hier is dat altijd zichtbaar.
export default async function AdminExamBankPage({
  params,
}: {
  params: { course: string };
}) {
  const T = t();
  const supabase = createClient();
  const course = await findCourseByParam(params.course);
  if (!course) notFound();
  const c = normCode(course.code);

  // Modulestructuur (voor de groepskoppen + volgorde)
  const { data: modData } = await supabase
    .from("modules")
    .select("sequence, title, course_id, courses!inner ( code )")
    .eq("courses.code", course.code)
    .order("sequence");
  const modules = (modData as any[]) ?? [];
  const moduleTitle = new Map<number, string>();
  for (const m of modules) moduleTitle.set(m.sequence, m.title);

  // Alle vragen voor deze opleiding — exact dezelfde datavorm als het
  // cursist-oefenexamen (id, opts, correct, expl, module_seq, ref).
  const { data: qData } = await supabase
    .from("questions")
    .select("id, course_code, module_seq, ref, stem, opts, correct, expl")
    .eq("course_code", course.code)
    .order("module_seq", { ascending: true })
    .order("id", { ascending: true });
  const all = (qData as QuestionRow[]) ?? [];

  // Groepeer per module_seq (null -> "none").
  const byModule = new Map<string | number, QuestionRow[]>();
  for (const q of all) {
    const key = q.module_seq ?? "none";
    if (!byModule.has(key)) byModule.set(key, []);
    byModule.get(key)!.push(q);
  }

  // Stabiele, gesorteerde groepsvolgorde: eerst genummerde modules, dan "none".
  const numericKeys = [...byModule.keys()]
    .filter((k): k is number => typeof k === "number")
    .sort((a, b) => a - b);
  const groupKeys: (string | number)[] = [...numericKeys];
  if (byModule.has("none")) groupKeys.push("none");

  return (
    <>
      <p className="page-sub" style={{ marginBottom: 6 }}>
        <Link href="/admin/exams">{T.ex_back_to_overview}</Link>
      </p>
      <h1 className="page-title">
        {T.ex_bank_for} {course.code}
      </h1>
      <p className="page-sub">{course.title}</p>

      {all.length === 0 ? (
        <div className="card">
          <p className="muted small">{T.ex_no_questions}</p>
        </div>
      ) : (
        groupKeys.map((key) => {
          const list = byModule.get(key)!;
          const heading =
            key === "none"
              ? T.ex_module_none
              : `${T.ex_module} ${key}${
                  moduleTitle.get(key as number)
                    ? " — " + moduleTitle.get(key as number)
                    : ""
                }`;
          return (
            <div className="card" key={String(key)}>
              <h2>{heading}</h2>
              <p className="muted small" style={{ marginTop: -8 }}>
                {list.length} {T.ex_q_count_in_module}
              </p>

              {list.map((q, qi) => (
                <div
                  key={q.id}
                  style={{ padding: "12px 0", borderTop: "1px solid var(--line)" }}
                >
                  <p className="quiz-stem" style={{ margin: 0 }}>
                    <strong>
                      {qi + 1}. {q.stem}
                    </strong>
                    {q.ref ? (
                      <span className="muted small">
                        {" "}
                        · {T.ex_source}: {q.ref}
                      </span>
                    ) : null}
                  </p>

                  <ul style={{ listStyle: "none", margin: "8px 0 0", padding: 0 }}>
                    {q.opts.map((opt, oi) => {
                      const isCorrect = oi === q.correct;
                      return (
                        <li
                          key={oi}
                          className="small"
                          style={{
                            padding: "4px 0",
                            display: "flex",
                            gap: 8,
                            alignItems: "baseline",
                          }}
                        >
                          <span className="quiz-letter">
                            {String.fromCharCode(65 + oi)}
                          </span>
                          <span style={isCorrect ? { fontWeight: 600 } : undefined}>
                            {opt}
                          </span>
                          {isCorrect ? (
                            <span className="badge ok" style={{ marginLeft: 4 }}>
                              ✓ {T.ex_correct_answer}
                            </span>
                          ) : null}
                        </li>
                      );
                    })}
                  </ul>

                  {q.expl ? (
                    <p className="small muted" style={{ margin: "8px 0 0" }}>
                      <strong>{T.ex_explanation}:</strong> {q.expl}
                    </p>
                  ) : null}
                </div>
              ))}
            </div>
          );
        })
      )}
    </>
  );
}
