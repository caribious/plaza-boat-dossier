import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { progressBadge } from "@/lib/format";

export const dynamic = "force-dynamic";

interface Row {
  id: string;
  student_number: string;
  first_name: string;
  last_name: string;
  email: string | null;
  enrollments: {
    status: string;
    courses: { code: string; title: string } | null;
    module_progress: { status: string }[];
  }[];
}

export default async function AdminHome() {
  const supabase = createClient();
  const { data } = await supabase
    .from("students")
    .select(
      `id, student_number, first_name, last_name, email,
       enrollments ( status, courses ( code, title ),
         module_progress ( status ) )`
    )
    .order("last_name");

  const students = (data as unknown as Row[]) ?? [];

  // Kerncijfers voor het dashboard
  const [{ count: studentCount }, { count: activeCount }, { count: certCount }, { count: instrCount }] =
    await Promise.all([
      supabase.from("students").select("*", { count: "exact", head: true }),
      supabase.from("enrollments").select("*", { count: "exact", head: true }).eq("status", "active"),
      supabase.from("certificates").select("*", { count: "exact", head: true }),
      supabase.from("instructors").select("*", { count: "exact", head: true }).eq("active", true),
    ]);

  const kpis = [
    { label: "Cursisten", value: studentCount ?? 0 },
    { label: "Actieve inschrijvingen", value: activeCount ?? 0 },
    { label: "Certificaten", value: certCount ?? 0 },
    { label: "Instructeurs", value: instrCount ?? 0 },
  ];

  return (
    <>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <div>
          <h1 className="page-title">Cursisten</h1>
          <p className="page-sub">
            Leerlingadministratie — alle ingeschreven cursisten en hun voortgang.
          </p>
        </div>
        <Link className="btn" href="/admin/students/new">+ Nieuwe cursist</Link>
      </div>

      <div className="kpis">
        {kpis.map((k) => (
          <div className="kpi" key={k.label}>
            <div className="kpi-value">{k.value}</div>
            <div className="kpi-label">{k.label}</div>
          </div>
        ))}
      </div>

      <div className="card">
        {students.length === 0 ? (
          <p className="muted small">
            Nog geen cursisten. Voer <code>seed-demo.sql</code> uit voor demo-data.
          </p>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Cursistnr.</th>
                <th>Naam</th>
                <th>Opleiding</th>
                <th>Voortgang</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {students.map((s) => {
                const enr = s.enrollments?.[0];
                const mods = enr?.module_progress ?? [];
                const done = mods.filter((m) => m.status === "completed").length;
                const pct = mods.length ? Math.round((done / mods.length) * 100) : 0;
                return (
                  <tr key={s.id}>
                    <td className="muted small">{s.student_number}</td>
                    <td>
                      <Link href={`/admin/students/${s.id}`}>
                        {s.first_name} {s.last_name}
                      </Link>
                    </td>
                    <td>{enr?.courses?.code ?? "—"}</td>
                    <td style={{ minWidth: 160 }}>
                      <div className="progress-wrap">
                        <div className="progress-bar" style={{ width: `${pct}%` }} />
                      </div>
                      <span className="muted small">
                        {done}/{mods.length} modules · {pct}%
                      </span>
                    </td>
                    <td>
                      <Link className="btn ghost sm" href={`/admin/students/${s.id}`}>
                        Open dossier
                      </Link>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </>
  );
}
