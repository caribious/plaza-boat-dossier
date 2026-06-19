import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function IltAudit() {
  const supabase = createClient();
  const { data } = await supabase
    .from("audit_log")
    .select("action, table_name, record_id, changed_by_email, changed_at")
    .order("changed_at", { ascending: false })
    .limit(200);

  const rows = (data as any[]) ?? [];

  return (
    <>
      <h1 className="page-title">Audit-log</h1>
      <p className="page-sub">
        Onveranderbaar spoor van alle wijzigingen (laatste 200). Wie wijzigde wat, wanneer.
      </p>

      <div className="card">
        <table>
          <thead>
            <tr><th>Wanneer</th><th>Actie</th><th>Tabel</th><th>Record</th><th>Door</th></tr>
          </thead>
          <tbody>
            {rows.map((a, i) => (
              <tr key={i}>
                <td className="muted small">{new Date(a.changed_at).toLocaleString("nl-NL")}</td>
                <td className="muted small">{a.action}</td>
                <td className="muted small">{a.table_name}</td>
                <td className="muted small">{a.record_id?.slice(0, 8)}</td>
                <td className="muted small">{a.changed_by_email ?? "systeem"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
