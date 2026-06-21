import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { getAgenda } from "@/lib/qmsAgenda";
import { t } from "@/lib/i18n";

export default async function QmsReminderBanner() {
  let overdue = 0, soon = 0;
  try {
    const items = await getAgenda(createClient());
    overdue = items.filter((i) => i.bucket === "overdue").length;
    soon = items.filter((i) => i.bucket === "soon").length;
  } catch {
    return null;
  }
  if (overdue === 0 && soon === 0) return null;
  const T = t();
  const parts: string[] = [];
  if (overdue) parts.push(`${overdue} ${T.rem_overdue}`);
  if (soon) parts.push(`${soon} ${T.rem_soon}`);

  return (
    <div className="container" style={{ paddingTop: 12, paddingBottom: 0 }}>
      <div className="card" style={{
        borderLeft: "4px solid var(--warn, #b45309)", display: "flex",
        justifyContent: "space-between", alignItems: "center", gap: 12, flexWrap: "wrap",
      }}>
        <span className="small"><strong>{T.rem_label}</strong> {parts.join(" · ")} {T.rem_tail}</span>
        <Link className="btn sm" href="/admin/quality/agenda">{T.rem_cta}</Link>
      </div>
    </div>
  );
}
