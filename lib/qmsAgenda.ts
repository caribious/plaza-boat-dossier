// Gedeelde QMS-agenda/herinneringslogica (ISO 9001 §9/§10).
// Wordt gebruikt door het admin-dashboard (/admin/quality/agenda) en de
// herinneringsbanner. Eén bron van waarheid voor "wat moet wanneer".

export type Bucket = "overdue" | "soon" | "upcoming";

export interface AgendaItem {
  category: string;          // Certificaat / CAPA / Risico / Klacht / Incident / Audit / Directiebeoordeling / Routine
  title: string;
  ref?: string | null;
  owner?: string | null;
  date: string | null;       // ISO-datum waarop het verloopt/verschuldigd is
  bucket: Bucket;
  href: string;              // waar je het afhandelt
  note?: string;
}

const DAY = 86400000;

export function daysUntil(dateStr: string | null): number | null {
  if (!dateStr) return null;
  return Math.round((new Date(dateStr).getTime() - Date.now()) / DAY);
}

function bucketFor(d: number | null): Bucket | null {
  if (d === null) return null;
  if (d < 0) return "overdue";
  if (d <= 30) return "soon";
  if (d <= 90) return "upcoming";
  return null; // verder dan 90 dagen weg = (nog) niet tonen
}

function addDays(dateStr: string, n: number): string {
  return new Date(new Date(dateStr).getTime() + n * DAY).toISOString().slice(0, 10);
}

function nextQuarterStart(): string {
  const now = new Date();
  const q = Math.floor(now.getMonth() / 3); // 0..3
  const month = (q + 1) * 3;                // start van het volgende kwartaal
  const year = now.getFullYear() + (month > 11 ? 1 : 0);
  return new Date(year, month % 12, 1).toISOString().slice(0, 10);
}

const OPEN = ["open", "in_behandeling"];

// Haalt alle bronnen op en bouwt de agendalijst.
export async function getAgenda(supabase: any): Promise<AgendaItem[]> {
  const [certs, improvements, risks, complaints, incidents, reviews] = await Promise.all([
    supabase.from("instructor_certificates").select("cert_type, certificate_number, expiry_date, instructors ( first_name, last_name )"),
    supabase.from("qms_improvements").select("ref, description, owner, due_date, status"),
    supabase.from("qms_risks").select("ref, description, owner, due_date, status"),
    supabase.from("qms_complaints").select("ref, description, owner, due_date, status"),
    supabase.from("qms_incidents").select("ref, description, owner, due_date, status"),
    supabase.from("qms_reviews").select("kind, ref, planned_date, completed_date, status"),
  ]);

  const items: AgendaItem[] = [];

  // 1. Instructeurcertificaten die verlopen
  for (const c of (certs.data as any[]) ?? []) {
    const b = bucketFor(daysUntil(c.expiry_date));
    if (!b) continue;
    const who = c.instructors ? `${c.instructors.first_name} ${c.instructors.last_name}` : "";
    items.push({ category: "Certificaat", title: `${c.cert_type}${who ? ` — ${who}` : ""}`,
      ref: c.certificate_number, owner: who, date: c.expiry_date, bucket: b, href: "/admin/instructors" });
  }

  // 2. Openstaande registers met einddatum (CAPA / risico / klacht / incident)
  const regs: [any[], string, string][] = [
    [(improvements.data as any[]) ?? [], "CAPA", "/admin/quality/registers"],
    [(risks.data as any[]) ?? [], "Risico", "/admin/quality/registers"],
    [(complaints.data as any[]) ?? [], "Klacht", "/admin/quality/registers"],
    [(incidents.data as any[]) ?? [], "Incident", "/admin/quality/registers"],
  ];
  for (const [rows, category, href] of regs) {
    for (const r of rows) {
      if (!OPEN.includes(r.status)) continue;
      const b = bucketFor(daysUntil(r.due_date));
      if (r.due_date && b) {
        items.push({ category, title: r.description ?? r.ref, ref: r.ref, owner: r.owner, date: r.due_date, bucket: b, href });
      } else if (!r.due_date) {
        items.push({ category, title: r.description ?? r.ref, ref: r.ref, owner: r.owner, date: null,
          bucket: "upcoming", href, note: "open — geen einddatum" });
      }
    }
  }

  // 3. Jaarlijkse cyclus: interne audit (§9.2) en directiebeoordeling (§9.3)
  const cycle: [string, string][] = [["interne_audit", "Interne audit"], ["directiebeoordeling", "Directiebeoordeling"]];
  const revs = (reviews.data as any[]) ?? [];
  for (const [kind, label] of cycle) {
    const ofKind = revs.filter((r) => r.kind === kind);
    const done = ofKind.filter((r) => r.completed_date).sort((a, b) => (a.completed_date < b.completed_date ? 1 : -1))[0];
    const planned = ofKind.filter((r) => !r.completed_date && r.planned_date).sort((a, b) => (a.planned_date < b.planned_date ? -1 : 1))[0];
    if (done) {
      const due = addDays(done.completed_date, 365);
      const b = bucketFor(daysUntil(due));
      if (b) items.push({ category: label, title: `${label} — volgende ronde verschuldigd`, date: due, bucket: b,
        href: "/admin/quality/reviews", note: `laatste afgerond ${done.completed_date}` });
    } else if (planned) {
      const b = bucketFor(daysUntil(planned.planned_date));
      items.push({ category: label, title: `${label} gepland`, date: planned.planned_date, bucket: b ?? "upcoming",
        href: "/admin/quality/reviews", note: "uitvoeren en afvinken" });
    } else {
      items.push({ category: label, title: `${label} nog nooit uitgevoerd`, date: null, bucket: "overdue",
        href: "/admin/quality/reviews", note: "vereist vóór ISO-certificering" });
    }
  }

  // 4. Terugkerende kwartaalcontrole van certificaatgeldigheid (PR-03)
  const nq = nextQuarterStart();
  const bq = bucketFor(daysUntil(nq)) ?? "upcoming";
  items.push({ category: "Routine", title: "Kwartaalcontrole geldigheid instructeurcertificaten", date: nq, bucket: bq,
    href: "/admin/instructors", note: "PR-03 — vóór elke examenronde" });

  // Sorteer: te laat eerst, dan op datum
  const order: Record<Bucket, number> = { overdue: 0, soon: 1, upcoming: 2 };
  items.sort((a, b) => order[a.bucket] - order[b.bucket] || ((a.date ?? "9999") < (b.date ?? "9999") ? -1 : 1));
  return items;
}
