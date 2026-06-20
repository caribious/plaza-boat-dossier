import Link from "next/link";
import { t } from "@/lib/i18n";

export default function IltNav() {
  const T = t();
  return (
    <nav className="adminnav">
      <Link href="/ilt">{T.iln_overview}</Link>
      <Link href="/ilt/students">{T.nav_students}</Link>
      <Link href="/ilt/instructors">{T.nav_instructors}</Link>
      <Link href="/ilt/content">{T.iln_content}</Link>
      <Link href="/ilt/quality">{T.nav_quality}</Link>
      <Link href="/ilt/quality/registers">{T.nav_registers}</Link>
      <Link href="/ilt/quality/registers/risks">{T.nav_risks}</Link>
      <Link href="/ilt/quality/satisfaction">{T.nav_satisfaction}</Link>
      <Link href="/ilt/audit">{T.iln_audit}</Link>
      <Link href="/ilt/export">{T.iln_export}</Link>
    </nav>
  );
}
