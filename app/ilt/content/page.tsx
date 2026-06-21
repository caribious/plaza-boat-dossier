import { createClient } from "@/lib/supabase/server";
import { t } from "@/lib/i18n";

export const dynamic = "force-dynamic";

export default async function IltContent() {
  const T = t();
  const supabase = createClient();
  const { data: courses } = await supabase
    .from("courses")
    .select(`id, code, title, description, regulatory_reference,
       modules ( sequence, code, title, required_hours, is_practical )`)
    .order("code");
  const list = (courses as any[]) ?? [];

  return (
    <>
      <h1 className="page-title">{T.ilc_title}</h1>
      <p className="page-sub">{T.ilc_sub}</p>

      {list.map((c) => {
        const mods = (c.modules ?? []).slice().sort((a: any, b: any) => a.sequence - b.sequence);
        const totalHours = mods.reduce((s: number, m: any) => s + Number(m.required_hours || 0), 0);
        return (
          <div className="card" key={c.id}>
            <h2>{c.code} — {c.title}</h2>
            <p className="muted small" style={{ marginTop: -8 }}>
              {c.regulatory_reference} · {mods.length} {T.ilc_modules} · {totalHours} {T.ilc_hours}
            </p>
            {c.description ? <p className="small">{c.description}</p> : null}
            <table>
              <thead><tr><th>#</th><th>{T.ilc_module}</th><th>{T.ilc_h_hours}</th><th>{T.type}</th></tr></thead>
              <tbody>
                {mods.map((m: any) => (
                  <tr key={m.code ?? m.sequence}>
                    <td className="muted small">{m.code ?? m.sequence}</td>
                    <td>{m.title}</td>
                    <td className="muted small">{m.required_hours}</td>
                    <td className="muted small">{m.is_practical ? T.ilc_practical : T.ilc_theory}</td>
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
