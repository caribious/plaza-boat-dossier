import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fmtDate } from "@/lib/format";
import { t } from "@/lib/i18n";
import { saveReview, completeReview } from "./actions";

export const dynamic = "force-dynamic";
const td = new Date().toISOString().slice(0, 10);

export default async function ReviewsPage() {
  const T = t();
  const kindLabel = (k: string) => (k === "directiebeoordeling" ? T.rv_mgmt : T.rv_internal);
  const statusBadge = (s: string) =>
    s === "afgerond" ? { cls: "ok", label: T.rv_finished }
    : s === "uitgevoerd" ? { cls: "warn", label: T.rv_done }
    : { cls: "idle", label: T.rv_planned };

  const supabase = createClient();
  const { data } = await supabase
    .from("qms_reviews")
    .select("id, ref, kind, planned_date, completed_date, scope, summary, owner, status")
    .order("planned_date", { ascending: false });
  const rows = (data as any[]) ?? [];

  return (
    <>
      <h1 className="page-title">{T.rv_title}</h1>
      <p className="page-sub">
        {T.rv_sub_a}<Link href="/admin/quality/agenda">{T.rv_sub_b}</Link>.
      </p>

      <div className="card">
        <h2>{T.rv_plan}</h2>
        <form action={saveReview} style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, maxWidth: 620 }}>
          <select name="kind" required>
            <option value="interne_audit">{T.rv_internal}</option>
            <option value="directiebeoordeling">{T.rv_mgmt}</option>
          </select>
          <input name="planned_date" type="date" title={T.rv_col_planned} />
          <input name="owner" placeholder={T.rv_owner_ph} />
          <input name="scope" placeholder={T.rv_scope_ph} />
          <button className="btn" type="submit">{T.rv_planbtn}</button>
        </form>
      </div>

      <div className="card">
        <h2>{T.rv_rounds}</h2>
        <table>
          <thead>
            <tr><th>{T.ref}</th><th>{T.rv_col_type}</th><th>{T.rv_col_planned}</th><th>{T.rv_col_done}</th><th>{T.owner}</th><th>{T.status}</th><th></th></tr>
          </thead>
          <tbody>
            {rows.length === 0 ? (
              <tr><td colSpan={7} className="muted small">{T.rv_none}</td></tr>
            ) : rows.map((r) => {
              const st = statusBadge(r.status);
              return (
                <tr key={r.id}>
                  <td className="muted small">{r.ref ?? "—"}</td>
                  <td>{kindLabel(r.kind)}{r.scope ? <span className="muted small"> · {r.scope}</span> : null}
                    {r.summary ? <div className="muted small" style={{ marginTop: 4 }}>{T.rv_concl}: {r.summary}</div> : null}</td>
                  <td className="muted small">{fmtDate(r.planned_date)}</td>
                  <td className="muted small">{fmtDate(r.completed_date)}</td>
                  <td className="muted small">{r.owner ?? "—"}</td>
                  <td><span className={`badge ${st.cls}`}>{st.label}</span></td>
                  <td>
                    {r.status !== "afgerond" ? (
                      <details>
                        <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>{T.rv_check}</summary>
                        <form action={completeReview} style={{ display: "grid", gap: 6, marginTop: 8, minWidth: 240 }}>
                          <input type="hidden" name="id" value={r.id} />
                          <input name="completed_date" type="date" defaultValue={td} title={T.rv_col_done} />
                          <textarea name="summary" placeholder={T.rv_decisions_ph} rows={3}
                            style={{ fontFamily: "inherit", fontSize: 14, padding: 8, borderRadius: 8, border: "1px solid var(--line)" }} />
                          <button className="btn sm" type="submit">{T.rv_markdone}</button>
                        </form>
                      </details>
                    ) : <span className="muted small">—</span>}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </>
  );
}
