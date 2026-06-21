import Link from "next/link";
import { t } from "@/lib/i18n";

export default function StudentNav() {
  const T = t();
  return (
    <nav className="adminnav">
      <Link href="/student">{T.sn_record}</Link>
      <Link href="/student/learn">{T.sn_course}</Link>
    </nav>
  );
}
