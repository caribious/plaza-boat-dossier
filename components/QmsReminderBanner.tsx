import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getAgenda } from "@/lib/qmsAgenda";

// Toont een herinneringsbalk bovenaan de admin als er iets te laat is of
// binnen 30 dagen speelt. Verschijnt op elke admin-pagina (via de layout).
export default async function QmsReminderBanner() {
  let overdue = 0, soon = 0;
  try {
    const items = await getAgenda(createClient());
    overdue = items.filter((i) => i.bucket === "overdue").length;
    soon = items.filter((i) => i.bucket === "soon").length;
  } catch {
    return null; // bij twijfel: niets tonen i.p.v. de pagina breken
  }
  if (overdue === 0 && soon === 0) return null;

  const parts: string[] = [];
  if (overdue) parts.push(`${overdue} te laat`);
  if (soon) parts.push(`${soon} binnen 30 dagen`);

  return (
    <div className="container" style={{ paddingTop: 12, paddingBottom: 0 }}>
      <div className="card" style={{
        borderLeft: "4px solid var(--warn, #b45309)", display: "flex",
        justifyContent: "space-between", alignItems: "center", gap: 12, flexWrap: "wrap",
      }}>
        <span className="small">
          <strong>QMS-herinnering:</strong> {parts.join(" · ")} vragen aandacht.
        </span>
        <Link className="btn sm" href="/admin/quality/agenda">Naar de QMS-agenda</Link>
      </div>
    </div>
  );
}
