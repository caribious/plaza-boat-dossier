import { getLocale } from "@/lib/i18n";

// Kleine hulpfuncties voor weergave (taalbewust via cookie).
export function progressBadge(status: string) {
  const en = getLocale() === "en";
  if (status === "completed") return { cls: "ok", label: en ? "Completed" : "Afgerond" };
  if (status === "in_progress") return { cls: "warn", label: en ? "In progress" : "Onderweg" };
  return { cls: "idle", label: en ? "Not started" : "Nog niet gestart" };
}

export function examBadge(outcome: string) {
  const en = getLocale() === "en";
  if (outcome === "passed") return { cls: "ok", label: en ? "Passed" : "Geslaagd" };
  if (outcome === "failed") return { cls: "warn", label: en ? "Failed" : "Niet geslaagd" };
  return { cls: "idle", label: en ? "Planned / open" : "Gepland / open" };
}

export function examKindLabel(kind: string) {
  if (kind === "oral") return getLocale() === "en" ? "Oral (X/8.1)" : "Mondeling (X/8.1)";
  if (kind === "practical") return getLocale() === "en" ? "Practical (X/8.1)" : "Praktijk (X/8.1)";
  if (kind === "knowledge_mcq") return getLocale() === "en" ? "Knowledge test (X/8.5)" : "Kennistoets (X/8.5)";
  return kind;
}

export function qmsStatusBadge(status: string | null) {
  const en = getLocale() === "en";
  if (status === "gesloten") return { cls: "ok", label: en ? "Closed" : "Gesloten" };
  if (status === "in_behandeling") return { cls: "warn", label: en ? "In progress" : "In behandeling" };
  return { cls: "idle", label: "Open" };
}

export function incidentKindLabel(kind: string | null) {
  const en = getLocale() === "en";
  if (kind === "ongeval") return en ? "Accident" : "Ongeval";
  if (kind === "bijna_ongeval") return en ? "Near-miss" : "Bijna-ongeval";
  return kind ?? "—";
}

export function severityLabel(s: string | null) {
  const en = getLocale() === "en";
  if (s === "laag") return en ? "Low" : "Laag";
  if (s === "middel") return en ? "Medium" : "Middel";
  if (s === "hoog") return en ? "High" : "Hoog";
  return "—";
}

export function improvementTypeLabel(t: string | null) {
  const en = getLocale() === "en";
  if (t === "correctief") return en ? "Corrective" : "Correctief";
  if (t === "preventief") return en ? "Preventive" : "Preventief";
  if (t === "verbetering") return en ? "Improvement" : "Verbetering";
  return "—";
}

// --- Risicoregister (ISO 9001 §6.1) ---------------------------------
// Risicoscore = waarschijnlijkheid (1..5) x impact (1..5) = 1..25.
// Kleur: laag (<=4) groen, middel (5..9) oranje, hoog (>=10) rood.
export function riskScoreBadge(score: number | null) {
  const s = Number(score ?? 0);
  if (s <= 0) return { cls: "idle", label: "—" };
  if (s >= 10) return { cls: "bad", label: String(s) };
  if (s >= 5) return { cls: "warn", label: String(s) };
  return { cls: "ok", label: String(s) };
}

export function riskResponseLabel(r: string | null) {
  const en = getLocale() === "en";
  if (r === "vermijden") return en ? "Avoid" : "Vermijden";
  if (r === "beperken") return en ? "Mitigate" : "Beperken";
  if (r === "delen") return en ? "Share" : "Delen";
  if (r === "accepteren") return en ? "Accept" : "Accepteren";
  return "—";
}

// KPI-status t.o.v. target: 'ok' (groen) / 'warn' (oranje) / 'bad' (rood).
export function kpiStatusBadge(status: "ok" | "warn" | "bad" | "idle") {
  const en = getLocale() === "en";
  if (status === "ok") return { cls: "ok", label: en ? "On track" : "Op koers" };
  if (status === "warn") return { cls: "warn", label: en ? "Attention" : "Aandacht" };
  if (status === "bad") return { cls: "bad", label: en ? "Below target" : "Onder norm" };
  return { cls: "idle", label: "—" };
}

// Opleidingscode -> nette weergave (null = n.v.t.)
export function courseLabel(code: string | null) {
  if (!code) return getLocale() === "en" ? "n/a" : "n.v.t.";
  return code;
}

// --- Toelatingseisen & kwalificaties --------------------------------
// Vrije code (kind) -> nette weergave. VHF is de verplichte toelatingseis
// (SCV Code X/6.1 — Reg 10.11).
export function qualificationKindLabel(kind: string | null) {
  const en = getLocale() === "en";
  switch (kind) {
    case "vhf":         return en ? "VHF certificate" : "VHF-certificaat";
    case "medical":     return en ? "Medical certificate" : "Medisch certificaat";
    case "first_aid":   return en ? "First aid" : "EHBO / First Aid";
    case "gmdss_goc":   return "GMDSS / GOC";
    case "sea_service": return en ? "Sea service" : "Vaartijd / seagoing service";
    case "other":       return en ? "Other" : "Overig";
    default:            return kind ?? "—";
  }
}

// Aanbevolen keuzelijst voor de invoer (code + label). Taalbewust.
export function qualificationKinds(): { value: string; label: string }[] {
  const en = getLocale() === "en";
  return [
    { value: "vhf",         label: en ? "VHF certificate (SCV Code X/6.1 — Reg 10.11)" : "VHF-certificaat (SCV Code X/6.1 — Reg 10.11)" },
    { value: "medical",     label: en ? "Medical certificate" : "Medisch certificaat" },
    { value: "first_aid",   label: en ? "First aid" : "EHBO / First Aid" },
    { value: "gmdss_goc",   label: "GMDSS / GOC" },
    { value: "sea_service", label: en ? "Sea service" : "Vaartijd / seagoing service" },
    { value: "other",       label: en ? "Other" : "Overig" },
  ];
}

// Vervalsignalering: rood (verlopen) / oranje (binnen 60 dagen) / groen (geldig).
// valid_until null => onbeperkt geldig (groen).
export function expiryBadge(validUntil: string | null) {
  const en = getLocale() === "en";
  if (!validUntil) return { cls: "ok", label: en ? "Unlimited" : "Onbeperkt" };
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const end = new Date(validUntil);
  const days = Math.ceil((end.getTime() - today.getTime()) / 86400000);
  if (days < 0)  return { cls: "bad",  label: en ? "Expired" : "Verlopen" };
  if (days <= 60) return { cls: "warn", label: en ? `Expires in ${days} days` : `Verloopt over ${days} dg` };
  return { cls: "ok", label: en ? "Valid" : "Geldig" };
}

// Heeft de cursist een geldig (niet-verlopen) VHF-certificaat?
export function hasValidVhf(quals: { kind: string; valid_until: string | null }[]) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return quals.some(
    (q) =>
      q.kind === "vhf" &&
      (!q.valid_until || new Date(q.valid_until).getTime() >= today.getTime())
  );
}

export function fmtDate(d: string | null) {
  if (!d) return "—";
  return new Date(d).toLocaleDateString(getLocale() === "en" ? "en-GB" : "nl-NL", {
    day: "2-digit", month: "short", year: "numeric",
  });
}
