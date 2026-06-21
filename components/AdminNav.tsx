import Link from "next/link";

export default function AdminNav() {
  return (
    <nav className="adminnav">
      <Link href="/admin">Cursisten</Link>
      <Link href="/admin/instructors">Instructeurs</Link>
      <Link href="/admin/quality">Kwaliteit</Link>
      <Link href="/admin/quality/registers">QMS-registers</Link>
      <Link href="/admin/quality/agenda">QMS-agenda</Link>
      <Link href="/admin/quality/reviews">Audit &amp; beoordeling</Link>
    </nav>
  );
}
