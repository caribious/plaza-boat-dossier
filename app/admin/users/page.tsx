import { createClient } from "@/lib/supabase/server";
import { getProfile } from "@/lib/getProfile";
import { t } from "@/lib/i18n";
import InviteUser from "@/components/InviteUser";
import CreateUserPw from "@/components/CreateUserPw";

export const dynamic = "force-dynamic";

export default async function UsersPage() {
  const T = t();
  const profile = await getProfile();
  if (profile?.role !== "admin") {
    return <div className="card"><p className="muted small">{T.us_admin_only}</p></div>;
  }
  const supabase = createClient();
  const { data } = await supabase.from("profiles").select("id, full_name, email, role").order("role");
  const rows = (data as any[]) ?? [];
  const roleLabel = (r: string) => r === "admin" ? T.role_admin : r === "instructor" ? T.role_instructor : r === "auditor" ? T.role_auditor : T.role_student;
  const labels = { name: T.us_name, email: T.us_email, send: T.us_send, sent: T.us_sent,
    admin: T.role_admin, instructor: T.role_instructor, auditor: T.role_auditor, student: T.role_student };

  return (
    <>
      <h1 className="page-title">{T.us_title}</h1>
      <p className="page-sub">{T.us_sub}</p>

      <div className="card">
        <h2>{T.us_invite}</h2>
        <InviteUser labels={labels} />
        <p className="small muted" style={{ marginTop: 10 }}>{T.us_note}</p>
      </div>

      <div className="card">
        <h2>{T.us_create_pw}</h2>
        <CreateUserPw labels={labels} />
      </div>

      <div className="card">
        <h2>{T.us_existing}</h2>
        <table>
          <thead><tr><th>{T.us_name}</th><th>{T.us_email}</th><th>{T.us_role}</th></tr></thead>
          <tbody>
            {rows.length === 0 ? <tr><td colSpan={3} className="muted small">{T.us_none}</td></tr> :
              rows.map((r) => (
                <tr key={r.id}>
                  <td>{r.full_name || "—"}</td>
                  <td className="muted small">{r.email || "—"}</td>
                  <td><span className="badge idle">{roleLabel(r.role)}</span></td>
                </tr>
              ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
