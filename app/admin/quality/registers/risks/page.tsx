import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import {
  fmtDate,
  qmsStatusBadge,
  riskScoreBadge,
  riskResponseLabel,
  courseLabel,
} from "@/lib/format";
import { t } from "@/lib/i18n";
import { saveRisk } from "./actions";

export const dynamic = "force-dynamic";

type Search = { status?: string };

const COURSE_OPTS = [
  { v: "", labelKey: "na" as const },
  { v: "BM-I", label: "BM-I" },
  { v: "BM-II", label: "BM-II" },
  { v: "BM-III", label: "BM-III" },
];

const LIKERT = [1, 2, 3, 4, 5];

function CourseSelect({ value }: { value?: string | null }) {
  const T = t();
  return (
    <select name="course_code" defaultValue={value ?? ""} title={T.risk_course_title}>
      {COURSE_OPTS.map((o) => (
        <option key={o.v} value={o.v}>{"labelKey" in o ? T.risk_course_na : o.label}</option>
      ))}
    </select>
  );
}

function StatusSelect({ value }: { value?: string | null }) {
  const T = t();
  return (
    <select name="status" defaultValue={value ?? "open"} title={T.risk_status_title}>
      <option value="open">{T.kpi_open}</option>
      <option value="in_behandeling">{T.kpi_in_progress}</option>
      <option value="gesloten">{T.kpi_closed}</option>
    </select>
  );
}

function LikertSelect({ name, value, label }: { name: string; value?: number | null; label: string }) {
  return (
    <select name={name} defaultValue={value != null ? String(value) : ""} title={label}>
      <option value="">{label}…</option>
      {LIKERT.map((n) => (
        <option key={n} value={n}>{n}</option>
      ))}
    </select>
  );
}

function ResponseSelect({ value }: { value?: string | null }) {
  const T = t();
  return (
    <select name="response" defaultValue={value ?? ""} title={T.risk_response_title}>
      <option value="">{T.risk_f_response}…</option>
      <option value="vermijden">{T.risk_resp_avoid}</option>
      <option value="beperken">{T.risk_resp_mitigate}</option>
      <option value="delen">{T.risk_resp_share}</option>
      <option value="accepteren">{T.risk_resp_accept}</option>
    </select>
  );
}

const inputCol: React.CSSProperties = { display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 };
const taStyle: React.CSSProperties = {
  width: "100%", fontFamily: "inherit", fontSize: 14, padding: 8,
  borderRadius: 8, border: "1px solid var(--line)",
};

function RiskForm({ r }: { r?: any }) {
  const T = t();
  return (
    <form action={saveRisk} style={{ marginTop: 12, maxWidth: 720 }}>
      {r?.id && <input type="hidden" name="id" value={r.id} />}
      <div style={inputCol}>
        <input name="raised_date" type="date" defaultValue={r?.raised_date ?? ""} title={T.risk_f_raised} />
        <input name="context" defaultValue={r?.context ?? ""} placeholder={T.risk_f_context} />
        <CourseSelect value={r?.course_code} />
        <input name="category" defaultValue={r?.category ?? ""} placeholder={T.risk_f_category} />
        <LikertSelect name="likelihood" value={r?.likelihood} label={T.risk_f_likelihood} />
        <LikertSelect name="impact" value={r?.impact} label={T.risk_f_impact} />
        <ResponseSelect value={r?.response} />
        <input name="owner" defaultValue={r?.owner ?? ""} placeholder={T.risk_f_owner} />
        <input name="due_date" type="date" defaultValue={r?.due_date ?? ""} title={T.risk_f_due} />
        <StatusSelect value={r?.status} />
        <input name="closed_date" type="date" defaultValue={r?.closed_date ?? ""} title={T.risk_f_closed} />
      </div>
      <textarea name="description" defaultValue={r?.description ?? ""} placeholder={T.risk_f_desc} rows={2} style={{ ...taStyle, marginTop: 10 }} />
      <textarea name="action" defaultValue={r?.action ?? ""} placeholder={T.risk_f_action} rows={2} style={{ ...taStyle, marginTop: 10 }} />
      <p className="muted small" style={{ margin: "8px 0 0" }}>{T.risk_f_note}</p>
      <button className="btn" type="submit" style={{ marginTop: 12 }}>{T.save}</button>
    </form>
  );
}

export default async function QmsRisks({ searchParams }: { searchParams: Search }) {
  const T = t();
  const status = searchParams.status ?? "";
  const supabase = createClient();

  const STATUS_FILTERS = [
    { key: "", label: T.st_all },
    { key: "open", label: T.kpi_open },
    { key: "in_behandeling", label: T.kpi_in_progress },
    { key: "gesloten", label: T.kpi_closed },
  ];

  let q = supabase.from("qms_risks").select("*").order("score", { ascending: false, nullsFirst: false }).order("created_at", { ascending: false });
  if (status) q = q.eq("status", status);
  const { data } = await q;
  const rows = (data as any[]) ?? [];

  const href = (s: string) =>
    `/admin/quality/registers/risks${s ? `?status=${s}` : ""}`;

  return (
    <>
      <h1 className="page-title">{T.risk_title}</h1>
      <p className="page-sub">{T.risk_sub}</p>
      <p className="small" style={{ marginTop: -6 }}>
        <Link href="/admin/quality/kpi">{T.risk_to_kpi}</Link>
        {" · "}
        <Link href="/admin/quality/registers">{T.risk_to_registers}</Link>
      </p>

      {/* Statusfilter */}
      <div className="card" style={{ display: "flex", gap: 8, flexWrap: "wrap", alignItems: "center" }}>
        <span className="muted small">{T.risk_filter}</span>
        {STATUS_FILTERS.map((s) => (
          <Link key={s.key} href={href(s.key)} className={`btn sm${status === s.key ? "" : " ghost"}`}>
            {s.label}
          </Link>
        ))}
      </div>

      {/* Nieuw risico */}
      <div className="card">
        <details>
          <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>
            {T.risk_new}
          </summary>
          <RiskForm />
        </details>
      </div>

      {/* Tabel */}
      <div className="card">
        <table>
          <thead>
            <tr>
              <th>{T.ref}</th>
              <th>{T.date}</th>
              <th>{T.risk_col_risk}</th>
              <th>{T.course}</th>
              <th>{T.risk_col_category}</th>
              <th>{T.risk_col_wi}</th>
              <th>{T.risk_col_score}</th>
              <th>{T.risk_col_response}</th>
              <th>{T.owner}</th>
              <th>{T.status}</th>
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 ? (
              <tr><td colSpan={10} className="muted small">{T.risk_none}</td></tr>
            ) : rows.map((r) => {
              const st = qmsStatusBadge(r.status);
              const sc = riskScoreBadge(r.score);
              return (
                <tr key={r.id}>
                  <td className="small">{r.ref ?? "—"}</td>
                  <td className="muted small">{fmtDate(r.raised_date)}</td>
                  <td className="small">{r.description ?? "—"}</td>
                  <td className="muted small">{courseLabel(r.course_code)}</td>
                  <td className="muted small">{r.category ?? "—"}</td>
                  <td className="muted small">
                    {r.likelihood ?? "—"} × {r.impact ?? "—"}
                  </td>
                  <td><span className={`badge ${sc.cls}`}>{sc.label}</span></td>
                  <td className="muted small">{riskResponseLabel(r.response)}</td>
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
              {r.ref ?? "—"} · {T.risk_edit}
            </summary>
            <RiskForm r={r} />
          </details>
        ))}
      </div>
    </>
  );
}
