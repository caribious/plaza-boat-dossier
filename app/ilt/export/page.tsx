import { createClient } from "@/lib/supabase/server";
import { examBadge, examKindLabel, fmtDate } from "@/lib/format";
import { getLocale, t } from "@/lib/i18n";
import PrintButton from "@/components/PrintButton";

export const dynamic = "force-dynamic";

export default async function IltExport() {
  const T = t();
  const loc = getLocale() === "en" ? "en-GB" : "nl-NL";
  const supabase = createClient();

  const { data: studentsData } = await supabase
    .from("students")
    .select(`id, student_number, first_name, last_name, date_of_birth, place_of_birth,
       identity_verified, rya_number,
       enrollments ( status, start_date, courses ( code, title ),
         module_progress ( status, hours_logged, modules ( sequence, title ) ),
         exam_results ( kind, attempt, exam_date, examiner_name, score, max_score, outcome, valid_until ) ),
       certificates ( certificate_number, title, issued_date, expiry_date )`)
    .order("last_name");
  const { data: instructorsData } = await supabase
    .from("instructors")
    .select(`first_name, last_name, title,
       instructor_certificates ( cert_type, certificate_number, issuing_body, issued_date, expiry_date )`)
    .order("last_name");
  const { data: coursesData } = await supabase
    .from("courses").select(`code, title, regulatory_reference, modules ( sequence, title, required_hours )`).order("code");
  const { data: qmsData } = await supabase.from("qms_clauses").select("clause_number, title, pbc_approach").order("sort_order");
  const { data: qmsDocs } = await supabase.from("qms_documents").select("title, doc_type, reference").order("created_at");

  const students = (studentsData as any[]) ?? [];
  const instructors = (instructorsData as any[]) ?? [];
  const courses = (coursesData as any[]) ?? [];
  const now = new Date().toLocaleString(loc);

  return (
    <div className="report" style={{ maxWidth: "100%" }}>
      <div className="toolbar no-print">
        <PrintButton />
        <span className="muted small">{T.ile_print_hint}</span>
      </div>

      <div className="report-head">
        <div className="org">Plaza Boat College<small>{T.ile_org_sub}</small></div>
        <div className="meta">{T.ile_meta}<br />{T.ile_generated} {now}</div>
      </div>

      <h1>{T.ile_title}</h1>
      <p className="muted small">{T.ile_intro}</p>

      <h3>{T.ile_h1}</h3>
      {courses.map((c) => {
        const mods = (c.modules ?? []).slice().sort((a: any, b: any) => a.sequence - b.sequence);
        return (
          <p key={c.code} className="small">
            <strong>{c.code} — {c.title}</strong> ({c.regulatory_reference}) · {mods.length} {T.ilc_modules}:
            {" "}{mods.map((m: any) => m.title).join(", ")}.
          </p>
        );
      })}

      <h3>{T.ile_h2}</h3>
      {instructors.map((ins, i) => (
        <div key={i} className="small" style={{ marginBottom: 8 }}>
          <strong>{ins.first_name} {ins.last_name}</strong>{ins.title ? ` — ${ins.title}` : ""}
          <ul style={{ margin: "4px 0", paddingLeft: 18 }}>
            {(ins.instructor_certificates ?? []).map((c: any, j: number) => (
              <li key={j}>
                {c.cert_type} — {c.certificate_number ?? T.ile_no_num} ({c.issuing_body ?? "—"}),
                {" "}{T.ile_valid_until} {fmtDate(c.expiry_date)}
              </li>
            ))}
          </ul>
        </div>
      ))}

      <h3>{T.ile_h3}</h3>
      <p className="small">
        {T.ile_qms_intro}
        {" "}{((qmsDocs as any[]) ?? []).map((d: any) => `${d.title}${d.reference ? ` (${d.reference})` : ""}`).join("; ") || "—"}.
      </p>
      {((qmsData as any[]) ?? []).map((c: any) => (
        <p key={c.clause_number} className="small" style={{ margin: "4px 0" }}>
          <strong>{c.clause_number}. {c.title}.</strong> {c.pbc_approach}
        </p>
      ))}

      <h3>{T.ile_h4} ({students.length})</h3>
      {students.map((s) => {
        const enr = s.enrollments?.[0];
        const mods = (enr?.module_progress ?? []).slice().sort((a: any, b: any) => (a.modules?.sequence ?? 0) - (b.modules?.sequence ?? 0));
        const exams = enr?.exam_results ?? [];
        const certs = s.certificates ?? [];
        const done = mods.filter((m: any) => m.status === "completed").length;
        const hours = mods.reduce((t: number, m: any) => t + Number(m.hours_logged || 0), 0);
        return (
          <div key={s.id} className="card" style={{ breakInside: "avoid" }}>
            <strong>{s.first_name} {s.last_name}</strong> · {s.student_number}
            <div className="muted small">
              {T.ile_born} {fmtDate(s.date_of_birth)}{s.place_of_birth ? `, ${s.place_of_birth}` : ""} ·
              ID {s.identity_verified ? T.ile_id_ok : T.ile_id_no} ·
              {enr?.courses?.code ?? T.ile_no_course} ·
              {done}/{mods.length} {T.ilc_modules} · {hours} {T.ilc_hours} ·
              RYA {s.rya_number ?? "—"}
            </div>
            <table style={{ marginTop: 8 }}>
              <thead><tr><th>{T.ile_exam}</th><th>{T.ile_attempt}</th><th>{T.date}</th><th>{T.ile_examiner}</th><th>{T.ile_score}</th><th>{T.in_validuntil}</th><th>{T.ile_outcome}</th></tr></thead>
              <tbody>
                {exams.length === 0 ? (
                  <tr><td colSpan={7} className="muted small">{T.ile_no_exams}</td></tr>
                ) : exams.map((x: any, k: number) => (
                  <tr key={k}>
                    <td>{examKindLabel(x.kind)}</td>
                    <td className="muted small">{x.attempt}</td>
                    <td className="muted small">{fmtDate(x.exam_date)}</td>
                    <td className="muted small">{x.examiner_name ?? "—"}</td>
                    <td className="muted small">{x.score != null ? `${x.score}/${x.max_score}` : "—"}</td>
                    <td className="muted small">{fmtDate(x.valid_until)}</td>
                    <td className="muted small">{examBadge(x.outcome).label}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            {certs.length > 0 && (
              <div className="small" style={{ marginTop: 6 }}>
                {T.ile_certs} {certs.map((c: any) => `${c.certificate_number} (${c.title}, ${T.ile_valid_until} ${fmtDate(c.expiry_date)})`).join("; ")}
              </div>
            )}
          </div>
        );
      })}

      <p className="muted small" style={{ marginTop: 24 }}>{T.ile_end}</p>
    </div>
  );
}
