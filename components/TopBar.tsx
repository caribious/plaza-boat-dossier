import Link from "next/link";

export default function TopBar({ name, role }: { name: string; role: string }) {
  const roleLabel =
    role === "admin" ? "Beheer" : role === "instructor" ? "Instructeur"
    : role === "auditor" ? "ILT-inspecteur" : "Cursist";
  const home = role === "student" ? "/student" : role === "auditor" ? "/ilt" : "/admin";
  return (
    <div className="topbar">
      <Link href={home} className="brand" style={{ color: "#fff" }}>
        <span className="logo-mark" aria-hidden>⚓</span> Plaza Boat College <small>Studentdossier</small>
      </Link>
      <div className="right">
        <span>
          {name} · {roleLabel}
        </span>
        <Link href="/account" className="acct-link">Account</Link>
        <form action="/auth/signout" method="post">
          <button className="link" type="submit">
            Uitloggen
          </button>
        </form>
      </div>
    </div>
  );
}
