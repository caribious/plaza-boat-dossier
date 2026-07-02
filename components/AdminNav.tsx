import Link from "next/link";
import { t } from "@/lib/i18n";

export default function AdminNav() {
  const T = t();
  return (
    <nav className="adminnav">
      <div className="navrow">
        <Link href="/admin">{T.nav_students}</Link>
        <Link href="/admin/instructors">{T.nav_instructors}</Link>
        <Link href="/admin/content">{T.iln_content}</Link>
        <Link href="/admin/exams">{T.nav_exams}</Link>
        <Link href="/admin/quality">{T.nav_quality}</Link>
        <Link href="/admin/quality/kpi">{T.nav_kpi}</Link>
        <Link href="/admin/quality/registers">{T.nav_registers}</Link>
        <Link href="/admin/quality/registers/risks">{T.nav_risks}</Link>
        <Link href="/admin/quality/agenda">{T.nav_agenda}</Link>
        <Link href="/admin/quality/reviews">{T.nav_reviews}</Link>
        <Link href="/admin/quality/satisfaction">{T.nav_satisfaction}</Link>
        <Link href="/admin/ilt-aanvraag">ILT-aanvraag</Link>
        <Link href="/admin/users">{T.nav_users}</Link>
      </div>
    </nav>
  );
}
