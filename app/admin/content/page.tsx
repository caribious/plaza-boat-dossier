import { createClient } from "@/lib/supabase/server";
import Link from "next/link";
import { normCode } from "@/lib/learn";
import { t } from "@/lib/i18n";

export const dynamic = "force-dynamic";

export default async function AdminContent() {
  const T = t();
  const supabase = createClient();
  const { data: courses } = await supabase
    .from("courses")
    .select(`id, code, title, description, regulatory_reference,
       modules ( sequence, code, title, required_hours, is_practical )`)
    .order("code");
  const list = (courses as any[]) ?? [];
  const totalModules = list.reduce((n, c) => n + (c.modules?.length ?? 0), 0);

  return (
    <>
      <h1 className="page-title">{T.ilc_title}</h1>
      <p className="page-sub">{T.ilc_sub}</p>

      <div className="kpis">
        <div className="kpi"><div className="kpi-value">{list.length}</div><div className="kpi-label">{T.ah_course}</div></div>
        <div className="kpi"><div className="kpi-value">{totalModules}</div><div className="kpi-label">{T.ilc_modules}</div></div>
      </div>

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
                {mods.length === 0 ? (
                  <tr><td colSpan={4} className="muted small">—</td></tr>
                ) : mods.map((m: any) => (
                  <tr key={m.code ?? m.sequence}>
                    <td className="muted small">{m.code ?? m.sequence}</td>
                    <td><Link href={`/admin/content/${normCode(c.code)}/${m.sequence}`}>{m.title}</Link></td>
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
