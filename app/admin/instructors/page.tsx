import { createClient } from "@/lib/supabase/server";
import { fmtDate } from "@/lib/format";
import { addInstructor, addInstructorCertificate, uploadInstructorCertFile } from "./actions";
import { createInstructorLogin } from "@/app/admin/account-actions";
import CreateLogin from "@/components/CreateLogin";

export const dynamic = "force-dynamic";

// Geldigheidsstatus van een instructeurcertificaat.
function expiryStatus(expiry: string | null) {
  if (!expiry) return { cls: "idle", label: "—" };
  const d = new Date(expiry).getTime();
  const now = Date.now();
  const days = Math.round((d - now) / 86400000);
  if (days < 0) return { cls: "warn", label: "Verlopen" };
  if (days < 90) return { cls: "warn", label: `Verloopt < 90 dgn` };
  return { cls: "ok", label: "Geldig" };
}

export default async function Instructors() {
  const supabase = createClient();
  const { data } = await supabase
    .from("instructors")
    .select(
      `id, first_name, last_name, title, email, active, profile_id,
       instructor_certificates ( id, cert_type, certificate_number, issuing_body, issued_date, expiry_date, file_path )`
    )
    .order("last_name");

  const instructors = (data as any[]) ?? [];

  // Signed download-links voor geüploade certificaat-PDF's
  const signed: Record<string, string> = {};
  for (const ins of instructors) {
    for (const c of ins.instructor_certificates ?? []) {
      if (c.file_path) {
        const { data: s } = await supabase.storage
          .from("instructor-certificates")
          .createSignedUrl(c.file_path, 3600);
        if (s?.signedUrl) signed[c.id] = s.signedUrl;
      }
    }
  }

  return (
    <>
      <h1 className="page-title">Instructeurs</h1>
      <p className="page-sub">
        Personeels-/instructeurregister met kwalificaties en geldigheid (ILT component 5).
      </p>

      <div className="card">
        <details>
          <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>
            + Instructeur toevoegen
          </summary>
          <form action={addInstructor} style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, marginTop: 12, maxWidth: 560 }}>
            <input name="first_name" placeholder="Voornaam" required />
            <input name="last_name" placeholder="Achternaam" required />
            <input name="title" placeholder="Functie/titel (bv. RYA Chief Instructor)" />
            <input name="email" placeholder="E-mail" />
            <input name="phone" placeholder="Telefoon" />
            <button className="btn" type="submit">Opslaan</button>
          </form>
        </details>
      </div>

      {instructors.length === 0 && (
        <div className="card">
          <p className="muted small">Nog geen instructeurs. Voer <code>seed-demo.sql</code> uit of voeg er hierboven een toe.</p>
        </div>
      )}

      {instructors.map((ins) => (
        <div className="card" key={ins.id}>
          <h2>
            {ins.first_name} {ins.last_name}
            {ins.title ? <span className="muted small"> · {ins.title}</span> : null}
            {!ins.active ? <span className="badge idle" style={{ marginLeft: 8 }}>Inactief</span> : null}
          </h2>
          <p className="muted small" style={{ marginTop: -8 }}>{ins.email ?? ""}</p>

          <div style={{ marginBottom: 12 }}>
            <span className="flabel">Toegang tot portal</span>
            {ins.profile_id ? (
              <span className="badge ok">Inlog actief{ins.email ? ` · ${ins.email}` : ""}</span>
            ) : (
              <CreateLogin
                action={createInstructorLogin}
                recordId={ins.id}
                idField="instructor_id"
                defaultEmail={ins.email}
              />
            )}
          </div>

          <table>
            <thead>
              <tr><th>Kwalificatie</th><th>Nummer</th><th>Instantie</th><th>Afgegeven</th><th>Geldig t/m</th><th>Status</th><th>PDF</th></tr>
            </thead>
            <tbody>
              {(ins.instructor_certificates ?? []).length === 0 ? (
                <tr><td colSpan={7} className="muted small">Nog geen kwalificaties vastgelegd.</td></tr>
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
                      <td>
                        {signed[c.id] ? (
                          <a className="small" href={signed[c.id]} target="_blank" rel="noreferrer">Download</a>
                        ) : (
                          <form action={uploadInstructorCertFile} encType="multipart/form-data" style={{ display: "flex", gap: 6 }}>
                            <input type="hidden" name="instructor_id" value={ins.id} />
                            <input type="hidden" name="certificate_id" value={c.id} />
                            <input type="file" name="file" accept="application/pdf" className="small" required />
                            <button className="btn sm" type="submit">Upload</button>
                          </form>
                        )}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>

          <details style={{ marginTop: 12 }}>
            <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>
              + Kwalificatie toevoegen
            </summary>
            <form action={addInstructorCertificate} style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 10, marginTop: 12 }}>
              <input type="hidden" name="instructor_id" value={ins.id} />
              <input name="cert_type" placeholder="Type (bv. RYA Powerboat Instructor)" required />
              <input name="certificate_number" placeholder="Certificaatnummer" />
              <input name="issuing_body" placeholder="Instantie (RYA/MCA)" />
              <input name="issued_date" type="date" title="Afgiftedatum" />
              <input name="expiry_date" type="date" title="Geldig t/m" />
              <button className="btn" type="submit">Opslaan</button>
            </form>
          </details>
        </div>
      ))}
    </>
  );
}
