import Link from "next/link";
import { redirect } from "next/navigation";
import { getProfile } from "@/lib/getProfile";
import TopBar from "@/components/TopBar";
import Footer from "@/components/Footer";
import ChangePasswordForm from "@/components/ChangePasswordForm";

export const dynamic = "force-dynamic";

export default async function AccountPage() {
  const profile = await getProfile();
  if (!profile) redirect("/login");

  const home = profile.role === "student" ? "/student" : "/admin";

  return (
    <>
      <TopBar name={profile.full_name || profile.email || ""} role={profile.role} />
      <div className="container">
        <p className="small">
          <Link href={home}>← Terug</Link>
        </p>
        <h1 className="page-title">Mijn account</h1>
        <p className="page-sub">Beheer je inloggegevens.</p>

        <div className="card">
          <h2>Gegevens</h2>
          <dl className="kv">
            <dt>Naam</dt><dd>{profile.full_name || "—"}</dd>
            <dt>E-mail</dt><dd>{profile.email || "—"}</dd>
            <dt>Rol</dt>
            <dd>{profile.role === "student" ? "Cursist" : profile.role === "instructor" ? "Instructeur" : "Beheer"}</dd>
          </dl>
        </div>

        <div className="card">
          <h2>Wachtwoord wijzigen</h2>
          <p className="muted small" style={{ marginTop: -8 }}>
            Wijzig je tijdelijke wachtwoord direct na de eerste keer inloggen.
          </p>
          <ChangePasswordForm />
        </div>
      </div>
      <Footer />
    </>
  );
}
