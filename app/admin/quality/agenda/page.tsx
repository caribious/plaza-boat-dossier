import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fmtDate } from "@/lib/format";
import { getAgenda, daysUntil, type AgendaItem, type Bucket } from "@/lib/qmsAgenda";
import { t } from "@/lib/i18n";

export const dynamic = "force-dynamic";

export default async function AgendaPage() {
  const T = t();
  const supabase = createClient();
  const items = await getAgenda(supabase);

  const BUCKETS: { key: Bucket; title: string; cls: string }[] = [
    { key: "overdue", title: T.ag_overdue, cls: "warn" },
    { key: "soon", title: T.ag_soon, cls: "warn" },
    { key: "upcoming", title: T.ag_upcoming, cls: "idle" },
  ];

  const whenLabel = (it: AgendaItem) => {
    if (!it.date) return it.note ?? "—";
    const d = daysUntil(it.date);
    if (d === null) return fmtDate(it.date);
    if (d < 0) return `${fmtDate(it.date)} · ${Math.abs(d)} ${T.ag_overdue_by}`;
    if (d === 0) return `${fmtDate(it.date)} · ${T.ag_today}`;
    return `${fmtDate(it.date)} · ${T.ag_in} ${d} ${T.ag_days}`;
  };

  const counts = {
    overdue: items.filter((i) => i.bucket === "overdue").length,
    soon: items.filter((i) => i.bucket === "soon").length,
    upcoming: items.filter((i) => i.bucket === "upcoming").length,
  };

  return (
    <>
      <h1 className="page-title">{T.ag_title}</h1>
      <p className="page-sub">{T.ag_sub}</p>

      <div className="kpis">
        <div className="kpi"><div className="kpi-value">{counts.overdue}</div><div className="kpi-label">{T.ag_overdue}</div></div>
        <div className="kpi"><div className="kpi-value">{counts.soon}</div><div className="kpi-label">{T.ag_soon}</div></div>
        <div className="kpi"><div className="kpi-value">{counts.upcoming}</div><div className="kpi-label">{T.ag_upcoming_short}</div></div>
      </div>

      {items.length === 0 && (
        <div className="card"><p className="muted small">{T.ag_empty}</p></div>
      )}

      {BUCKETS.map((b) => {
        const rows = items.filter((i) => i.bucket === b.key);
        if (rows.length === 0) return null;
        return (
          <div className="card" key={b.key}>
            <h2>{b.title}</h2>
            <table>
              <thead>
                <tr><th>{T.ag_cat}</th><th>{T.ag_subject}</th><th>{T.owner}</th><th>{T.ag_when}</th><th></th></tr>
              </thead>
              <tbody>
                {rows.map((it, i) => (
                  <tr key={i}>
                    <td><span className={`badge ${b.cls}`}>{it.category}</span></td>
                    <td>{it.title}{it.ref ? <span className="muted small"> · {it.ref}</span> : null}</td>
                    <td className="muted small">{it.owner ?? "—"}</td>
                    <td className="muted small">{whenLabel(it)}</td>
                    <td><Link className="btn ghost sm" href={it.href}>{T.open}</Link></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        );
      })}

      <p className="small muted">{T.ag_rhythm}</p>
    </>
  );
}
