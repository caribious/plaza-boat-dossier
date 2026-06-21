import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fmtDate, qmsStatusBadge, incidentKindLabel, severityLabel, improvementTypeLabel, courseLabel } from "@/lib/format";
import { t, type Dict } from "@/lib/i18n";
import { saveIncident, saveComplaint, saveImprovement } from "./actions";

export const dynamic = "force-dynamic";
type Search = { reg?: string; status?: string };

const REG_KEYS = ["incidents", "complaints", "improvements"] as const;
const COURSE_OPTS = ["", "BM-I", "BM-II", "BM-III"];

function CourseSelect({ value, T }: { value?: string | null; T: Dict }) {
  return (
    <select name="course_code" defaultValue={value ?? ""} title={T.course}>
      {COURSE_OPTS.map((v) => (<option key={v} value={v}>{v === "" ? courseLabel(null) : v}</option>))}
    </select>
  );
}
function StatusSelect({ value, T }: { value?: string | null; T: Dict }) {
  return (
    <select name="status" defaultValue={value ?? "open"} title={T.status}>
      <option value="open">{T.st_open}</option>
      <option value="in_behandeling">{T.st_progress}</option>
      <option value="gesloten">{T.st_closed}</option>
    </select>
  );
}
const inputCol: React.CSSProperties = { display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 };
const taStyle: React.CSSProperties = { width: "100%", fontFamily: "inherit", fontSize: 14, padding: 8, borderRadius: 8, border: "1px solid var(--line)" };

export default async function QmsRegisters({ searchParams }: { searchParams: Search }) {
  const T = t();
  const reg = (REG_KEYS.find((r) => r === searchParams.reg)) ?? "incidents";
  const status = searchParams.status ?? "";
  const supabase = createClient();
  const table = reg === "incidents" ? "qms_incidents" : reg === "complaints" ? "qms_complaints" : "qms_improvements";

  let q = supabase.from(table).select("*").order("created_at", { ascending: false });
  if (status) q = q.eq("status", status);
  const { data } = await q;
  const rows = (data as any[]) ?? [];

  const REGISTERS = [
    { key: "incidents", label: T.rg_incidents }, { key: "complaints", label: T.rg_complaints }, { key: "improvements", label: T.rg_improvements },
  ] as const;
  const STATUS_FILTERS = [
    { key: "", label: T.st_all }, { key: "open", label: T.st_open }, { key: "in_behandeling", label: T.st_progress }, { key: "gesloten", label: T.st_closed },
  ];
  const href = (r: string, s: string) => `/admin/quality/registers?reg=${r}${s ? `&status=${s}` : ""}`;

  return (
    <>
      <h1 className="page-title">{T.rg_title}</h1>
      <p className="page-sub">{T.rg_sub}</p>

      <nav className="learn-tabs" style={{ marginBottom: 12 }}>
        {REGISTERS.map((r) => (
          <Link key={r.key} href={href(r.key, status)} className={`learn-tab${reg === r.key ? " active" : ""}`}>{r.label}</Link>
        ))}
      </nav>

      <div className="card" style={{ display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center" }}>
        <span className="muted small">{T.rg_filter}</span>
        {STATUS_FILTERS.map((s) => (
          <Link key={s.key} href={href(reg, s.key)} className={`btn sm${status === s.key ? "" : " ghost"}`}>{s.label}</Link>
        ))}
      </div>

      {reg === "incidents" && <IncidentsView rows={rows} T={T} />}
      {reg === "complaints" && <ComplaintsView rows={rows} T={T} />}
      {reg === "improvements" && <ImprovementsView rows={rows} T={T} />}
    </>
  );
}

function SeveritySelect({ value, T }: { value?: string | null; T: Dict }) {
  return (
    <select name="severity" defaultValue={value ?? ""} title={T.rg_severity}>
      <option value="">{T.rg_severity}…</option>
      <option value="laag">{T.rg_sev_low}</option>
      <option value="middel">{T.rg_sev_mid}</option>
      <option value="hoog">{T.rg_sev_high}</option>
    </select>
  );
}
function KindSelect({ value, T }: { value?: string | null; T: Dict }) {
  return (
    <select name="kind" defaultValue={value ?? "ongeval"} title={T.rg_kind}>
      <option value="ongeval">{T.rg_accident}</option>
      <option value="bijna_ongeval">{T.rg_nearmiss}</option>
    </select>
  );
}
function TypeSelect({ value, T }: { value?: string | null; T: Dict }) {
  return (
    <select name="type" defaultValue={value ?? ""} title={T.type}>
      <option value="">{T.type}…</option>
      <option value="correctief">{T.rg_t_corr}</option>
      <option value="preventief">{T.rg_t_prev}</option>
      <option value="verbetering">{T.rg_t_impr}</option>
    </select>
  );
}

function IncidentFields({ r, T }: { r?: any; T: Dict }) {
  return (
    <>
      <div style={inputCol}>
        <KindSelect value={r?.kind} T={T} />
        <input name="report_date" type="date" defaultValue={r?.report_date ?? ""} title={T.rg_reportdate} />
        <input name="reporter_name" defaultValue={r?.reporter_name ?? ""} placeholder={T.rg_reporter} />
        <CourseSelect value={r?.course_code} T={T} />
        <input name="location" defaultValue={r?.location ?? ""} placeholder={T.rg_location} />
        <SeveritySelect value={r?.severity} T={T} />
        <input name="owner" defaultValue={r?.owner ?? ""} placeholder={T.owner} />
        <input name="due_date" type="date" defaultValue={r?.due_date ?? ""} title={T.rg_duedate} />
        <StatusSelect value={r?.status} T={T} />
        <input name="closed_date" type="date" defaultValue={r?.closed_date ?? ""} title={T.rg_closeddate} />
      </div>
      <textarea name="description" defaultValue={r?.description ?? ""} placeholder={T.rg_desc} rows={2} style={{ ...taStyle, marginTop: 10 }} />
      <textarea name="immediate_action" defaultValue={r?.immediate_action ?? ""} placeholder={T.rg_immediate} rows={2} style={{ ...taStyle, marginTop: 10 }} />
      <textarea name="root_cause" defaultValue={r?.root_cause ?? ""} placeholder={T.rg_root} rows={2} style={{ ...taStyle, marginTop: 10 }} />
      <textarea name="corrective_action" defaultValue={r?.corrective_action ?? ""} placeholder={T.rg_corrective} rows={2} style={{ ...taStyle, marginTop: 10 }} />
    </>
  );
}

function IncidentsView({ rows, T }: { rows: any[]; T: Dict }) {
  return (
    <>
      <div className="card">
        <details>
          <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>{T.rg_new_incident}</summary>
          <form action={saveIncident} style={{ marginTop: 12, maxWidth: 720 }}>
            <IncidentFields T={T} />
            <button className="btn" type="submit" style={{ marginTop: 12 }}>{T.save}</button>
          </form>
        </details>
      </div>
      <div className="card">
        <table>
          <thead><tr><th>{T.ref}</th><th>{T.rg_kind}</th><th>{T.date}</th><th>{T.course}</th><th>{T.rg_severity}</th><th>{T.owner}</th><th>{T.status}</th></tr></thead>
          <tbody>
            {rows.length === 0 ? <tr><td colSpan={7} className="muted small">{T.none}</td></tr> : rows.map((r) => {
              const st = qmsStatusBadge(r.status);
              return (<tr key={r.id}>
                <td className="small">{r.ref ?? "—"}</td><td className="muted small">{incidentKindLabel(r.kind)}</td>
                <td className="muted small">{fmtDate(r.report_date)}</td><td className="muted small">{courseLabel(r.course_code)}</td>
                <td className="muted small">{severityLabel(r.severity)}</td><td className="muted small">{r.owner ?? "—"}</td>
                <td><span className={`badge ${st.cls}`}>{st.label}</span></td></tr>);
            })}
          </tbody>
        </table>
        {rows.map((r) => (
          <details key={`e-${r.id}`} style={{ marginTop: 10, borderTop: "1px solid var(--line)", paddingTop: 10 }}>
            <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>{r.ref ?? "—"} · {incidentKindLabel(r.kind)} {T.edit}</summary>
            <form action={saveIncident} style={{ marginTop: 12, maxWidth: 720 }}>
              <input type="hidden" name="id" value={r.id} />
              <IncidentFields r={r} T={T} />
              <button className="btn" type="submit" style={{ marginTop: 12 }}>{T.save}</button>
            </form>
          </details>
        ))}
      </div>
    </>
  );
}

function ComplaintFields({ r, T }: { r?: any; T: Dict }) {
  return (
    <>
      <div style={inputCol}>
        <input name="report_date" type="date" defaultValue={r?.report_date ?? ""} title={T.rg_reportdate} />
        <input name="complainant" defaultValue={r?.complainant ?? ""} placeholder={T.rg_complainant} />
        <CourseSelect value={r?.course_code} T={T} />
        <input name="channel" defaultValue={r?.channel ?? ""} placeholder={T.rg_channel} />
        <input name="category" defaultValue={r?.category ?? ""} placeholder={T.rg_category} />
        <input name="owner" defaultValue={r?.owner ?? ""} placeholder={T.owner} />
        <input name="due_date" type="date" defaultValue={r?.due_date ?? ""} title={T.rg_duedate} />
        <StatusSelect value={r?.status} T={T} />
        <input name="closed_date" type="date" defaultValue={r?.closed_date ?? ""} title={T.rg_closeddate} />
      </div>
      <textarea name="description" defaultValue={r?.description ?? ""} placeholder={T.rg_desc} rows={2} style={{ ...taStyle, marginTop: 10 }} />
      <textarea name="action" defaultValue={r?.action ?? ""} placeholder={T.rg_handling} rows={2} style={{ ...taStyle, marginTop: 10 }} />
    </>
  );
}

function ComplaintsView({ rows, T }: { rows: any[]; T: Dict }) {
  return (
    <>
      <div className="card">
        <details>
          <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>{T.rg_new_complaint}</summary>
          <form action={saveComplaint} style={{ marginTop: 12, maxWidth: 720 }}>
            <ComplaintFields T={T} />
            <button className="btn" type="submit" style={{ marginTop: 12 }}>{T.save}</button>
          </form>
        </details>
      </div>
      <div className="card">
        <table>
          <thead><tr><th>{T.ref}</th><th>{T.date}</th><th>{T.rg_complainant}</th><th>{T.course}</th><th>{T.rg_category}</th><th>{T.owner}</th><th>{T.status}</th></tr></thead>
          <tbody>
            {rows.length === 0 ? <tr><td colSpan={7} className="muted small">{T.none}</td></tr> : rows.map((r) => {
              const st = qmsStatusBadge(r.status);
              return (<tr key={r.id}>
                <td className="small">{r.ref ?? "—"}</td><td className="muted small">{fmtDate(r.report_date)}</td>
                <td className="muted small">{r.complainant ?? "—"}</td><td className="muted small">{courseLabel(r.course_code)}</td>
                <td className="muted small">{r.category ?? "—"}</td><td className="muted small">{r.owner ?? "—"}</td>
                <td><span className={`badge ${st.cls}`}>{st.label}</span></td></tr>);
            })}
          </tbody>
        </table>
        {rows.map((r) => (
          <details key={`e-${r.id}`} style={{ marginTop: 10, borderTop: "1px solid var(--line)", paddingTop: 10 }}>
            <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>{r.ref ?? "—"} · {T.rg_edit_complaint}</summary>
            <form action={saveComplaint} style={{ marginTop: 12, maxWidth: 720 }}>
              <input type="hidden" name="id" value={r.id} />
              <ComplaintFields r={r} T={T} />
              <button className="btn" type="submit" style={{ marginTop: 12 }}>{T.save}</button>
            </form>
          </details>
        ))}
      </div>
    </>
  );
}

function ImprovementFields({ r, T }: { r?: any; T: Dict }) {
  return (
    <>
      <div style={inputCol}>
        <input name="raised_date" type="date" defaultValue={r?.raised_date ?? ""} title={T.rg_raiseddate} />
        <input name="source" defaultValue={r?.source ?? ""} placeholder={T.rg_source} />
        <CourseSelect value={r?.course_code} T={T} />
        <TypeSelect value={r?.type} T={T} />
        <input name="owner" defaultValue={r?.owner ?? ""} placeholder={T.owner} />
        <input name="due_date" type="date" defaultValue={r?.due_date ?? ""} title={T.rg_duedate} />
        <StatusSelect value={r?.status} T={T} />
        <input name="closed_date" type="date" defaultValue={r?.closed_date ?? ""} title={T.rg_closeddate} />
      </div>
      <textarea name="description" defaultValue={r?.description ?? ""} placeholder={T.rg_desc} rows={2} style={{ ...taStyle, marginTop: 10 }} />
      <textarea name="action" defaultValue={r?.action ?? ""} placeholder={T.rg_action} rows={2} style={{ ...taStyle, marginTop: 10 }} />
      <textarea name="effectiveness_check" defaultValue={r?.effectiveness_check ?? ""} placeholder={T.rg_effcheck} rows={2} style={{ ...taStyle, marginTop: 10 }} />
    </>
  );
}

function ImprovementsView({ rows, T }: { rows: any[]; T: Dict }) {
  return (
    <>
      <div className="card">
        <details>
          <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>{T.rg_new_improvement}</summary>
          <form action={saveImprovement} style={{ marginTop: 12, maxWidth: 720 }}>
            <ImprovementFields T={T} />
            <button className="btn" type="submit" style={{ marginTop: 12 }}>{T.save}</button>
          </form>
        </details>
      </div>
      <div className="card">
        <table>
          <thead><tr><th>{T.ref}</th><th>{T.date}</th><th>{T.rg_source}</th><th>{T.course}</th><th>{T.type}</th><th>{T.owner}</th><th>{T.status}</th></tr></thead>
          <tbody>
            {rows.length === 0 ? <tr><td colSpan={7} className="muted small">{T.none}</td></tr> : rows.map((r) => {
              const st = qmsStatusBadge(r.status);
              return (<tr key={r.id}>
                <td className="small">{r.ref ?? "—"}</td><td className="muted small">{fmtDate(r.raised_date)}</td>
                <td className="muted small">{r.source ?? "—"}</td><td className="muted small">{courseLabel(r.course_code)}</td>
                <td className="muted small">{improvementTypeLabel(r.type)}</td><td className="muted small">{r.owner ?? "—"}</td>
                <td><span className={`badge ${st.cls}`}>{st.label}</span></td></tr>);
            })}
          </tbody>
        </table>
        {rows.map((r) => (
          <details key={`e-${r.id}`} style={{ marginTop: 10, borderTop: "1px solid var(--line)", paddingTop: 10 }}>
            <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>{r.ref ?? "—"} · {T.rg_edit_improvement}</summary>
            <form action={saveImprovement} style={{ marginTop: 12, maxWidth: 720 }}>
              <input type="hidden" name="id" value={r.id} />
              <ImprovementFields r={r} T={T} />
              <button className="btn" type="submit" style={{ marginTop: 12 }}>{T.save}</button>
            </form>
          </details>
        ))}
      </div>
    </>
  );
}
