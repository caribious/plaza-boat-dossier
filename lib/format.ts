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

// --- QMS-registers (ISO 9001) ---------------------------------------
export function qmsStatusBadge(status: string | null) {
  if (status === "gesloten") return { cls: "ok", label: "Gesloten" };
  if (status === "in_behandeling") return { cls: "warn", label: "In behandeling" };
  return { cls: "idle", label: "Open" };
}

export function incidentKindLabel(kind: string | null) {
  if (kind === "ongeval") return "Ongeval";
  if (kind === "bijna_ongeval") return "Bijna-ongeval";
  return kind ?? "—";
}

export function severityLabel(s: string | null) {
  if (s === "laag") return "Laag";
  if (s === "middel") return "Middel";
  if (s === "hoog") return "Hoog";
  return "—";
}

export function improvementTypeLabel(t: string | null) {
  if (t === "correctief") return "Correctief";
  if (t === "preventief") return "Preventief";
  if (t === "verbetering") return "Verbetering";
  return "—";
}

// Opleidingscode -> nette weergave (null = n.v.t.)
export function courseLabel(code: string | null) {
  if (!code) return "n.v.t.";
  return code;
}

export function fmtDate(d: string | null) {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("nl-NL", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  });
}
