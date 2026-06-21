import { createClient } from "@/lib/supabase/server";
import { fmtDate } from "@/lib/format";
import { t } from "@/lib/i18n";

export const dynamic = "force-dynamic";

export default async function IltSatisfaction() {
  const T = t();
  const supabase = createClient();
  const { data } = await supabase
    .from("qms_satisfaction")
    .select("id, course_code, period, survey_date, respondents, avg_score, comments")
    .order("survey_date", { ascending: false });
  const rows = (data as any[]) ?? [];
  const scored = rows.filter((r) => r.avg_score != null);
  const overall = scored.length ? (scored.reduce((s, r) => s + Number(r.avg_score), 0) / scored.length).toFixed(1) : "—";

  return (
    <>
      <h1 className="page-title">{T.sat_title}</h1>
      <p className="page-sub">{T.sat_readonly}</p>
      <div className="kpis">
        <div className="kpi"><div className="kpi-value">{overall}</div><div className="kpi-label">{T.sat_overall}</div></div>
        <div className="kpi"><div className="kpi-value">4,2</div><div className="kpi-label">{T.sat_target}</div></div>
      </div>
      <div className="card">
        <table>
          <thead><tr><th>{T.sat_surveydate}</th><th>{T.course}</th><th>{T.sat_period}</th><th>{T.sat_respondents}</th><th>{T.sat_avg}</th><th>{T.sat_comments}</th></tr></thead>
          <tbody>
            {rows.length === 0 ? <tr><td colSpan={6} className="muted small">{T.sat_none}</td></tr> : rows.map((r) => (
              <tr key={r.id}>
                <td className="muted small">{fmtDate(r.survey_date)}</td>
                <td className="muted small">{r.course_code ?? "—"}</td>
                <td className="muted small">{r.period ?? "—"}</td>
                <td className="muted small">{r.respondents ?? "—"}</td>
                <td><span className={`badge ${r.avg_score != null && Number(r.avg_score) >= 4.2 ? "ok" : "warn"}`}>{r.avg_score != null ? Number(r.avg_score).toFixed(1) : "—"}</span></td>
                <td className="muted small">{r.comments ?? "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
