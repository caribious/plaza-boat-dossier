import { createClient } from "@/lib/supabase/server";
import {
  fmtDate,
  qmsStatusBadge,
  incidentKindLabel,
  severityLabel,
  improvementTypeLabel,
  courseLabel,
} from "@/lib/format";

export const dynamic = "force-dynamic";

export default async function IltQmsRegisters() {
  const supabase = createClient();
  const [inc, com, imp] = await Promise.all([
    supabase.from("qms_incidents").select("*").order("created_at", { ascending: false }),
    supabase.from("qms_complaints").select("*").order("created_at", { ascending: false }),
    supabase.from("qms_improvements").select("*").order("created_at", { ascending: false }),
  ]);
  const incidents = (inc.data as any[]) ?? [];
  const complaints = (com.data as any[]) ?? [];
  const improvements = (imp.data as any[]) ?? [];

  return (
    <>
      <h1 className="page-title">QMS-registers — ISO 9001 (alleen-lezen)</h1>
      <p className="page-sub">
        Incidenten/ongevallen, bijna-ongevallen, klachten en verbeteringen (CAPA).
        Volledig, ongewijzigd beeld conform NEN-EN-ISO 9001:2015 §8 en §10.
      </p>

      <div className="card">
        <h2>Incidenten / ongevallen ({incidents.length})</h2>
        <table>
          <thead>
            <tr><th>Ref</th><th>Soort</th><th>Datum</th><th>Opleiding</th><th>Ernst</th><th>Eigenaar</th><th>Streefdatum</th><th>Status</th></tr>
          </thead>
          <tbody>
            {incidents.length === 0 ? (
              <tr><td colSpan={8} className="muted small">Geen registraties.</td></tr>
            ) : incidents.map((r) => {
              const st = qmsStatusBadge(r.status);
              return (
                <tr key={r.id}>
                  <td className="small">{r.ref ?? "—"}</td>
                  <td className="muted small">{incidentKindLabel(r.kind)}</td>
                  <td className="muted small">{fmtDate(r.report_date)}</td>
                  <td className="muted small">{courseLabel(r.course_code)}</td>
                  <td className="muted small">{severityLabel(r.severity)}</td>
                  <td className="muted small">{r.owner ?? "—"}</td>
                  <td className="muted small">{fmtDate(r.due_date)}</td>
                  <td><span className={`badge ${st.cls}`}>{st.label}</span></td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="card">
        <h2>Klachten ({complaints.length})</h2>
        <table>
          <thead>
            <tr><th>Ref</th><th>Datum</th><th>Klager</th><th>Opleiding</th><th>Categorie</th><th>Eigenaar</th><th>Streefdatum</th><th>Status</th></tr>
          </thead>
          <tbody>
            {complaints.length === 0 ? (
              <tr><td colSpan={8} className="muted small">Geen registraties.</td></tr>
            ) : complaints.map((r) => {
              const st = qmsStatusBadge(r.status);
              return (
                <tr key={r.id}>
                  <td className="small">{r.ref ?? "—"}</td>
                  <td className="muted small">{fmtDate(r.report_date)}</td>
                  <td className="muted small">{r.complainant ?? "—"}</td>
                  <td className="muted small">{courseLabel(r.course_code)}</td>
                  <td className="muted small">{r.category ?? "—"}</td>
                  <td className="muted small">{r.owner ?? "—"}</td>
                  <td className="muted small">{fmtDate(r.due_date)}</td>
                  <td><span className={`badge ${st.cls}`}>{st.label}</span></td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="card">
        <h2>Verbeteringen / CAPA ({improvements.length})</h2>
        <table>
          <thead>
            <tr><th>Ref</th><th>Datum</th><th>Bron</th><th>Opleiding</th><th>Type</th><th>Eigenaar</th><th>Streefdatum</th><th>Status</th></tr>
          </thead>
          <tbody>
            {improvements.length === 0 ? (
              <tr><td colSpan={8} className="muted small">Geen registraties.</td></tr>
            ) : improvements.map((r) => {
              const st = qmsStatusBadge(r.status);
              return (
                <tr key={r.id}>
                  <td className="small">{r.ref ?? "—"}</td>
                  <td className="muted small">{fmtDate(r.raised_date)}</td>
                  <td className="muted small">{r.source ?? "—"}</td>
                  <td className="muted small">{courseLabel(r.course_code)}</td>
                  <td className="muted small">{improvementTypeLabel(r.type)}</td>
                  <td className="muted small">{r.owner ?? "—"}</td>
                  <td className="muted small">{fmtDate(r.due_date)}</td>
                  <td><span className={`badge ${st.cls}`}>{st.label}</span></td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </>
  );
}
