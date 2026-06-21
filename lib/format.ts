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

export function courseLabel(code: string | null) {
  if (!code) return getLocale() === "en" ? "n/a" : "n.v.t.";
  return code;
}

export function fmtDate(d: string | null) {
  if (!d) return "—";
  return new Date(d).toLocaleDateString(getLocale() === "en" ? "en-GB" : "nl-NL", {
    day: "2-digit", month: "short", year: "numeric",
  });
}
