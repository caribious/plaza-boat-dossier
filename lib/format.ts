// Kleine hulpfuncties voor weergave.

export function progressBadge(status: string) {
  if (status === "completed") return { cls: "ok", label: "Afgerond" };
  if (status === "in_progress") return { cls: "warn", label: "Onderweg" };
  return { cls: "idle", label: "Nog niet gestart" };
}

export function examBadge(outcome: string) {
  if (outcome === "passed") return { cls: "ok", label: "Geslaagd" };
  if (outcome === "failed") return { cls: "warn", label: "Niet geslaagd" };
  return { cls: "idle", label: "Gepland / open" };
}

export function examKindLabel(kind: string) {
  if (kind === "oral") return "Mondeling (X/8.1)";
  if (kind === "practical") return "Praktijk (X/8.1)";
  if (kind === "knowledge_mcq") return "Kennistoets (X/8.5)";
  return kind;
}

export function fmtDate(d: string | null) {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("nl-NL", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}
