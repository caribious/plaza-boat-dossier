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

export const dynamic = "force-dynamic";

export default async function IltQmsRisks() {
  const T = t();
  const supabase = createClient();
  const { data } = await supabase
    .from("qms_risks")
    .select("*")
    .order("score", { ascending: false, nullsFirst: false })
    .order("created_at", { ascending: false });
  const rows = (data as any[]) ?? [];

  return (
    <>
      <h1 className="page-title">{T.risk_title_ro}</h1>
      <p className="page-sub">{T.risk_sub_ro}</p>
      <p className="small" style={{ marginTop: -6 }}>
        <Link href="/ilt/quality/registers">{T.risk_to_registers}</Link>
      </p>

      <div className="card">
        <h2>{T.risk_heading} ({rows.length})</h2>
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
              <th>{T.risk_col_duedate}</th>
              <th>{T.status}</th>
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 ? (
              <tr><td colSpan={11} className="muted small">{T.risk_none}</td></tr>
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
                  <td className="muted small">{r.likelihood ?? "—"} × {r.impact ?? "—"}</td>
                  <td><span className={`badge ${sc.cls}`}>{sc.label}</span></td>
                  <td className="muted small">{riskResponseLabel(r.response)}</td>
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
