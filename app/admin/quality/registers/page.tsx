import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import {
  fmtDate,
  qmsStatusBadge,
  incidentKindLabel,
  severityLabel,
  improvementTypeLabel,
  courseLabel,
} from "@/lib/format";
import { saveIncident, saveComplaint, saveImprovement } from "./actions";

export const dynamic = "force-dynamic";

type Search = { reg?: string; status?: string };

const REGISTERS = [
  { key: "incidents", label: "Incidenten / ongevallen" },
  { key: "complaints", label: "Klachten" },
  { key: "improvements", label: "Verbeteringen (CAPA)" },
] as const;

const STATUS_FILTERS = [
  { key: "", label: "Alle" },
  { key: "open", label: "Open" },
  { key: "in_behandeling", label: "In behandeling" },
  { key: "gesloten", label: "Gesloten" },
];

const COURSE_OPTS = [
  { v: "", label: "n.v.t." },
  { v: "BM-I", label: "BM-I" },
  { v: "BM-II", label: "BM-II" },
  { v: "BM-III", label: "BM-III" },
];

// Kleine herbruikbare opleiding-select
function CourseSelect({ value }: { value?: string | null }) {
  return (
    <select name="course_code" defaultValue={value ?? ""} title="Opleiding">
      {COURSE_OPTS.map((o) => (
        <option key={o.v} value={o.v}>{o.label}</option>
      ))}
    </select>
  );
}

function StatusSelect({ value }: { value?: string | null }) {
  return (
    <select name="status" defaultValue={value ?? "open"} title="Status">
      <option value="open">Open</option>
      <option value="in_behandeling">In behandeling</option>
      <option value="gesloten">Gesloten</option>
    </select>
  );
}

const inputCol: React.CSSProperties = { display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 };
const taStyle: React.CSSProperties = {
  width: "100%", fontFamily: "inherit", fontSize: 14, padding: 8,
  borderRadius: 8, border: "1px solid var(--line)",
};

export default async function QmsRegisters({ searchParams }: { searchParams: Search }) {
  const reg = (REGISTERS.find((r) => r.key === searchParams.reg)?.key) ?? "incidents";
  const status = searchParams.status ?? "";
  const supabase = createClient();

  const table =
    reg === "incidents" ? "qms_incidents" : reg === "complaints" ? "qms_complaints" : "qms_improvements";

  let q = supabase.from(table).select("*").order("created_at", { ascending: false });
  if (status) q = q.eq("status", status);
  const { data } = await q;
  const rows = (data as any[]) ?? [];

  const href = (r: string, s: string) =>
    `/admin/quality/registers?reg=${r}${s ? `&status=${s}` : ""}`;

  return (
    <>
      <h1 className="page-title">QMS-registers — ISO 9001</h1>
      <p className="page-sub">
        Live registers voor incidenten/ongevallen, bijna-ongevallen, klachten en verbeteringen (CAPA).
        Conform NEN-EN-ISO 9001:2015 §8 en §10. Refnummers worden automatisch toegekend.
      </p>

      {/* Register-tabs */}
      <nav className="learn-tabs" style={{ marginBottom: 12 }}>
        {REGISTERS.map((r) => (
          <Link
            key={r.key}
            href={href(r.key, status)}
            className={`learn-tab${reg === r.key ? " active" : ""}`}
          >
            {r.label}
          </Link>
        ))}
      </nav>

      {/* Statusfilter */}
      <div className="card" style={{ display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center" }}>
        <span className="muted small">Filter op status:</span>
        {STATUS_FILTERS.map((s) => (
          <Link
            key={s.key}
            href={href(reg, s.key)}
            className={`btn sm${status === s.key ? "" : " ghost"}`}
          >
            {s.label}
          </Link>
        ))}
      </div>

      {reg === "incidents" && <IncidentsView rows={rows} />}
      {reg === "complaints" && <ComplaintsView rows={rows} />}
      {reg === "improvements" && <ImprovementsView rows={rows} />}
    </>
  );
}

/* ===================== INCIDENTEN ===================== */
function IncidentsView({ rows }: { rows: any[] }) {
  return (
    <>
      <div className="card">
        <details>
          <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>
            + Nieuw incident / bijna-ongeval
          </summary>
          <form action={saveIncident} style={{ marginTop: 12, maxWidth: 720 }}>
            <div style={inputCol}>
              <select name="kind" defaultValue="ongeval" title="Soort">
                <option value="ongeval">Ongeval</option>
                <option value="bijna_ongeval">Bijna-ongeval</option>
              </select>
              <input name="report_date" type="date" title="Meldingsdatum" />
              <input name="reporter_name" placeholder="Melder" />
              <CourseSelect />
              <input name="location" placeholder="Locatie" />
              <select name="severity" defaultValue="" title="Ernst">
                <option value="">Ernst…</option>
                <option value="laag">Laag</option>
                <option value="middel">Middel</option>
                <option value="hoog">Hoog</option>
              </select>
              <input name="owner" placeholder="Eigenaar" />
              <input name="due_date" type="date" title="Streefdatum" />
              <StatusSelect />
              <input name="closed_date" type="date" title="Afgesloten op" />
            </div>
            <textarea name="description" placeholder="Omschrijving" rows={2} style={{ ...taStyle, marginTop: 10 }} />
            <textarea name="immediate_action" placeholder="Directe actie" rows={2} style={{ ...taStyle, marginTop: 10 }} />
            <textarea name="root_cause" placeholder="Oorzaakanalyse" rows={2} style={{ ...taStyle, marginTop: 10 }} />
            <textarea name="corrective_action" placeholder="Corrigerende maatregel" rows={2} style={{ ...taStyle, marginTop: 10 }} />
            <button className="btn" type="submit" style={{ marginTop: 12 }}>Opslaan</button>
          </form>
        </details>
      </div>

      <div className="card">
        <table>
          <thead>
            <tr><th>Ref</th><th>Soort</th><th>Datum</th><th>Opleiding</th><th>Ernst</th><th>Eigenaar</th><th>Status</th></tr>
          </thead>
          <tbody>
            {rows.length === 0 ? (
              <tr><td colSpan={7} className="muted small">Geen registraties.</td></tr>
            ) : rows.map((r) => {
              const st = qmsStatusBadge(r.status);
              return (
                <tr key={r.id}>
                  <td className="small">{r.ref ?? "—"}</td>
                  <td className="muted small">{incidentKindLabel(r.kind)}</td>
                  <td className="muted small">{fmtDate(r.report_date)}</td>
                  <td className="muted small">{courseLabel(r.course_code)}</td>
                  <td className="muted small">{severityLabel(r.severity)}</td>
                  <td className="muted small">{r.owner ?? "—"}</td>
                  <td><span className={`badge ${st.cls}`}>{st.label}</span></td>
                </tr>
              );
            })}
          </tbody>
        </table>

        {/* Bewerk-formulieren (apart om geneste forms te vermijden) */}
        {rows.map((r) => (
          <details key={`e-${r.id}`} style={{ marginTop: 10, borderTop: "1px solid var(--line)", paddingTop: 10 }}>
            <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>
              {r.ref ?? "—"} · {incidentKindLabel(r.kind)} bewerken
            </summary>
            <form action={saveIncident} style={{ marginTop: 12, maxWidth: 720 }}>
              <input type="hidden" name="id" value={r.id} />
              <div style={inputCol}>
                <select name="kind" defaultValue={r.kind} title="Soort">
                  <option value="ongeval">Ongeval</option>
                  <option value="bijna_ongeval">Bijna-ongeval</option>
                </select>
                <input name="report_date" type="date" defaultValue={r.report_date ?? ""} title="Meldingsdatum" />
                <input name="reporter_name" defaultValue={r.reporter_name ?? ""} placeholder="Melder" />
                <CourseSelect value={r.course_code} />
                <input name="location" defaultValue={r.location ?? ""} placeholder="Locatie" />
                <select name="severity" defaultValue={r.severity ?? ""} title="Ernst">
                  <option value="">Ernst…</option>
                  <option value="laag">Laag</option>
                  <option value="middel">Middel</option>
                  <option value="hoog">Hoog</option>
                </select>
                <input name="owner" defaultValue={r.owner ?? ""} placeholder="Eigenaar" />
                <input name="due_date" type="date" defaultValue={r.due_date ?? ""} title="Streefdatum" />
                <StatusSelect value={r.status} />
                <input name="closed_date" type="date" defaultValue={r.closed_date ?? ""} title="Afgesloten op" />
              </div>
              <textarea name="description" defaultValue={r.description ?? ""} placeholder="Omschrijving" rows={2} style={{ ...taStyle, marginTop: 10 }} />
              <textarea name="immediate_action" defaultValue={r.immediate_action ?? ""} placeholder="Directe actie" rows={2} style={{ ...taStyle, marginTop: 10 }} />
              <textarea name="root_cause" defaultValue={r.root_cause ?? ""} placeholder="Oorzaakanalyse" rows={2} style={{ ...taStyle, marginTop: 10 }} />
              <textarea name="corrective_action" defaultValue={r.corrective_action ?? ""} placeholder="Corrigerende maatregel" rows={2} style={{ ...taStyle, marginTop: 10 }} />
              <button className="btn" type="submit" style={{ marginTop: 12 }}>Opslaan</button>
            </form>
          </details>
        ))}
      </div>
    </>
  );
}

/* ===================== KLACHTEN ===================== */
function ComplaintsView({ rows }: { rows: any[] }) {
  return (
    <>
      <div className="card">
        <details>
          <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>+ Nieuwe klacht</summary>
          <form action={saveComplaint} style={{ marginTop: 12, maxWidth: 720 }}>
            <div style={inputCol}>
              <input name="report_date" type="date" title="Meldingsdatum" />
              <input name="complainant" placeholder="Klager" />
              <CourseSelect />
              <input name="channel" placeholder="Kanaal (e-mail/telefoon/…)" />
              <input name="category" placeholder="Categorie" />
              <input name="owner" placeholder="Eigenaar" />
              <input name="due_date" type="date" title="Streefdatum" />
              <StatusSelect />
              <input name="closed_date" type="date" title="Afgesloten op" />
            </div>
            <textarea name="description" placeholder="Omschrijving" rows={2} style={{ ...taStyle, marginTop: 10 }} />
            <textarea name="action" placeholder="Afhandeling / maatregel" rows={2} style={{ ...taStyle, marginTop: 10 }} />
            <button className="btn" type="submit" style={{ marginTop: 12 }}>Opslaan</button>
          </form>
        </details>
      </div>

      <div className="card">
        <table>
          <thead>
            <tr><th>Ref</th><th>Datum</th><th>Klager</th><th>Opleiding</th><th>Categorie</th><th>Eigenaar</th><th>Status</th></tr>
          </thead>
          <tbody>
            {rows.length === 0 ? (
              <tr><td colSpan={7} className="muted small">Geen registraties.</td></tr>
            ) : rows.map((r) => {
              const st = qmsStatusBadge(r.status);
              return (
                <tr key={r.id}>
                  <td className="small">{r.ref ?? "—"}</td>
                  <td className="muted small">{fmtDate(r.report_date)}</td>
                  <td className="muted small">{r.complainant ?? "—"}</td>
                  <td className="muted small">{courseLabel(r.course_code)}</td>
                  <td className="muted small">{r.category ?? "—"}</td>
                  <td className="muted small">{r.owner ?? "—"}</td>
                  <td><span className={`badge ${st.cls}`}>{st.label}</span></td>
                </tr>
              );
            })}
          </tbody>
        </table>

        {rows.map((r) => (
          <details key={`e-${r.id}`} style={{ marginTop: 10, borderTop: "1px solid var(--line)", paddingTop: 10 }}>
            <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>
              {r.ref ?? "—"} · klacht bewerken
            </summary>
            <form action={saveComplaint} style={{ marginTop: 12, maxWidth: 720 }}>
              <input type="hidden" name="id" value={r.id} />
              <div style={inputCol}>
                <input name="report_date" type="date" defaultValue={r.report_date ?? ""} title="Meldingsdatum" />
                <input name="complainant" defaultValue={r.complainant ?? ""} placeholder="Klager" />
                <CourseSelect value={r.course_code} />
                <input name="channel" defaultValue={r.channel ?? ""} placeholder="Kanaal" />
                <input name="category" defaultValue={r.category ?? ""} placeholder="Categorie" />
                <input name="owner" defaultValue={r.owner ?? ""} placeholder="Eigenaar" />
                <input name="due_date" type="date" defaultValue={r.due_date ?? ""} title="Streefdatum" />
                <StatusSelect value={r.status} />
                <input name="closed_date" type="date" defaultValue={r.closed_date ?? ""} title="Afgesloten op" />
              </div>
              <textarea name="description" defaultValue={r.description ?? ""} placeholder="Omschrijving" rows={2} style={{ ...taStyle, marginTop: 10 }} />
              <textarea name="action" defaultValue={r.action ?? ""} placeholder="Afhandeling / maatregel" rows={2} style={{ ...taStyle, marginTop: 10 }} />
              <button className="btn" type="submit" style={{ marginTop: 12 }}>Opslaan</button>
            </form>
          </details>
        ))}
      </div>
    </>
  );
}

/* ===================== VERBETERINGEN ===================== */
function ImprovementsView({ rows }: { rows: any[] }) {
  return (
    <>
      <div className="card">
        <details>
          <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>+ Nieuwe verbetering (CAPA)</summary>
          <form action={saveImprovement} style={{ marginTop: 12, maxWidth: 720 }}>
            <div style={inputCol}>
              <input name="raised_date" type="date" title="Geregistreerd op" />
              <input name="source" placeholder="Bron (audit/feedback/incident/…)" />
              <CourseSelect />
              <select name="type" defaultValue="" title="Type">
                <option value="">Type…</option>
                <option value="correctief">Correctief</option>
                <option value="preventief">Preventief</option>
                <option value="verbetering">Verbetering</option>
              </select>
              <input name="owner" placeholder="Eigenaar" />
              <input name="due_date" type="date" title="Streefdatum" />
              <StatusSelect />
              <input name="closed_date" type="date" title="Afgesloten op" />
            </div>
            <textarea name="description" placeholder="Omschrijving" rows={2} style={{ ...taStyle, marginTop: 10 }} />
            <textarea name="action" placeholder="Actie / maatregel" rows={2} style={{ ...taStyle, marginTop: 10 }} />
            <textarea name="effectiveness_check" placeholder="Doeltreffendheidstoets" rows={2} style={{ ...taStyle, marginTop: 10 }} />
            <button className="btn" type="submit" style={{ marginTop: 12 }}>Opslaan</button>
          </form>
        </details>
      </div>

      <div className="card">
        <table>
          <thead>
            <tr><th>Ref</th><th>Datum</th><th>Bron</th><th>Opleiding</th><th>Type</th><th>Eigenaar</th><th>Status</th></tr>
          </thead>
          <tbody>
            {rows.length === 0 ? (
              <tr><td colSpan={7} className="muted small">Geen registraties.</td></tr>
            ) : rows.map((r) => {
              const st = qmsStatusBadge(r.status);
              return (
                <tr key={r.id}>
                  <td className="small">{r.ref ?? "—"}</td>
                  <td className="muted small">{fmtDate(r.raised_date)}</td>
                  <td className="muted small">{r.source ?? "—"}</td>
                  <td className="muted small">{courseLabel(r.course_code)}</td>
                  <td className="muted small">{improvementTypeLabel(r.type)}</td>
                  <td className="muted small">{r.owner ?? "—"}</td>
                  <td><span className={`badge ${st.cls}`}>{st.label}</span></td>
                </tr>
              );
            })}
          </tbody>
        </table>

        {rows.map((r) => (
          <details key={`e-${r.id}`} style={{ marginTop: 10, borderTop: "1px solid var(--line)", paddingTop: 10 }}>
            <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>
              {r.ref ?? "—"} · verbetering bewerken
            </summary>
            <form action={saveImprovement} style={{ marginTop: 12, maxWidth: 720 }}>
              <input type="hidden" name="id" value={r.id} />
              <div style={inputCol}>
                <input name="raised_date" type="date" defaultValue={r.raised_date ?? ""} title="Geregistreerd op" />
                <input name="source" defaultValue={r.source ?? ""} placeholder="Bron" />
                <CourseSelect value={r.course_code} />
                <select name="type" defaultValue={r.type ?? ""} title="Type">
                  <option value="">Type…</option>
                  <option value="correctief">Correctief</option>
                  <option value="preventief">Preventief</option>
                  <option value="verbetering">Verbetering</option>
                </select>
                <input name="owner" defaultValue={r.owner ?? ""} placeholder="Eigenaar" />
                <input name="due_date" type="date" defaultValue={r.due_date ?? ""} title="Streefdatum" />
                <StatusSelect value={r.status} />
                <input name="closed_date" type="date" defaultValue={r.closed_date ?? ""} title="Afgesloten op" />
              </div>
              <textarea name="description" defaultValue={r.description ?? ""} placeholder="Omschrijving" rows={2} style={{ ...taStyle, marginTop: 10 }} />
              <textarea name="action" defaultValue={r.action ?? ""} placeholder="Actie / maatregel" rows={2} style={{ ...taStyle, marginTop: 10 }} />
              <textarea name="effectiveness_check" defaultValue={r.effectiveness_check ?? ""} placeholder="Doeltreffendheidstoets" rows={2} style={{ ...taStyle, marginTop: 10 }} />
              <button className="btn" type="submit" style={{ marginTop: 12 }}>Opslaan</button>
            </form>
          </details>
        ))}
      </div>
    </>
  );
}
