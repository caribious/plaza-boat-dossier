import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fmtDate } from "@/lib/format";
import { saveReview, completeReview } from "./actions";

export const dynamic = "force-dynamic";

function kindLabel(k: string) {
  return k === "directiebeoordeling" ? "Directiebeoordeling (§9.3)" : "Interne audit (§9.2)";
}
function statusBadge(s: string) {
  if (s === "afgerond") return { cls: "ok", label: "Afgerond" };
  if (s === "uitgevoerd") return { cls: "warn", label: "Uitgevoerd" };
  return { cls: "idle", label: "Gepland" };
}
const td = new Date().toISOString().slice(0, 10);

export default async function ReviewsPage() {
  const supabase = createClient();
  const { data } = await supabase
    .from("qms_reviews")
    .select("id, ref, kind, planned_date, completed_date, scope, summary, owner, status")
    .order("planned_date", { ascending: false });
  const rows = (data as any[]) ?? [];

  return (
    <>
      <h1 className="page-title">Audit &amp; directiebeoordeling</h1>
      <p className="page-sub">
        Plan, voer uit en vink af: de jaarlijkse interne audit (IA-01, §9.2) en directiebeoordeling
        (MR-01, §9.3). Afgevinkte rondes voeden automatisch de herinneringen op de{" "}
        <Link href="/admin/quality/agenda">QMS-agenda</Link>.
      </p>

      <div className="card">
        <h2>Nieuwe ronde plannen</h2>
        <form action={saveReview} style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, maxWidth: 620 }}>
          <select name="kind" required>
            <option value="interne_audit">Interne audit (§9.2)</option>
            <option value="directiebeoordeling">Directiebeoordeling (§9.3)</option>
          </select>
          <input name="planned_date" type="date" title="Geplande datum" />
          <input name="owner" placeholder="Eigenaar (bv. Johan Duits)" />
          <input name="scope" placeholder="Scope (bv. volledig QMS + BM I/II/III)" />
          <button className="btn" type="submit">Plannen</button>
        </form>
      </div>

      <div className="card">
        <h2>Rondes</h2>
        <table>
          <thead>
            <tr><th>Ref</th><th>Type</th><th>Gepland</th><th>Uitgevoerd</th><th>Eigenaar</th><th>Status</th><th></th></tr>
          </thead>
          <tbody>
            {rows.length === 0 ? (
              <tr><td colSpan={7} className="muted small">Nog geen audit of beoordeling gepland.</td></tr>
            ) : rows.map((r) => {
              const st = statusBadge(r.status);
              return (
                <tr key={r.id}>
                  <td className="muted small">{r.ref ?? "—"}</td>
                  <td>{kindLabel(r.kind)}{r.scope ? <span className="muted small"> · {r.scope}</span> : null}
                    {r.summary ? <div className="muted small" style={{ marginTop: 4 }}>Conclusie: {r.summary}</div> : null}</td>
                  <td className="muted small">{fmtDate(r.planned_date)}</td>
                  <td className="muted small">{fmtDate(r.completed_date)}</td>
                  <td className="muted small">{r.owner ?? "—"}</td>
                  <td><span className={`badge ${st.cls}`}>{st.label}</span></td>
                  <td>
                    {r.status !== "afgerond" ? (
                      <details>
                        <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>Afvinken</summary>
                        <form action={completeReview} style={{ display: "grid", gap: 6, marginTop: 8, minWidth: 240 }}>
                          <input type="hidden" name="id" value={r.id} />
                          <input name="completed_date" type="date" defaultValue={td} title="Datum uitgevoerd" />
                          <textarea name="summary" placeholder="Conclusies / besluiten" rows={3}
                            style={{ fontFamily: "inherit", fontSize: 14, padding: 8, borderRadius: 8, border: "1px solid var(--line)" }} />
                          <button className="btn sm" type="submit">Markeer afgerond</button>
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
