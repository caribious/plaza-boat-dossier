import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { t } from "@/lib/i18n";

export const dynamic = "force-dynamic";

export default async function IltHome() {
  const T = t();
  const supabase = createClient();
  const [students, enrollments, certs, instructors, exams, audit] = await Promise.all([
    supabase.from("students").select("*", { count: "exact", head: true }),
    supabase.from("enrollments").select("*", { count: "exact", head: true }).eq("status", "active"),
    supabase.from("certificates").select("*", { count: "exact", head: true }),
    supabase.from("instructors").select("*", { count: "exact", head: true }).eq("active", true),
    supabase.from("exam_results").select("*", { count: "exact", head: true }),
    supabase.from("audit_log").select("*", { count: "exact", head: true }),
  ]);

  const kpis = [
    { label: T.nav_students, value: students.count ?? 0 },
    { label: T.ah_kpi_active, value: enrollments.count ?? 0 },
    { label: T.ilh_kpi_exams, value: exams.count ?? 0 },
    { label: T.ah_kpi_certs, value: certs.count ?? 0 },
    { label: T.nav_instructors, value: instructors.count ?? 0 },
    { label: T.ilh_kpi_audit, value: audit.count ?? 0 },
  ];

  return (
    <>
      <h1 className="page-title">{T.ilh_title}</h1>
      <p className="page-sub">{T.ilh_sub}</p>

      <div className="kpis" style={{ gridTemplateColumns: "repeat(3, 1fr)" }}>
        {kpis.map((k) => (
          <div className="kpi" key={k.label}>
            <div className="kpi-value">{k.value}</div>
            <div className="kpi-label">{k.label}</div>
          </div>
        ))}
      </div>

      <div className="card">
        <h2>{T.ilh_can_view}</h2>
        <ul style={{ margin: 0, paddingLeft: 18, lineHeight: 1.9 }}>
          <li><Link href="/ilt/students">{T.nav_students}</Link>{T.ilh_li_students}</li>
          <li><Link href="/ilt/instructors">{T.nav_instructors}</Link>{T.ilh_li_instructors}</li>
          <li><Link href="/ilt/content">{T.iln_content}</Link>{T.ilh_li_content}</li>
          <li><Link href="/ilt/audit">{T.iln_audit}</Link>{T.ilh_li_audit}</li>
          <li><Link href="/ilt/export">{T.iln_export}</Link>{T.ilh_li_export}</li>
        </ul>
      </div>
    </>
  );
}
