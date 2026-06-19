import { createClient } from "@/lib/supabase/server";
import { fmtDate } from "@/lib/format";

export const dynamic = "force-dynamic";

function expiryStatus(expiry: string | null) {
  if (!expiry) return { cls: "idle", label: "—" };
  const days = Math.round((new Date(expiry).getTime() - Date.now()) / 86400000);
  if (days < 0) return { cls: "warn", label: "Verlopen" };
  if (days < 90) return { cls: "warn", label: "Verloopt < 90 dgn" };
  return { cls: "ok", label: "Geldig" };
}

export default async function IltInstructors() {
  const supabase = createClient();
  const { data } = await supabase
    .from("instructors")
    .select(`id, first_name, last_name, title, active,
       instructor_certificates ( id, cert_type, certificate_number, issuing_body, issued_date, expiry_date )`)
    .order("last_name");
  const instructors = (data as any[]) ?? [];

  return (
    <>
      <h1 className="page-title">Instructeurs</h1>
      <p className="page-sub">Kwalificaties met certificaatnummer en geldigheid (alleen-lezen).</p>

      {instructors.map((ins) => (
        <div className="card" key={ins.id}>
          <h2>
            {ins.first_name} {ins.last_name}
            {ins.title ? <span className="muted small"> · {ins.title}</span> : null}
          </h2>
          <table>
            <thead>
              <tr><th>Kwalificatie</th><th>Nummer</th><th>Instantie</th><th>Afgegeven</th><th>Geldig t/m</th><th>Status</th></tr>
            </thead>
            <tbody>
              {(ins.instructor_certificates ?? []).length === 0 ? (
                <tr><td colSpan={6} className="muted small">Geen kwalificaties vastgelegd.</td></tr>
              ) : (
                (ins.instructor_certificates ?? []).map((c: any) => {
                  const st = expiryStatus(c.expiry_date);
                  return (
                    <tr key={c.id}>
                      <td>{c.cert_type}</td>
                      <td className="muted small">{c.certificate_number ?? "—"}</td>
                      <td className="muted small">{c.issuing_body ?? "—"}</td>
                      <td className="muted small">{fmtDate(c.issued_date)}</td>
                      <td className="muted small">{fmtDate(c.expiry_date)}</td>
                      <td><span className={`badge ${st.cls}`}>{st.label}</span></td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      ))}
    </>
  );
}
