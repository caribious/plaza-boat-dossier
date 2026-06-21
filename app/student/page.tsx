import { createClient } from "@/lib/supabase/server";
import { progressBadge, examBadge, examKindLabel, fmtDate } from "@/lib/format";
import { t } from "@/lib/i18n";

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
