import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fmtDate, qmsStatusBadge, incidentKindLabel, severityLabel, improvementTypeLabel, courseLabel } from "@/lib/format";
import { t } from "@/lib/i18n";

export const dynamic = "force-dynamic";

export default async function IltQmsRegisters() {
  const T = t();
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
      <h1 className="page-title">{T.ilr_title}</h1>
      <p className="page-sub">{T.ilr_sub}</p>
      <p className="small" style={{ marginTop: -6 }}>
        <Link href="/ilt/quality/registers/risks">{T.ilr_to_risks}</Link>
      </p>

      <div className="card">
        <h2>{T.rg_incidents} ({incidents.length})</h2>
        <table>
          <thead><tr><th>{T.ref}</th><th>{T.rg_kind}</th><th>{T.date}</th><th>{T.course}</th><th>{T.rg_severity}</th><th>{T.owner}</th><th>{T.rg_duedate}</th><th>{T.status}</th></tr></thead>
          <tbody>
            {incidents.length === 0 ? <tr><td colSpan={8} className="muted small">{T.none}</td></tr> : incidents.map((r) => {
              const st = qmsStatusBadge(r.status);
              return (<tr key={r.id}>
                <td className="small">{r.ref ?? "—"}</td><td className="muted small">{incidentKindLabel(r.kind)}</td>
                <td className="muted small">{fmtDate(r.report_date)}</td><td className="muted small">{courseLabel(r.course_code)}</td>
                <td className="muted small">{severityLabel(r.severity)}</td><td className="muted small">{r.owner ?? "—"}</td>
                <td className="muted small">{fmtDate(r.due_date)}</td><td><span className={`badge ${st.cls}`}>{st.label}</span></td></tr>);
            })}
          </tbody>
        </table>
      </div>

      <div className="card">
        <h2>{T.rg_complaints} ({complaints.length})</h2>
        <table>
          <thead><tr><th>{T.ref}</th><th>{T.date}</th><th>{T.rg_complainant}</th><th>{T.course}</th><th>{T.rg_category}</th><th>{T.owner}</th><th>{T.rg_duedate}</th><th>{T.status}</th></tr></thead>
          <tbody>
            {complaints.length === 0 ? <tr><td colSpan={8} className="muted small">{T.none}</td></tr> : complaints.map((r) => {
              const st = qmsStatusBadge(r.status);
              return (<tr key={r.id}>
                <td className="small">{r.ref ?? "—"}</td><td className="muted small">{fmtDate(r.report_date)}</td>
                <td className="muted small">{r.complainant ?? "—"}</td><td className="muted small">{courseLabel(r.course_code)}</td>
                <td className="muted small">{r.category ?? "—"}</td><td className="muted small">{r.owner ?? "—"}</td>
                <td className="muted small">{fmtDate(r.due_date)}</td><td><span className={`badge ${st.cls}`}>{st.label}</span></td></tr>);
            })}
          </tbody>
        </table>
      </div>

      <div className="card">
        <h2>{T.rg_improvements} ({improvements.length})</h2>
        <table>
          <thead><tr><th>{T.ref}</th><th>{T.date}</th><th>{T.rg_source}</th><th>{T.course}</th><th>{T.type}</th><th>{T.owner}</th><th>{T.rg_duedate}</th><th>{T.status}</th></tr></thead>
          <tbody>
            {improvements.length === 0 ? <tr><td colSpan={8} className="muted small">{T.none}</td></tr> : improvements.map((r) => {
              const st = qmsStatusBadge(r.status);
              return (<tr key={r.id}>
                <td className="small">{r.ref ?? "—"}</td><td className="muted small">{fmtDate(r.raised_date)}</td>
                <td className="muted small">{r.source ?? "—"}</td><td className="muted small">{courseLabel(r.course_code)}</td>
                <td className="muted small">{improvementTypeLabel(r.type)}</td><td className="muted small">{r.owner ?? "—"}</td>
                <td className="muted small">{fmtDate(r.due_date)}</td><td><span className={`badge ${st.cls}`}>{st.label}</span></td></tr>);
            })}
          </tbody>
        </table>
      </div>
    </>
  );
}
