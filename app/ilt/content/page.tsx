import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function IltContent() {
  const supabase = createClient();
  const { data: courses } = await supabase
    .from("courses")
    .select(`id, code, title, description, regulatory_reference,
       modules ( sequence, code, title, required_hours, is_practical )`)
    .order("code");

  const list = (courses as any[]) ?? [];

  return (
    <>
      <h1 className="page-title">Lesprogramma</h1>
      <p className="page-sub">Opleidingen en modulestructuur (alleen-lezen).</p>

      {list.map((c) => {
        const mods = (c.modules ?? []).slice().sort((a: any, b: any) => a.sequence - b.sequence);
        const totalHours = mods.reduce((s: number, m: any) => s + Number(m.required_hours || 0), 0);
        return (
          <div className="card" key={c.id}>
            <h2>{c.code} — {c.title}</h2>
            <p className="muted small" style={{ marginTop: -8 }}>
              {c.regulatory_reference} · {mods.length} modules · {totalHours} uur
            </p>
            {c.description ? <p className="small">{c.description}</p> : null}
            <table>
              <thead>
                <tr><th>#</th><th>Module</th><th>Uren</th><th>Type</th></tr>
              </thead>
              <tbody>
                {mods.map((m: any) => (
                  <tr key={m.code ?? m.sequence}>
                    <td className="muted small">{m.code ?? m.sequence}</td>
                    <td>{m.title}</td>
                    <td className="muted small">{m.required_hours}</td>
                    <td className="muted small">{m.is_practical ? "Praktijk" : "Theorie"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        );
      })}
    </>
  );
}
