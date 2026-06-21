import { createClient } from "@/lib/supabase/server";
import { getLocale, t } from "@/lib/i18n";

export const dynamic = "force-dynamic";

export default async function IltAudit() {
  const T = t();
  const loc = getLocale() === "en" ? "en-GB" : "nl-NL";
  const supabase = createClient();
  const { data } = await supabase
    .from("audit_log")
    .select("action, table_name, record_id, changed_by_email, changed_at")
    .order("changed_at", { ascending: false })
    .limit(200);
  const rows = (data as any[]) ?? [];

  return (
    <>
      <h1 className="page-title">{T.ila_title}</h1>
      <p className="page-sub">{T.ila_sub}</p>

      <div className="card">
        <table>
          <thead>
            <tr><th>{T.ila_when}</th><th>{T.ila_action}</th><th>{T.ila_table}</th><th>{T.ila_record}</th><th>{T.ila_by}</th></tr>
          </thead>
          <tbody>
            {rows.map((a, i) => (
              <tr key={i}>
                <td className="muted small">{new Date(a.changed_at).toLocaleString(loc)}</td>
                <td className="muted small">{a.action}</td>
                <td className="muted small">{a.table_name}</td>
                <td className="muted small">{a.record_id?.slice(0, 8)}</td>
                <td className="muted small">{a.changed_by_email ?? T.ila_system}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
