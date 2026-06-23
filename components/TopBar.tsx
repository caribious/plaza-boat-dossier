import Link from "next/link";
import { t } from "@/lib/i18n";
import LangSwitch from "@/components/LangSwitch";

export default function TopBar({ name, role }: { name: string; role: string }) {
  const T = t();
  const roleLabel =
    role === "admin" ? T.role_admin : role === "instructor" ? T.role_instructor
    : role === "auditor" ? T.role_auditor : T.role_student;
  const home = role === "student" ? "/student" : role === "auditor" ? "/ilt" : "/admin";
  return (
    <div className="topbar">
      <div className="topbar-inner">
        <Link href={home} className="brand" style={{ color: "#fff" }}>
          <span className="logo-mark" aria-hidden>⚓</span> Plaza Boat College <small>{T.subtitle}</small>
        </Link>
        <div className="right">
          <span>{name} · {roleLabel}</span>
          <LangSwitch />
          <Link href="/account" className="acct-link">{T.account}</Link>
          <form action="/auth/signout" method="post">
            <button className="link" type="submit">{T.logout}</button>
          </form>
        </div>
      </div>
    </div>
  );
}
