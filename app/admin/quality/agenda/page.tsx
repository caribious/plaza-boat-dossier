import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fmtDate } from "@/lib/format";
import { getAgenda, daysUntil, type AgendaItem, type Bucket } from "@/lib/qmsAgenda";

export const dynamic = "force-dynamic";

const BUCKETS: { key: Bucket; title: string; cls: string }[] = [
  { key: "overdue", title: "Te laat", cls: "warn" },
  { key: "soon", title: "Binnen 30 dagen", cls: "warn" },
  { key: "upcoming", title: "Aankomend (≤ 90 dagen)", cls: "idle" },
];

function whenLabel(it: AgendaItem) {
  if (!it.date) return it.note ?? "—";
  const d = daysUntil(it.date);
  if (d === null) return fmtDate(it.date);
  if (d < 0) return `${fmtDate(it.date)} · ${Math.abs(d)} dgn te laat`;
  if (d === 0) return `${fmtDate(it.date)} · vandaag`;
  return `${fmtDate(it.date)} · over ${d} dgn`;
}

export default async function AgendaPage() {
  const supabase = createClient();
  const items = await getAgenda(supabase);

  const counts = {
    overdue: items.filter((i) => i.bucket === "overdue").length,
    soon: items.filter((i) => i.bucket === "soon").length,
    upcoming: items.filter((i) => i.bucket === "upcoming").length,
  };

  return (
    <>
      <h1 className="page-title">QMS-agenda &amp; herinneringen</h1>
      <p className="page-sub">
        Automatisch overzicht van wat aandacht vraagt — certificaten die verlopen, openstaande
        CAPA&apos;s/risico&apos;s/klachten, en de jaarlijkse audit- en directiebeoordelingscyclus
        (ISO 9001 §9–§10). Werk de items bij in de betreffende registers.
      </p>

      <div className="kpis">
        <div className="kpi"><div className="kpi-value">{counts.overdue}</div><div className="kpi-label">Te laat</div></div>
        <div className="kpi"><div className="kpi-value">{counts.soon}</div><div className="kpi-label">Binnen 30 dagen</div></div>
        <div className="kpi"><div className="kpi-value">{counts.upcoming}</div><div className="kpi-label">Aankomend</div></div>
      </div>

      {items.length === 0 && (
        <div className="card"><p className="muted small">Niets openstaand. Alles is bij — netjes.</p></div>
      )}

      {BUCKETS.map((b) => {
        const rows = items.filter((i) => i.bucket === b.key);
        if (rows.length === 0) return null;
        return (
          <div className="card" key={b.key}>
            <h2>{b.title}</h2>
            <table>
              <thead>
                <tr><th>Categorie</th><th>Onderwerp</th><th>Eigenaar</th><th>Wanneer</th><th></th></tr>
              </thead>
              <tbody>
                {rows.map((it, i) => (
                  <tr key={i}>
                    <td><span className={`badge ${b.cls}`}>{it.category}</span></td>
                    <td>{it.title}{it.ref ? <span className="muted small"> · {it.ref}</span> : null}</td>
                    <td className="muted small">{it.owner ?? "—"}</td>
                    <td className="muted small">{whenLabel(it)}</td>
                    <td><Link className="btn ghost sm" href={it.href}>Open</Link></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        );
      })}

      <p className="small muted">
        Ritme: registraties doorlopend · CAPA-controle per kwartaal · interne audit en
        directiebeoordeling jaarlijks (GIDS-01).
      </p>
    </>
  );
}
