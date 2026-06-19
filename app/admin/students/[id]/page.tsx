import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { progressBadge, examBadge, examKindLabel, fmtDate } from "@/lib/format";
import { updateModuleStatus, updateExamOutcome, addCertificate, uploadCertificateFile, updateStudent } from "./actions";
import { createStudentLogin } from "@/app/admin/account-actions";
import CreateLogin from "@/components/CreateLogin";

export const dynamic = "force-dynamic";

export default async function StudentDossier({ params }: { params: { id: string } }) {
  const supabase = createClient();

  const { data: student } = await supabase
    .from("students")
    .select("*")
    .eq("id", params.id)
    .single();

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
        .select("id, kind, attempt, exam_date, examiner_name, score, max_score, outcome, valid_until, remarks")
        .eq("enrollment_id", enr.id)
        .order("kind")
    : { data: [] as any[] };

  const { data: certs } = await supabase
    .from("certificates")
    .select("id, certificate_number, title, regulatory_reference, issued_date, expiry_date, file_path")
    .eq("student_id", params.id);

  // Tijdelijke download-links (signed URLs) voor geüploade certificaat-PDF's
  const certList = (certs as any[]) ?? [];
  const signed: Record<string, string> = {};
  for (const c of certList) {
    if (c.file_path) {
      const { data: s } = await supabase.storage
        .from("certificates")
        .createSignedUrl(c.file_path, 3600);
      if (s?.signedUrl) signed[c.id] = s.signedUrl;
    }
  }

  const { data: audit } = await supabase
    .from("audit_log")
    .select("action, table_name, changed_by_email, changed_at")
    .order("changed_at", { ascending: false })
    .limit(8);

  const done = mods.filter((m) => m.status === "completed").length;
  const pct = mods.length ? Math.round((done / mods.length) * 100) : 0;

  return (
    <>
      <p className="small">
        <Link href="/admin">← Terug naar cursisten</Link>
      </p>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 16 }}>
        <div>
          <h1 className="page-title">
            {student.first_name} {student.last_name}
          </h1>
          <p className="page-sub">
            {student.student_number} · {enr?.courses?.title ?? "Geen inschrijving"}
          </p>
        </div>
        <Link className="btn ghost" href={`/report/${student.id}`}>
          ILT-exportrapport
        </Link>
      </div>

      <div className="grid-2">
        <div className="card">
          <h2>Persoonsgegevens</h2>
          <dl className="kv">
            <dt>Cursistnummer</dt><dd>{student.student_number}</dd>
            <dt>Geboortedatum</dt><dd>{fmtDate(student.date_of_birth)}</dd>
            <dt>Geboorteplaats</dt><dd>{student.place_of_birth ?? "—"}</dd>
            <dt>Identiteit</dt>
            <dd>
              {student.identity_verified
                ? <span className="badge ok">Gecontroleerd{student.id_document_type ? ` (${student.id_document_type})` : ""}</span>
                : <span className="badge warn">Niet gecontroleerd</span>}
            </dd>
            <dt>E-mail</dt><dd>{student.email ?? "—"}</dd>
            <dt>Telefoon</dt><dd>{student.phone ?? "—"}</dd>
            <dt>Nationaliteit</dt><dd>{student.nationality ?? "—"}</dd>
            <dt>Adres</dt><dd>{student.address ?? "—"}</dd>
            <dt>RYA-nummer</dt><dd>{student.rya_number ?? "—"}</dd>
          </dl>

          <div style={{ marginTop: 14, paddingTop: 12, borderTop: "1px solid var(--line)" }}>
            <div className="flabel">Toegang tot studentportaal</div>
            {student.profile_id ? (
              <span className="badge ok">Inlog actief{student.email ? ` · ${student.email}` : ""}</span>
            ) : (
              <CreateLogin
                action={createStudentLogin}
                recordId={student.id}
                idField="student_id"
                defaultEmail={student.email}
              />
            )}
          </div>

          <details style={{ marginTop: 12 }}>
            <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>
              Gegevens bewerken
            </summary>
            <form action={updateStudent} style={{ marginTop: 12, display: "grid", gap: 8 }}>
              <input type="hidden" name="student_id" value={student.id} />
              <div className="grid-2">
                <input name="first_name" defaultValue={student.first_name} placeholder="Voornaam" required />
                <input name="last_name" defaultValue={student.last_name} placeholder="Achternaam" required />
                <input name="date_of_birth" type="date" defaultValue={student.date_of_birth ?? ""} required />
                <input name="place_of_birth" defaultValue={student.place_of_birth ?? ""} placeholder="Geboorteplaats" />
                <input name="email" defaultValue={student.email ?? ""} placeholder="E-mail" />
                <input name="phone" defaultValue={student.phone ?? ""} placeholder="Telefoon" />
                <input name="nationality" defaultValue={student.nationality ?? ""} placeholder="Nationaliteit" />
                <input name="address" defaultValue={student.address ?? ""} placeholder="Adres" />
                <input name="id_document_type" defaultValue={student.id_document_type ?? ""} placeholder="Documenttype" />
                <input name="rya_number" defaultValue={student.rya_number ?? ""} placeholder="RYA-nummer" />
              </div>
              <label className="small">
                <input type="checkbox" name="identity_verified" defaultChecked={student.identity_verified}
                       style={{ width: "auto", marginRight: 8 }} />
                Identiteit gecontroleerd
              </label>
              <button className="btn sm" type="submit" style={{ justifySelf: "start" }}>Opslaan</button>
            </form>
          </details>
        </div>
        <div className="card">
          <h2>Inschrijving</h2>
          <dl className="kv">
            <dt>Opleiding</dt><dd>{enr?.courses?.code ?? "—"} — {enr?.courses?.title ?? ""}</dd>
            <dt>Kader</dt><dd>{enr?.courses?.regulatory_reference ?? "—"}</dd>
            <dt>Status</dt><dd>{enr?.status ?? "—"}</dd>
            <dt>Startdatum</dt><dd>{fmtDate(enr?.start_date)}</dd>
            <dt>Streefdatum</dt><dd>{fmtDate(enr?.target_end_date)}</dd>
            <dt>Voortgang</dt>
            <dd>
              <div className="progress-wrap" style={{ maxWidth: 220 }}>
                <div className="progress-bar" style={{ width: `${pct}%` }} />
              </div>
              <span className="muted small">{done}/{mods.length} modules · {pct}%</span>
            </dd>
          </dl>
        </div>
      </div>

      <div className="card">
        <h2>Voortgang per module</h2>
        <table>
          <thead>
            <tr>
              <th>#</th><th>Module</th><th>Uren</th><th>Instructeur</th>
              <th>Status</th><th>Wijzig</th>
            </tr>
          </thead>
          <tbody>
            {mods.map((m) => {
              const b = progressBadge(m.status);
              return (
                <tr key={m.id}>
                  <td className="muted small">{m.modules?.code}</td>
                  <td>{m.modules?.title}</td>
                  <td className="muted small">{m.hours_logged}/{m.modules?.required_hours}</td>
                  <td className="muted small">{m.instructor_name ?? "—"}</td>
                  <td><span className={`badge ${b.cls}`}>{b.label}</span></td>
                  <td>
                    <form action={updateModuleStatus} style={{ display: "flex", gap: 6 }}>
                      <input type="hidden" name="progress_id" value={m.id} />
                      <input type="hidden" name="student_id" value={student.id} />
                      <select name="status" defaultValue={m.status} className="small">
                        <option value="not_started">Nog niet gestart</option>
                        <option value="in_progress">Onderweg</option>
                        <option value="completed">Afgerond</option>
                      </select>
                      <button className="btn sm" type="submit">Opslaan</button>
                    </form>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="card">
        <h2>Examenresultaten</h2>
        <p className="muted small" style={{ marginTop: -8 }}>
          Examinator is bewust apart vastgelegd (ILT-eis: niet de eigen instructeur).
        </p>
        <table>
          <thead>
            <tr>
              <th>Onderdeel</th><th>Poging</th><th>Datum</th><th>Examinator</th>
              <th>Score</th><th>Geldig t/m</th><th>Uitslag</th><th>Wijzig</th>
            </tr>
          </thead>
          <tbody>
            {((exams as any[]) ?? []).map((x) => {
              const b = examBadge(x.outcome);
              return (
                <tr key={x.id}>
                  <td>{examKindLabel(x.kind)}</td>
                  <td className="muted small">{x.attempt}</td>
                  <td className="muted small">{fmtDate(x.exam_date)}</td>
                  <td className="muted small">{x.examiner_name ?? "—"}</td>
                  <td className="muted small">{x.score != null ? `${x.score}/${x.max_score}` : "—"}</td>
                  <td className="muted small">{fmtDate(x.valid_until)}</td>
                  <td><span className={`badge ${b.cls}`}>{b.label}</span></td>
                  <td>
                    <form action={updateExamOutcome} style={{ display: "flex", gap: 6 }}>
                      <input type="hidden" name="exam_id" value={x.id} />
                      <input type="hidden" name="student_id" value={student.id} />
                      <select name="outcome" defaultValue={x.outcome} className="small">
                        <option value="pending">Gepland / open</option>
                        <option value="passed">Geslaagd</option>
                        <option value="failed">Niet geslaagd</option>
                      </select>
                      <button className="btn sm" type="submit">Opslaan</button>
                    </form>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="card">
        <h2>Certificatenregister</h2>
        {certList.length === 0 ? (
          <p className="muted small">Nog geen certificaten.</p>
        ) : (
          <table>
            <thead>
              <tr><th>Nummer</th><th>Titel</th><th>Afgegeven</th><th>Geldig t/m</th><th>PDF</th></tr>
            </thead>
            <tbody>
              {certList.map((c) => (
                <tr key={c.id}>
                  <td className="muted small">{c.certificate_number}</td>
                  <td>{c.title}</td>
                  <td className="muted small">{fmtDate(c.issued_date)}</td>
                  <td className="muted small">{fmtDate(c.expiry_date)}</td>
                  <td>
                    {signed[c.id] ? (
                      <a className="small" href={signed[c.id]} target="_blank" rel="noreferrer">
                        Download
                      </a>
                    ) : (
                      <form action={uploadCertificateFile} encType="multipart/form-data"
                            style={{ display: "flex", gap: 6, alignItems: "center" }}>
                        <input type="hidden" name="student_id" value={student.id} />
                        <input type="hidden" name="certificate_id" value={c.id} />
                        <input type="file" name="file" accept="application/pdf" className="small" required />
                        <button className="btn sm" type="submit">Upload</button>
                      </form>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}

        <details style={{ marginTop: 14 }}>
          <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>
            + Certificaat toevoegen
          </summary>
          <form action={addCertificate}
                style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, marginTop: 12, maxWidth: 560 }}>
            <input type="hidden" name="student_id" value={student.id} />
            <input name="certificate_number" placeholder="Certificaatnummer" required />
            <input name="title" placeholder="Titel" required />
            <input name="regulatory_reference" placeholder="Kader (bv. SCV Code Ch X)" />
            <input name="issued_date" type="date" title="Afgiftedatum" />
            <input name="expiry_date" type="date" title="Geldig t/m" />
            <button className="btn" type="submit">Opslaan</button>
          </form>
        </details>
      </div>

      <div className="card">
        <h2>Wijzigingshistorie (audit)</h2>
          <p className="muted small" style={{ marginTop: -8 }}>
            Onveranderbaar spoor — wie wijzigde wat, wanneer.
          </p>
          <table>
            <thead>
              <tr><th>Actie</th><th>Tabel</th><th>Door</th><th>Wanneer</th></tr>
            </thead>
            <tbody>
              {((audit as any[]) ?? []).map((a, i) => (
                <tr key={i}>
                  <td className="muted small">{a.action}</td>
                  <td className="muted small">{a.table_name}</td>
                  <td className="muted small">{a.changed_by_email ?? "systeem"}</td>
                  <td className="muted small">
                    {new Date(a.changed_at).toLocaleString("nl-NL")}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
    </>
  );
}
