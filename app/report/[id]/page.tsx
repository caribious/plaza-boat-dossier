import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getProfile } from "@/lib/getProfile";
import { progressBadge, examBadge, examKindLabel, fmtDate, qualificationKindLabel, expiryBadge, hasValidVhf } from "@/lib/format";
import PrintButton from "@/components/PrintButton";

export const dynamic = "force-dynamic";

export default async function Report({ params }: { params: { id: string } }) {
  // Alleen staff mag het rapport openen
  const profile = await getProfile();
  if (!profile) redirect("/login");
  if (profile.role === "student") redirect("/student");

  const supabase = createClient();

  const { data: student } = await supabase
    .from("students").select("*").eq("id", params.id).single();
  if (!student) notFound();

  const { data: enrollment } = await supabase
    .from("enrollments")
    .select("id, status, start_date, target_end_date, courses ( code, title, regulatory_reference )")
    .eq("student_id", params.id)
    .order("created_at", { ascending: false })
    .limit(1)
    .single();
  const enr: any = enrollment;

  const { data: progress } = enr
    ? await supabase
        .from("module_progress")
        .select("id, status, hours_logged, instructor_name, modules ( sequence, code, title, required_hours )")
        .eq("enrollment_id", enr.id)
    : { data: [] as any[] };
  const mods = (progress as any[]) ?? [];
  mods.sort((a, b) => (a.modules?.sequence ?? 0) - (b.modules?.sequence ?? 0));

  const { data: exams } = enr
    ? await supabase
        .from("exam_results")
        .select("id, kind, attempt, exam_date, examiner_name, score, max_score, outcome, valid_until")
        .eq("enrollment_id", enr.id)
        .order("kind")
    : { data: [] as any[] };

  const { data: certs } = await supabase
    .from("certificates")
    .select("certificate_number, title, regulatory_reference, issued_date, expiry_date")
    .eq("student_id", params.id);

  const { data: quals } = await supabase
    .from("student_qualifications")
    .select("id, kind, title, number, issuer, issue_date, valid_until, verified, verified_by")
    .eq("student_id", params.id)
    .order("kind");
  const qualList = (quals as any[]) ?? [];
  const vhfValid = hasValidVhf(qualList);

  const done = mods.filter((m) => m.status === "completed").length;
  const totalHours = mods.reduce((s, m) => s + Number(m.hours_logged || 0), 0);
  const pct = mods.length ? Math.round((done / mods.length) * 100) : 0;
  const now = new Date().toLocaleString("nl-NL");

  return (
    <div className="report">
      <div className="toolbar no-print">
        <Link className="btn ghost" href={profile.role === "auditor" ? "/ilt/students" : `/admin/students/${student.id}`}>
          ← Terug
        </Link>
        <PrintButton />
      </div>

      <div className="report-head">
        <div className="org">
          Plaza Boat College
          <small>Plaza Marina, Bonaire · Erkende maritieme opleiding (SCV Code / RVZ Bijlage 6)</small>
        </div>
        <div className="meta">
          Cursistdossier — export<br />
          Gegenereerd: {now}<br />
          Door: {profile.full_name || profile.email}
        </div>
      </div>

      <h1>{student.first_name} {student.last_name}</h1>
      <p className="muted small">
        Cursistnummer {student.student_number} · {enr?.courses?.code ?? "—"} {enr?.courses?.title ?? ""}
      </p>

      <h3>Persoons- en inschrijfgegevens</h3>
      <dl className="kv">
        <dt>Geboortedatum</dt><dd>{fmtDate(student.date_of_birth)}</dd>
        <dt>Geboorteplaats</dt><dd>{student.place_of_birth ?? "—"}</dd>
        <dt>Identiteit gecontroleerd</dt>
        <dd>{student.identity_verified ? `Ja${student.id_document_type ? ` (${student.id_document_type})` : ""}` : "Nee"}</dd>
        <dt>Nationaliteit</dt><dd>{student.nationality ?? "—"}</dd>
        <dt>RYA-nummer</dt><dd>{student.rya_number ?? "—"}</dd>
        <dt>E-mail</dt><dd>{student.email ?? "—"}</dd>
        <dt>Telefoon</dt><dd>{student.phone ?? "—"}</dd>
        <dt>Opleiding</dt><dd>{enr?.courses?.title ?? "—"}</dd>
        <dt>Regelgevend kader</dt><dd>{enr?.courses?.regulatory_reference ?? "—"}</dd>
        <dt>Status</dt><dd>{enr?.status ?? "—"}</dd>
        <dt>Startdatum</dt><dd>{fmtDate(enr?.start_date)}</dd>
        <dt>Streefdatum</dt><dd>{fmtDate(enr?.target_end_date)}</dd>
        <dt>Voortgang</dt><dd>{done}/{mods.length} modules ({pct}%) · {totalHours} contacturen geregistreerd</dd>
      </dl>

      <h3>Voortgang per module</h3>
      <table>
        <thead>
          <tr><th>#</th><th>Module</th><th>Uren</th><th>Instructeur</th><th>Status</th></tr>
        </thead>
        <tbody>
          {mods.map((m) => (
            <tr key={m.id}>
              <td className="muted small">{m.modules?.code}</td>
              <td>{m.modules?.title}</td>
              <td className="muted small">{m.hours_logged}/{m.modules?.required_hours}</td>
              <td className="muted small">{m.instructor_name ?? "—"}</td>
              <td>{progressBadge(m.status).label}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <h3>Examenresultaten</h3>
      <table>
        <thead>
          <tr><th>Onderdeel</th><th>Poging</th><th>Datum</th><th>Examinator</th><th>Score</th><th>Geldig t/m</th><th>Uitslag</th></tr>
        </thead>
        <tbody>
          {((exams as any[]) ?? []).map((x) => (
            <tr key={x.id}>
              <td>{examKindLabel(x.kind)}</td>
              <td className="muted small">{x.attempt}</td>
              <td className="muted small">{fmtDate(x.exam_date)}</td>
              <td className="muted small">{x.examiner_name ?? "—"}</td>
              <td className="muted small">{x.score != null ? `${x.score}/${x.max_score}` : "—"}</td>
              <td className="muted small">{fmtDate(x.valid_until)}</td>
              <td>{examBadge(x.outcome).label}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <h3>Toelatingseisen &amp; kwalificaties</h3>
      <p className="muted small" style={{ marginTop: -6 }}>
        Verplichte toelatingseis VHF (SCV Code X/6.1 — Reg 10.11):{" "}
        {vhfValid ? "geldig certificaat aanwezig." : "GEEN geldig VHF-certificaat vastgelegd."}
      </p>
      {qualList.length === 0 ? (
        <p className="muted small">Nog geen toelatingseisen/kwalificaties vastgelegd.</p>
      ) : (
        <table>
          <thead>
            <tr><th>Type</th><th>Nummer</th><th>Uitgever</th><th>Afgegeven</th><th>Geldig t/m</th><th>Geverifieerd</th></tr>
          </thead>
          <tbody>
            {qualList.map((q) => (
              <tr key={q.id}>
                <td>{qualificationKindLabel(q.kind)}{q.title ? ` — ${q.title}` : ""}</td>
                <td className="muted small">{q.number ?? "—"}</td>
                <td className="muted small">{q.issuer ?? "—"}</td>
                <td className="muted small">{fmtDate(q.issue_date)}</td>
                <td className="muted small">{fmtDate(q.valid_until)} · {expiryBadge(q.valid_until).label}</td>
                <td className="muted small">{q.verified ? `Ja${q.verified_by ? ` (${q.verified_by})` : ""}` : "Nee"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <h3>Certificatenregister</h3>
      {((certs as any[]) ?? []).length === 0 ? (
        <p className="muted small">Nog geen certificaten.</p>
      ) : (
        <table>
          <thead>
            <tr><th>Nummer</th><th>Titel</th><th>Kader</th><th>Afgegeven</th><th>Geldig t/m</th></tr>
          </thead>
          <tbody>
            {((certs as any[]) ?? []).map((c) => (
              <tr key={c.certificate_number}>
                <td className="muted small">{c.certificate_number}</td>
                <td>{c.title}</td>
                <td className="muted small">{c.regulatory_reference ?? "—"}</td>
                <td className="muted small">{fmtDate(c.issued_date)}</td>
                <td className="muted small">{fmtDate(c.expiry_date)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <div className="sig">
        <div className="line">Handtekening examinator / verantwoordelijke</div>
        <div className="line">Datum &amp; plaats</div>
      </div>

      <p className="muted small" style={{ marginTop: 30 }}>
        Dit rapport is automatisch gegenereerd uit de leerlingadministratie van Plaza Boat College.
        Alle wijzigingen aan dit dossier worden vastgelegd in een onveranderbaar audit-spoor.
      </p>
    </div>
  );
}
