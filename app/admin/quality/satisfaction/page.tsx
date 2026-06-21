import { createClient } from "@/lib/supabase/server";
import { fmtDate } from "@/lib/format";
import { t } from "@/lib/i18n";
import { saveSatisfaction } from "./actions";

export const dynamic = "force-dynamic";

export default async function SatisfactionPage() {
  const T = t();
  const supabase = createClient();
  const { data } = await supabase
    .from("qms_satisfaction")
    .select("id, course_code, period, survey_date, respondents, avg_score, comments")
    .order("survey_date", { ascending: false });
  const rows = (data as any[]) ?? [];
  const scored = rows.filter((r) => r.avg_score != null);
  const overall = scored.length
    ? (scored.reduce((s, r) => s + Number(r.avg_score), 0) / scored.length).toFixed(1)
    : "—";
  const meets = overall !== "—" && Number(overall) >= 4.2;

  return (
    <>
      <h1 className="page-title">{T.sat_title}</h1>
      <p className="page-sub">{T.sat_sub}</p>

      <div className="kpis">
        <div className="kpi"><div className="kpi-value" style={{ color: meets ? "var(--ok)" : undefined }}>{overall}</div><div className="kpi-label">{T.sat_overall}</div></div>
        <div className="kpi"><div className="kpi-value">4,2</div><div className="kpi-label">{T.sat_target}</div></div>
        <div className="kpi"><div className="kpi-value">{rows.length}</div><div className="kpi-label">{T.sat_respondents}</div></div>
      </div>

      <div className="card">
        <details>
          <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>{T.sat_add}</summary>
          <form action={saveSatisfaction} style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, marginTop: 12, maxWidth: 640 }}>
            <select name="course_code" defaultValue="" title={T.course}>
              <option value="">{T.course}…</option>
              <option value="BM-I">BM-I</option><option value="BM-II">BM-II</option><option value="BM-III">BM-III</option>
            </select>
            <input name="period" placeholder={T.sat_period} />
            <input name="survey_date" type="date" title={T.sat_surveydate} />
            <input name="respondents" type="number" min="0" placeholder={T.sat_respondents} />
            <input name="avg_score" type="number" min="1" max="5" step="0.1" placeholder={T.sat_score_ph} />
            <button className="btn" type="submit">{T.save}</button>
            <textarea name="comments" placeholder={T.sat_comments} rows={2}
              style={{ gridColumn: "1 / -1", fontFamily: "inherit", fontSize: 14, padding: 8, borderRadius: 8, border: "1px solid var(--line)" }} />
          </form>
        </details>
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
