import Link from "next/link";

export default function IltNav() {
  return (
    <nav className="adminnav">
      <Link href="/ilt">Overzicht</Link>
      <Link href="/ilt/students">Cursisten</Link>
      <Link href="/ilt/instructors">Instructeurs</Link>
      <Link href="/ilt/content">Lesprogramma</Link>
      <Link href="/ilt/quality">Kwaliteit</Link>
      <Link href="/ilt/quality/registers">QMS-registers</Link>
      <Link href="/ilt/audit">Audit-log</Link>
      <Link href="/ilt/export">Inspectierapport</Link>
    </nav>
  );
}
