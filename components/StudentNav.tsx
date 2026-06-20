import Link from "next/link";

export default function StudentNav() {
  return (
    <nav className="adminnav">
      <Link href="/student">Mijn dossier</Link>
      <Link href="/student/learn">Mijn cursus</Link>
    </nav>
  );
}
