import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { t } from "@/lib/i18n";

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
  const T = t();
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

  const [{ count: studentCount }, { count: activeCount }, { count: certCount }, { count: instrCount }] =
    await Promise.all([
      supabase.from("students").select("*", { count: "exact", head: true }),
      supabase.from("enrollments").select("*", { count: "exact", head: true }).eq("status", "active"),
      supabase.from("certificates").select("*", { count: "exact", head: true }),
      supabase.from("instructors").select("*", { count: "exact", head: true }).eq("active", true),
    ]);

  const kpis = [
    { label: T.ah_kpi_students, value: studentCount ?? 0 },
    { label: T.ah_kpi_active, value: activeCount ?? 0 },
    { label: T.ah_kpi_certs, value: certCount ?? 0 },
    { label: T.ah_kpi_instr, value: instrCount ?? 0 },
  ];

  return (
    <>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <div>
          <h1 className="page-title">{T.ah_title}</h1>
          <p className="page-sub">{T.ah_sub}</p>
        </div>
        <Link className="btn" href="/admin/students/new">{T.ah_new}</Link>
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
          <p className="muted small">{T.ah_none}</p>
        ) : (
          <table>
            <thead>
              <tr>
                <th>{T.ah_num}</th><th>{T.ah_name}</th><th>{T.ah_course}</th><th>{T.ah_progress}</th><th></th>
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
                    <td><Link href={`/admin/students/${s.id}`}>{s.first_name} {s.last_name}</Link></td>
                    <td>{enr?.courses?.code ?? "—"}</td>
                    <td style={{ minWidth: 160 }}>
                      <div className="progress-wrap"><div className="progress-bar" style={{ width: `${pct}%` }} /></div>
                      <span className="muted small">{done}/{mods.length} {T.ah_modules} · {pct}%</span>
                    </td>
                    <td><Link className="btn ghost sm" href={`/admin/students/${s.id}`}>{T.ah_open}</Link></td>
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
