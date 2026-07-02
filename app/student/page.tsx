import { createClient } from "@/lib/supabase/server";
import { progressBadge, examBadge, examKindLabel, fmtDate, qualificationKindLabel, expiryBadge } from "@/lib/format";
import { t } from "@/lib/i18n";
import { updateOwnDetails } from "./actions";

export const dynamic = "force-dynamic";

export default async function StudentPortal() {
  const T = t();
  const supabase = createClient();

  const { data: student } = await supabase.from("students").select("*").single();

  if (!student) {
    return (
      <div className="card">
        <h2>{T.sp_no_record_t}</h2>
        <p className="muted small">{T.sp_no_record}</p>
      </div>
    );
  }

  const { data: enrollment } = await supabase
    .from("enrollments")
    .select("id, status, start_date, target_end_date, courses ( code, title )")
    .order("created_at", { ascending: false }).limit(1).single();
  const enr: any = enrollment;

  const { data: progress } = enr
    ? await supabase.from("module_progress")
        .select("id, status, hours_logged, modules ( sequence, code, title, required_hours )")
        .eq("enrollment_id", enr.id)
    : { data: [] as any[] };
  const mods = (progress as any[]) ?? [];
  mods.sort((a, b) => (a.modules?.sequence ?? 0) - (b.modules?.sequence ?? 0));

  const { data: exams } = enr
    ? await supabase.from("exam_results").select("id, kind, exam_date, outcome, valid_until").eq("enrollment_id", enr.id).order("kind")
    : { data: [] as any[] };

  const { data: certs } = await supabase
    .from("certificates").select("id, certificate_number, title, issued_date, expiry_date, file_path").eq("student_id", student.id);
  const certList = (certs as any[]) ?? [];
  const signed: Record<string, string> = {};
  for (const c of certList) {
    if (c.file_path) {
      const { data: s } = await supabase.storage.from("certificates").createSignedUrl(c.file_path, 3600);
      if (s?.signedUrl) signed[c.id] = s.signedUrl;
    }
  }

  // Toelatingseisen & kwalificaties — RLS toont alleen de eigen rijen.
  const { data: quals } = await supabase
    .from("student_qualifications")
    .select("id, kind, title, number, issuer, valid_until, verified, file_path")
    .eq("student_id", student.id)
    .order("kind");
  const qualList = (quals as any[]) ?? [];
  const qualSigned: Record<string, string> = {};
  for (const q of qualList) {
    if (q.file_path) {
      const { data: s } = await supabase.storage
        .from("student-qualifications")
        .createSignedUrl(q.file_path, 3600);
      if (s?.signedUrl) qualSigned[q.id] = s.signedUrl;
    }
  }

  const done = mods.filter((m) => m.status === "completed").length;
  const pct = mods.length ? Math.round((done / mods.length) * 100) : 0;

  return (
    <>
      <h1 className="page-title">{T.sp_welcome} {student.first_name}</h1>
      <p className="page-sub">
        {enr?.courses?.title ?? T.sp_no_enrol} · {T.sp_studentno} {student.student_number}
      </p>

      <div className="card">
        <h2>{T.sp_progress}</h2>
        <div className="progress-wrap" style={{ maxWidth: 360 }}>
          <div className="progress-bar" style={{ width: `${pct}%` }} />
        </div>
        <p className="muted small">{done} {T.sp_done_of} {mods.length} {T.sp_modules_done} ({pct}%).</p>
      </div>

      <div className="card">
        <h2>{T.sp_mydata}</h2>
        <dl className="kv">
          <dt>{T.sp_fn}</dt><dd>{student.first_name}</dd>
          <dt>{T.sp_ln}</dt><dd>{student.last_name}</dd>
          <dt>{T.sp_dob}</dt><dd>{fmtDate(student.date_of_birth)}</dd>
          <dt>{T.sp_email}</dt><dd>{student.email ?? "—"}</dd>
          <dt>{T.sp_phone}</dt><dd>{student.phone ?? "—"}</dd>
          <dt>{T.sp_addr}</dt><dd>{student.address ?? "—"}</dd>
        </dl>
        <details style={{ marginTop: 10 }}>
          <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>{T.sp_mydata_edit}</summary>
          <p className="muted small" style={{ marginTop: 8 }}>{T.sp_mydata_hint}</p>
          <form action={updateOwnDetails} style={{ marginTop: 8, display: "grid", gap: 8 }}>
            <div className="grid-2">
              <div>
                <label className="flabel">{T.sp_fn}</label>
                <input name="first_name" defaultValue={student.first_name} required style={{ width: "100%" }} />
              </div>
              <div>
                <label className="flabel">{T.sp_ln}</label>
                <input name="last_name" defaultValue={student.last_name} required style={{ width: "100%" }} />
              </div>
              <div>
                <label className="flabel">{T.sp_dob}</label>
                <input name="date_of_birth" type="date" defaultValue={student.date_of_birth ?? ""} style={{ width: "100%" }} />
              </div>
              <div>
                <label className="flabel">{T.sp_pob}</label>
                <input name="place_of_birth" defaultValue={student.place_of_birth ?? ""} style={{ width: "100%" }} />
              </div>
              <div>
                <label className="flabel">{T.sp_email}</label>
                <input name="email" type="email" defaultValue={student.email ?? ""} style={{ width: "100%" }} />
              </div>
              <div>
                <label className="flabel">{T.sp_phone}</label>
                <input name="phone" defaultValue={student.phone ?? ""} style={{ width: "100%" }} />
              </div>
              <div>
                <label className="flabel">{T.sp_nat}</label>
                <input name="nationality" defaultValue={student.nationality ?? ""} style={{ width: "100%" }} />
              </div>
              <div>
                <label className="flabel">{T.sp_addr}</label>
                <input name="address" defaultValue={student.address ?? ""} style={{ width: "100%" }} />
              </div>
            </div>
            <button className="btn sm" type="submit" style={{ justifySelf: "start" }}>{T.sp_save}</button>
          </form>
        </details>
      </div>

      <div className="card">
        <h2>{T.sp_modules}</h2>
        <table>
          <thead><tr><th>{T.sp_module}</th><th>{T.sp_hours}</th><th>{T.status}</th></tr></thead>
          <tbody>
            {mods.map((m) => {
              const b = progressBadge(m.status);
              return (
                <tr key={m.id}>
                  <td>{m.modules?.title}</td>
                  <td className="muted small">{m.hours_logged}/{m.modules?.required_hours}</td>
                  <td><span className={`badge ${b.cls}`}>{b.label}</span></td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="card">
        <h2>{T.sp_exams}</h2>
        <table>
          <thead><tr><th>{T.sp_part}</th><th>{T.date}</th><th>{T.sp_validuntil}</th><th>{T.sp_outcome}</th></tr></thead>
          <tbody>
            {((exams as any[]) ?? []).map((x) => {
              const b = examBadge(x.outcome);
              return (
                <tr key={x.id}>
                  <td>{examKindLabel(x.kind)}</td>
                  <td className="muted small">{fmtDate(x.exam_date)}</td>
                  <td className="muted small">{fmtDate(x.valid_until)}</td>
                  <td><span className={`badge ${b.cls}`}>{b.label}</span></td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="card">
        <h2>{T.sp_qual_title}</h2>
        {qualList.length === 0 ? (
          <p className="muted small">{T.qual_none}</p>
        ) : (
          <table>
            <thead>
              <tr><th>{T.qual_col_type}</th><th>{T.qual_col_number}</th><th>{T.qual_col_validuntil}</th><th>{T.qual_col_verified}</th><th>{T.qual_col_doc}</th></tr>
            </thead>
            <tbody>
              {qualList.map((q) => {
                const eb = expiryBadge(q.valid_until);
                return (
                  <tr key={q.id}>
                    <td>
                      {qualificationKindLabel(q.kind)}
                      {q.title ? <div className="muted small">{q.title}</div> : null}
                    </td>
                    <td className="muted small">{q.number ?? "—"}</td>
                    <td className="small">
                      {fmtDate(q.valid_until)}{" "}
                      <span className={`badge ${eb.cls}`}>{eb.label}</span>
                    </td>
                    <td>
                      {q.verified
                        ? <span className="badge ok">{T.qual_verified_yes}</span>
                        : <span className="badge warn">{T.qual_verified_no}</span>}
                    </td>
                    <td>
                      {qualSigned[q.id] ? (
                        <a className="small" href={qualSigned[q.id]} target="_blank" rel="noreferrer">{T.q_download}</a>
                      ) : (
                        <span className="muted small">—</span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      <div className="card">
        <h2>{T.sp_certs}</h2>
        {certList.length === 0 ? (
          <p className="muted small">{T.sp_no_certs}</p>
        ) : (
          <table>
            <thead><tr><th>{T.sp_number}</th><th>{T.sp_doctitle}</th><th>{T.sp_issued}</th><th>{T.sp_validuntil}</th><th>{T.q_pdf}</th></tr></thead>
            <tbody>
              {certList.map((c) => (
                <tr key={c.id}>
                  <td className="muted small">{c.certificate_number}</td>
                  <td>{c.title}</td>
                  <td className="muted small">{fmtDate(c.issued_date)}</td>
                  <td className="muted small">{fmtDate(c.expiry_date)}</td>
                  <td>{signed[c.id] ? <a className="small" href={signed[c.id]} target="_blank" rel="noreferrer">{T.q_download}</a> : <span className="muted small">—</span>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
