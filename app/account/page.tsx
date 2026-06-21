import Link from "next/link";
import { redirect } from "next/navigation";
import { getProfile } from "@/lib/getProfile";
import TopBar from "@/components/TopBar";
import Footer from "@/components/Footer";
import ChangePasswordForm from "@/components/ChangePasswordForm";
import { t } from "@/lib/i18n";

export const dynamic = "force-dynamic";

export default async function AccountPage() {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  const T = t();
  const home = profile.role === "student" ? "/student" : "/admin";
  const roleLabel = profile.role === "student" ? T.role_student : profile.role === "instructor" ? T.role_instructor : T.role_admin;

  return (
    <>
      <TopBar name={profile.full_name || profile.email || ""} role={profile.role} />
      <div className="container">
        <p className="small"><Link href={home}>{T.ac_back}</Link></p>
        <h1 className="page-title">{T.ac_title}</h1>
        <p className="page-sub">{T.ac_sub}</p>

        <div className="card">
          <h2>{T.ac_data}</h2>
          <dl className="kv">
            <dt>{T.ac_name}</dt><dd>{profile.full_name || "—"}</dd>
            <dt>{T.ac_email}</dt><dd>{profile.email || "—"}</dd>
            <dt>{T.ac_role}</dt><dd>{roleLabel}</dd>
          </dl>
        </div>

        <div className="card">
          <h2>{T.ac_pw}</h2>
          <p className="muted small" style={{ marginTop: -8 }}>{T.ac_pw_hint}</p>
          <ChangePasswordForm />
        </div>
      </div>
      <Footer />
    </>
  );
}
