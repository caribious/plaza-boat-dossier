import Link from "next/link";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function IltStudents() {
  const supabase = createClient();
  const { data } = await supabase
    .from("students")
    .select(
      `id, student_number, first_name, last_name, date_of_birth,
       enrollments ( status, courses ( code ), module_progress ( status ) )`
    )
    .order("last_name");

  const students = (data as any[]) ?? [];

  return (
    <>
      <h1 className="page-title">Cursisten</h1>
      <p className="page-sub">Klik op een cursist voor het volledige dossier (alleen-lezen).</p>

      <div className="card">
        <table>
          <thead>
            <tr>
              <th>Cursistnr.</th><th>Naam</th><th>Geb.datum</th><th>Opleiding</th><th>Voortgang</th><th></th>
            </tr>
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
                  <td className="muted small">
                    {s.date_of_birth ? new Date(s.date_of_birth).toLocaleDateString("nl-NL") : "—"}
                  </td>
                  <td>{enr?.courses?.code ?? "—"}</td>
                  <td className="muted small">{done}/{mods.length} · {pct}%</td>
                  <td><Link className="btn ghost sm" href={`/report/${s.id}`}>Dossier</Link></td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </>
  );
}
