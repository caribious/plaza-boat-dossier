import { createClient } from "@/lib/supabase/server";
import { progressBadge, examBadge, examKindLabel, fmtDate } from "@/lib/format";

export const dynamic = "force-dynamic";

export default async function StudentPortal() {
  const supabase = createClient();

  // RLS zorgt ervoor dat een student uitsluitend zijn eigen dossier ziet.
  const { data: student } = await supabase
    .from("students")
    .select("*")
    .single();

  if (!student) {
    return (
      <div className="card">
        <h2>Nog geen dossier gekoppeld</h2>
        <p className="muted small">
          Er is nog geen cursistdossier aan dit account gekoppeld. Neem contact op
          met de administratie van Plaza Boat College.
        </p>
      </div>
    );
  }

  const { data: enrollment } = await supabase
    .from("enrollments")
    .select("id, status, start_date, target_end_date, courses ( code, title )")
    .order("created_at", { ascending: false })
    .limit(1)
    .single();
  const enr: any = enrollment;

  const { data: progress } = enr
    ? await supabase
        .from("module_progress")
        .select("id, status, hours_logged, modules ( sequence, code, title, required_hours )")
        .eq("enrollment_id", enr.id)
    : { data: [] as any[] };
  const mods = (progress as any[]) ?? [];
  mods.sort((a, b) => (a.modules?.sequence ?? 0) - (b.modules?.sequence ?? 0));

  const { data: exams } = enr
    ? await supabase
        .from("exam_results")
        .select("id, kind, exam_date, outcome, valid_until")
        .eq("enrollment_id", enr.id)
        .order("kind")
    : { data: [] as any[] };

  const { data: certs } = await supabase
    .from("certificates")
    .select("id, certificate_number, title, issued_date, expiry_date, file_path")
    .eq("student_id", student.id);

  const certList = (certs as any[]) ?? [];
  const signed: Record<string, string> = {};
  for (const c of certList) {
    if (c.file_path) {
      const { data: s } = await supabase.storage
        .from("certificates")
        .createSignedUrl(c.file_path, 3600);
      if (s?.signedUrl) signed[c.id] = s.signedUrl;
    }
  }

  const done = mods.filter((m) => m.status === "completed").length;
  const pct = mods.length ? Math.round((done / mods.length) * 100) : 0;

  return (
    <>
      <h1 className="page-title">
        Welkom, {student.first_name}
      </h1>
      <p className="page-sub">
        {enr?.courses?.title ?? "Geen actieve inschrijving"} · cursistnr. {student.student_number}
      </p>

      <div className="card">
        <h2>Mijn voortgang</h2>
        <div className="progress-wrap" style={{ maxWidth: 360 }}>
          <div className="progress-bar" style={{ width: `${pct}%` }} />
        </div>
        <p className="muted small">
          {done} van {mods.length} modules afgerond ({pct}%).
        </p>
      </div>

      <div className="card">
        <h2>Modules</h2>
        <table>
          <thead>
            <tr><th>Module</th><th>Uren</th><th>Status</th></tr>
          </thead>
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
        <h2>Mijn examens</h2>
        <table>
          <thead>
            <tr><th>Onderdeel</th><th>Datum</th><th>Geldig t/m</th><th>Uitslag</th></tr>
          </thead>
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
        <h2>Mijn certificaten</h2>
        {certList.length === 0 ? (
          <p className="muted small">Nog geen certificaten behaald.</p>
        ) : (
          <table>
            <thead>
              <tr><th>Nummer</th><th>Titel</th><th>Afgegeven</th><th>Geldig t/m</th><th>PDF</th></tr>
            </thead>
            <tbody>
              {certList.map((c) => (
                <tr key={c.id}>
                  <td className="muted small">{c.certificate_number}</td>
                  <td>{c.title}</td>
                  <td className="muted small">{fmtDate(c.issued_date)}</td>
                  <td className="muted small">{fmtDate(c.expiry_date)}</td>
                  <td>
                    {signed[c.id] ? (
                      <a className="small" href={signed[c.id]} target="_blank" rel="noreferrer">Download</a>
                    ) : (
                      <span className="muted small">—</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
