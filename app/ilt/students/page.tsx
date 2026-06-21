import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fmtDate } from "@/lib/format";
import { t } from "@/lib/i18n";

export const dynamic = "force-dynamic";

export default async function IltStudents() {
  const T = t();
  const supabase = createClient();
  const { data } = await supabase
    .from("students")
    .select(`id, student_number, first_name, last_name, date_of_birth,
       enrollments ( status, courses ( code ), module_progress ( status ) )`)
    .order("last_name");
  const students = (data as any[]) ?? [];

  return (
    <>
      <h1 className="page-title">{T.nav_students}</h1>
      <p className="page-sub">{T.ils_sub}</p>

      <div className="card">
        <table>
          <thead>
            <tr><th>{T.ah_num}</th><th>{T.ah_name}</th><th>{T.ils_dob}</th><th>{T.course}</th><th>{T.ah_progress}</th><th></th></tr>
          </thead>
          <tbody>
            {students.map((s) => {
              const enr = s.enrollments?.[0];
              const mods = enr?.module_progress ?? [];
              const done = mods.filter((m: any) => m.status === "completed").length;
              const pct = mods.length ? Math.round((done / mods.length) * 100) : 0;
              return (
                <tr key={s.id}>
                  <td className="muted small">{s.student_number}</td>
                  <td>{s.first_name} {s.last_name}</td>
                  <td className="muted small">{fmtDate(s.date_of_birth)}</td>
                  <td>{enr?.courses?.code ?? "—"}</td>
                  <td className="muted small">{done}/{mods.length} · {pct}%</td>
                  <td><Link className="btn ghost sm" href={`/report/${s.id}`}>{T.ils_record}</Link></td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </>
  );
}
