import { createClient } from "@/lib/supabase/server";
import { fmtDate } from "@/lib/format";
import { t } from "@/lib/i18n";
import { addInstructor, addInstructorCertificate, uploadInstructorCertFile } from "./actions";
import { createInstructorLogin } from "@/app/admin/account-actions";
import CreateLogin from "@/components/CreateLogin";

export const dynamic = "force-dynamic";

export default async function Instructors() {
  const T = t();
  function expiryStatus(expiry: string | null) {
    if (!expiry) return { cls: "idle", label: "—" };
    const days = Math.round((new Date(expiry).getTime() - Date.now()) / 86400000);
    if (days < 0) return { cls: "warn", label: T.exp_expired };
    if (days < 90) return { cls: "warn", label: T.exp_soon };
    return { cls: "ok", label: T.exp_valid };
  }

  const supabase = createClient();
  const { data } = await supabase
    .from("instructors")
    .select(`id, first_name, last_name, title, email, active, profile_id,
       instructor_certificates ( id, cert_type, certificate_number, issuing_body, issued_date, expiry_date, file_path )`)
    .order("last_name");
  const instructors = (data as any[]) ?? [];

  const signed: Record<string, string> = {};
  for (const ins of instructors) {
    for (const c of ins.instructor_certificates ?? []) {
      if (c.file_path) {
        const { data: s } = await supabase.storage.from("instructor-certificates").createSignedUrl(c.file_path, 3600);
        if (s?.signedUrl) signed[c.id] = s.signedUrl;
      }
    }
  }

  return (
    <>
      <h1 className="page-title">{T.in_title}</h1>
      <p className="page-sub">{T.in_sub}</p>

      <div className="card">
        <details>
          <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>{T.in_add}</summary>
          <form action={addInstructor} style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, marginTop: 12, maxWidth: 560 }}>
            <input name="first_name" placeholder={T.in_fn} required />
            <input name="last_name" placeholder={T.in_ln} required />
            <input name="title" placeholder={T.in_func} />
            <input name="email" placeholder={T.in_email} />
            <input name="phone" placeholder={T.in_phone} />
            <button className="btn" type="submit">{T.save}</button>
          </form>
        </details>
      </div>

      {instructors.length === 0 && (
        <div className="card"><p className="muted small">{T.in_none}</p></div>
      )}

      {instructors.map((ins) => (
        <div className="card" key={ins.id}>
          <h2>
            {ins.first_name} {ins.last_name}
            {ins.title ? <span className="muted small"> · {ins.title}</span> : null}
            {!ins.active ? <span className="badge idle" style={{ marginLeft: 8 }}>{T.in_inactive}</span> : null}
          </h2>
          <p className="muted small" style={{ marginTop: -8 }}>{ins.email ?? ""}</p>

          <div style={{ marginBottom: 12 }}>
            <span className="flabel">{T.in_portal}</span>
            {ins.profile_id ? (
              <span className="badge ok">{T.in_login_active}{ins.email ? ` · ${ins.email}` : ""}</span>
            ) : (
              <CreateLogin action={createInstructorLogin} recordId={ins.id} idField="instructor_id" defaultEmail={ins.email} />
            )}
          </div>

          <table>
            <thead>
              <tr><th>{T.in_qual}</th><th>{T.in_number}</th><th>{T.in_body}</th><th>{T.in_issued}</th><th>{T.in_validuntil}</th><th>{T.status}</th><th>{T.q_pdf}</th></tr>
            </thead>
            <tbody>
              {(ins.instructor_certificates ?? []).length === 0 ? (
                <tr><td colSpan={7} className="muted small">{T.in_noqual}</td></tr>
              ) : (ins.instructor_certificates ?? []).map((c: any) => {
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
                        <a className="small" href={signed[c.id]} target="_blank" rel="noreferrer">{T.q_download}</a>
                      ) : (
                        <form action={uploadInstructorCertFile} encType="multipart/form-data" style={{ display: "flex", gap: 6 }}>
                          <input type="hidden" name="instructor_id" value={ins.id} />
                          <input type="hidden" name="certificate_id" value={c.id} />
                          <input type="file" name="file" accept="application/pdf" className="small" required />
                          <button className="btn sm" type="submit">{T.q_upload}</button>
                        </form>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>

          <details style={{ marginTop: 12 }}>
            <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>{T.in_add_qual}</summary>
            <form action={addInstructorCertificate} style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 10, marginTop: 12 }}>
              <input type="hidden" name="instructor_id" value={ins.id} />
              <input name="cert_type" placeholder={T.in_cert_type} required />
              <input name="certificate_number" placeholder={T.in_cert_num} />
              <input name="issuing_body" placeholder={T.in_cert_body} />
              <input name="issued_date" type="date" title={T.in_issued} />
              <input name="expiry_date" type="date" title={T.in_validuntil} />
              <button className="btn" type="submit">{T.save}</button>
            </form>
          </details>
        </div>
      ))}
    </>
  );
}
