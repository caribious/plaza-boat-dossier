import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function IltHome() {
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
    { label: "Cursisten", value: students.count ?? 0 },
    { label: "Actieve inschrijvingen", value: enrollments.count ?? 0 },
    { label: "Examenregistraties", value: exams.count ?? 0 },
    { label: "Certificaten", value: certs.count ?? 0 },
    { label: "Instructeurs", value: instructors.count ?? 0 },
    { label: "Audit-regels", value: audit.count ?? 0 },
  ];

  return (
    <>
      <h1 className="page-title">ILT-inzage — overzicht</h1>
      <p className="page-sub">
        Volledig, alleen-lezen beeld van Plaza Boat College. Niets kan vanuit deze
        omgeving gewijzigd worden.
      </p>

      <div className="kpis" style={{ gridTemplateColumns: "repeat(3, 1fr)" }}>
        {kpis.map((k) => (
          <div className="kpi" key={k.label}>
            <div className="kpi-value">{k.value}</div>
            <div className="kpi-label">{k.label}</div>
          </div>
        ))}
      </div>

      <div className="card">
        <h2>Wat u hier kunt inzien</h2>
        <ul style={{ margin: 0, paddingLeft: 18, lineHeight: 1.9 }}>
          <li><Link href="/ilt/students">Cursisten</Link> — volledige dossiers: voortgang, uren, examens (met examinator) en certificaten.</li>
          <li><Link href="/ilt/instructors">Instructeurs</Link> — kwalificaties met certificaatnummer en geldigheid.</li>
          <li><Link href="/ilt/content">Lesprogramma</Link> — opleidingen BM I/II/III en de modulestructuur.</li>
          <li><Link href="/ilt/audit">Audit-log</Link> — onveranderbaar spoor van alle wijzigingen.</li>
          <li><Link href="/ilt/export">Inspectierapport</Link> — alles gebundeld in één afdrukbaar/PDF-document.</li>
        </ul>
      </div>
    </>
  );
}
