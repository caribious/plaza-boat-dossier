import Link from "next/link";

export default function AdminNav() {
  return (
    <nav className="adminnav">
      <Link href="/admin">Cursisten</Link>
      <Link href="/admin/instructors">Instructeurs</Link>
      <Link href="/admin/quality">Kwaliteit</Link>
    </nav>
  );
}
