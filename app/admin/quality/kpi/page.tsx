import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { kpiStatusBadge } from "@/lib/format";
import { t, getLocale } from "@/lib/i18n";

export const dynamic = "force-dynamic";

// Taalbewust decimaalteken (NL komma, EN punt).
function dec(s: string) {
  return getLocale() === "en" ? s : s.replace(".", ",");
}

// Aantal werkdagen tussen twee datums (incl. begindatum, excl. weekenden).
// Benadering: tellen ma-vr; feestdagen worden niet meegenomen.
function workdaysBetween(from: Date, to: Date): number {
  if (to < from) return 0;
  let n = 0;
  const d = new Date(from);
  d.setHours(0, 0, 0, 0);
  const end = new Date(to);
  end.setHours(0, 0, 0, 0);
  while (d <= end) {
    const day = d.getDay();
    if (day !== 0 && day !== 6) n++;
    d.setDate(d.getDate() + 1);
  }
  return n;
}

function pct(part: number, whole: number): number | null {
  if (!whole) return null;
  return Math.round((part / whole) * 1000) / 10;
}

// Status t.o.v. target. higherIsBetter=false -> lager is beter (bv. ongevallen).
function statusVs(
  value: number | null,
  target: number,
  higherIsBetter = true
): "ok" | "warn" | "bad" | "idle" {
  if (value === null || Number.isNaN(value)) return "idle";
  if (higherIsBetter) {
    if (value >= target) return "ok";
    if (value >= target * 0.9) return "warn";
    return "bad";
  } else {
    if (value <= target) return "ok";
    if (value <= target + 1) return "warn";
    return "bad";
  }
}

function KpiCard({
  value,
  label,
  status,
}: {
  value: string;
  label: string;
  status?: "ok" | "warn" | "bad" | "idle";
}) {
  const cls = status && status !== "idle" ? ` kpi-${status}` : "";
  return (
    <div className={`kpi${cls}`}>
      <div className="kpi-value">{value}</div>
      <div className="kpi-label">{label}</div>
    </div>
  );
}

export default async function QmsKpiPage() {
  const T = t();
  const supabase = createClient();
  const now = new Date();
  const yearStart = new Date(now.getFullYear(), 0, 1);

  // Alle bronnen parallel ophalen; bij ontbrekende tabel/RLS -> lege data.
  const [
    mockRes,
    examRes,
    complaintsRes,
    improvementsRes,
    incidentsRes,
    enrollmentsRes,
    progressRes,
    objectivesRes,
  ] = await Promise.all([
    supabase.from("quiz_attempts").select("passed, kind").eq("kind", "mock"),
    supabase.from("exam_results").select("outcome, kind").eq("kind", "knowledge_mcq"),
    supabase.from("qms_complaints").select("status, report_date, closed_date, due_date"),
    supabase.from("qms_improvements").select("status, due_date, closed_date"),
    supabase.from("qms_incidents").select("kind, severity, status, report_date, created_at"),
    supabase.from("enrollments").select("status"),
    supabase.from("module_progress").select("status"),
    supabase.from("qms_objectives").select("*").order("sort_order"),
  ]);

  const mocks = (mockRes.data as any[]) ?? [];
  const exams = (examRes.data as any[]) ?? [];
  const complaints = (complaintsRes.data as any[]) ?? [];
  const improvements = (improvementsRes.data as any[]) ?? [];
  const incidents = (incidentsRes.data as any[]) ?? [];
  const enrollments = (enrollmentsRes.data as any[]) ?? [];
  const progress = (progressRes.data as any[]) ?? [];
  const objectives = (objectivesRes.data as any[]) ?? [];

  // --- 1. SLAAGPERCENTAGE (theorie) ---------------------------------
  // mock-examens (quiz_attempts.passed) + kennistoetsen (exam_results.outcome)
  const mockTotal = mocks.length;
  const mockPassed = mocks.filter((m) => m.passed === true).length;
  const examTotal = exams.filter((e) => e.outcome === "passed" || e.outcome === "failed").length;
  const examPassed = exams.filter((e) => e.outcome === "passed").length;
  const passTotal = mockTotal + examTotal;
  const passOk = mockPassed + examPassed;
  const passPct = pct(passOk, passTotal);
  const passStatus = statusVs(passPct, 80, true);

  // --- 2. KLACHTEN --------------------------------------------------
  const cOpen = complaints.filter((c) => c.status === "open").length;
  const cBusy = complaints.filter((c) => c.status === "in_behandeling").length;
  const cClosed = complaints.filter((c) => c.status === "gesloten").length;
  // % binnen termijn: gesloten klachten waarvan afhandeling <= 20 werkdagen
  // (gemeten van meldingsdatum tot afsluitdatum). Geen datums -> niet meegeteld.
  let cMeasured = 0;
  let cWithinTerm = 0;
  for (const c of complaints) {
    if (c.status !== "gesloten" || !c.report_date || !c.closed_date) continue;
    cMeasured++;
    const wd = workdaysBetween(new Date(c.report_date), new Date(c.closed_date));
    if (wd <= 20) cWithinTerm++;
  }
  const cWithinPct = pct(cWithinTerm, cMeasured);
  const cStatus = statusVs(cWithinPct, 95, true);

  // --- 3. CAPA / VERBETERINGEN --------------------------------------
  const iOpen = improvements.filter((i) => i.status !== "gesloten").length;
  const iClosed = improvements.filter((i) => i.status === "gesloten").length;
  // te laat: streefdatum verstreken en (nog) niet gesloten
  const iOverdue = improvements.filter(
    (i) => i.status !== "gesloten" && i.due_date && new Date(i.due_date) < now
  ).length;
  // % op tijd afgerond: gesloten zonder overschrijding (closed_date <= due_date)
  let iMeasured = 0;
  let iOnTime = 0;
  for (const i of improvements) {
    if (i.status !== "gesloten" || !i.due_date) continue;
    iMeasured++;
    if (!i.closed_date || new Date(i.closed_date) <= new Date(i.due_date)) iOnTime++;
  }
  const iOnTimePct = pct(iOnTime, iMeasured);
  const iStatus = statusVs(iOnTimePct, 90, true);

  // --- 4. INCIDENTEN / BIJNA-ONGEVALLEN (YTD) -----------------------
  const incYtd = incidents.filter((x) => {
    const d = x.report_date ? new Date(x.report_date) : x.created_at ? new Date(x.created_at) : null;
    return d ? d >= yearStart : false;
  });
  const ongevallenYtd = incYtd.filter((x) => x.kind === "ongeval").length;
  const bijnaYtd = incYtd.filter((x) => x.kind === "bijna_ongeval").length;
  const ernstigYtd = incYtd.filter((x) => x.kind === "ongeval" && x.severity === "hoog").length;
  const ernstigStatus = statusVs(ernstigYtd, 0, false);

  // --- 5. CURSISTEN / VOORTGANG -------------------------------------
  const activeEnroll = enrollments.filter(
    (e) => e.status === "enrolled" || e.status === "active"
  ).length;
  const progDone = progress.filter((p) => p.status === "completed").length;
  const progTotal = progress.length;
  const avgProgress = pct(progDone, progTotal);

  // --- Doelstellingen-tabel: live actuele waarde waar berekenbaar ----
  // Map per doelstellingscode -> {actual, status}. Onbekend = null.
  const actuals: Record<string, { actual: number | null; status: "ok" | "warn" | "bad" | "idle" }> = {
    D1: { actual: passPct, status: passStatus },
    D2: { actual: cWithinPct, status: cStatus },
    D3: { actual: iOnTimePct, status: iStatus },
    D4: { actual: ernstigYtd, status: ernstigStatus },
    // D5 (tevredenheid) en D6 (audit/directiebeoordeling): handmatig.
  };

  const fmtNum = (v: number | null, eenheid: string | null) =>
    v === null ? "—" : `${dec(String(v))}${eenheid === "%" ? "%" : ""}`;

  return (
    <>
      <h1 className="page-title">{T.kpi_title}</h1>
      <p className="page-sub">{T.kpi_sub}</p>
      <p className="small" style={{ marginTop: -6 }}>
        <Link href="/admin/quality">{T.kpi_to_handbook}</Link>
        {" · "}
        <Link href="/admin/quality/registers">{T.kpi_to_registers}</Link>
        {" · "}
        <Link href="/admin/quality/registers/risks">{T.kpi_to_risks}</Link>
      </p>

      {/* Onderwijsprestatie */}
      <div className="card">
        <h2>{T.kpi_edu_title}</h2>
        <div className="kpis">
          <KpiCard
            value={passPct === null ? "—" : `${dec(String(passPct))}%`}
            label={T.kpi_passrate}
            status={passStatus}
          />
          <KpiCard value={String(passOk)} label={T.kpi_passed_of.replace("{n}", String(passTotal))} />
          <KpiCard value={String(activeEnroll)} label={T.kpi_active_enroll} />
          <KpiCard
            value={avgProgress === null ? "—" : `${dec(String(avgProgress))}%`}
            label={T.kpi_avg_progress}
          />
        </div>
      </div>

      {/* Klachten */}
      <div className="card">
        <h2>{T.kpi_complaints_title}</h2>
        <div className="kpis">
          <KpiCard value={String(cOpen)} label={T.kpi_open} status={cOpen > 0 ? "warn" : "ok"} />
          <KpiCard value={String(cBusy)} label={T.kpi_in_progress} />
          <KpiCard value={String(cClosed)} label={T.kpi_closed} />
          <KpiCard
            value={cWithinPct === null ? "—" : `${dec(String(cWithinPct))}%`}
            label={T.kpi_within_term}
            status={cStatus}
          />
        </div>
      </div>

      {/* CAPA / verbeteringen */}
      <div className="card">
        <h2>{T.kpi_capa_title}</h2>
        <div className="kpis">
          <KpiCard value={String(iOpen)} label={T.kpi_running} />
          <KpiCard value={String(iOverdue)} label={T.kpi_overdue} status={iOverdue > 0 ? "bad" : "ok"} />
          <KpiCard value={String(iClosed)} label={T.kpi_closed} />
          <KpiCard
            value={iOnTimePct === null ? "—" : `${dec(String(iOnTimePct))}%`}
            label={T.kpi_ontime}
            status={iStatus}
          />
        </div>
      </div>

      {/* Incidenten YTD */}
      <div className="card">
        <h2>{T.kpi_inc_title}</h2>
        <div className="kpis">
          <KpiCard value={String(ongevallenYtd)} label={T.kpi_accidents_ytd} status={ongevallenYtd > 0 ? "warn" : "ok"} />
          <KpiCard value={String(bijnaYtd)} label={T.kpi_nearmiss_ytd} />
          <KpiCard value={String(ernstigYtd)} label={T.kpi_serious} status={ernstigStatus} />
          <KpiCard value={String(incYtd.length)} label={T.kpi_total_ytd} />
        </div>
      </div>

      {/* Kwaliteitsdoelstellingen */}
      <div className="card">
        <h2>{T.kpi_obj_title}</h2>
        <p className="muted small" style={{ marginTop: -8 }}>{T.kpi_obj_sub}</p>
        <table>
          <thead>
            <tr>
              <th>{T.kpi_obj_code}</th>
              <th>{T.kpi_obj_goal}</th>
              <th>{T.kpi_obj_target}</th>
              <th>{T.kpi_obj_actual}</th>
              <th>{T.kpi_obj_source}</th>
              <th>{T.kpi_obj_status}</th>
            </tr>
          </thead>
          <tbody>
            {objectives.length === 0 ? (
              <tr>
                <td colSpan={6} className="muted small">{T.kpi_obj_none}</td>
              </tr>
            ) : (
              objectives.map((o) => {
                const a = (o.code && actuals[o.code]) || { actual: null, status: "idle" as const };
                const st = kpiStatusBadge(a.status);
                return (
                  <tr key={o.id}>
                    <td className="small">{o.code ?? "—"}</td>
                    <td>
                      <strong>{o.naam}</strong>
                      <div className="muted small">{o.doelstelling}</div>
                    </td>
                    <td className="muted small">
                      {o.target === null || o.target === undefined
                        ? "—"
                        : `${dec(String(o.target))}${o.eenheid && o.eenheid !== "%" ? " " + o.eenheid : o.eenheid === "%" ? "%" : ""}`}
                    </td>
                    <td className="small">{fmtNum(a.actual, o.eenheid)}</td>
                    <td className="muted small">{o.meet_bron ?? "—"}</td>
                    <td>
                      <span className={`badge ${st.cls}`}>{st.label}</span>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
    </>
  );
}
