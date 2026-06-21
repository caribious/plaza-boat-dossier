import Link from "next/link";
import { createAdminClient } from "@/lib/supabase/admin";
import { normCode } from "@/lib/learn";
import { t } from "@/lib/i18n";

export const dynamic = "force-dynamic";

interface Row {
  ref: string;
  meaning: string;
  official: boolean;
  modules: { seq: number; label: string }[];
  reader: boolean;
  slides: boolean;
  quiz: number;
}

function short(s: string, n = 90) {
  s = (s || "").replace(/\s+/g, " ").trim();
  return s.length > n ? s.slice(0, n - 1) + "…" : s;
}

export default async function SyllabusMatrix() {
  const T = t();
  const admin = createAdminClient();
  const { data: coursesData } = await admin.from("courses").select("id, code, title").order("code");
  const { data: modulesData } = await admin.from("modules").select("course_id, sequence, code, title, reader_path, deck_path");
  const { data: questionsData } = await admin.from("questions").select("course_code, module_seq, ref, stem");
  const { data: refDescData } = await admin.from("qms_ref_descriptions").select("ref, description");

  const courses = (coursesData as any[]) ?? [];
  const modules = (modulesData as any[]) ?? [];
  const questions = (questionsData as any[]) ?? [];
  const refDesc = new Map<string, string>();
  for (const r of (refDescData as any[]) ?? []) refDesc.set(r.ref, r.description);

  function buildRows(course: any): Row[] {
    const mods = modules.filter((m) => m.course_id === course.id);
    const bySeq = new Map<number, any>();
    for (const m of mods) bySeq.set(m.sequence, m);
    const qs = questions.filter((q) => q.ref && normCode(q.course_code) === normCode(course.code));
    const byRef = new Map<string, { seqs: Set<number>; count: number; stem: string }>();
    for (const q of qs) {
      const r = String(q.ref).trim();
      if (!r) continue;
      if (!byRef.has(r)) byRef.set(r, { seqs: new Set(), count: 0, stem: q.stem ?? "" });
      const e = byRef.get(r)!;
      e.count++;
      if (q.module_seq != null) e.seqs.add(q.module_seq);
    }
    const rows: Row[] = [];
    for (const [ref, e] of byRef) {
      const seqs = [...e.seqs].sort((a, b) => a - b);
      const modsForRef = seqs.map((s) => bySeq.get(s)).filter(Boolean);
      const official = refDesc.has(ref);
      rows.push({
        ref,
        meaning: official ? refDesc.get(ref)! : short(e.stem),
        official,
        modules: seqs.map((s) => ({ seq: s, label: bySeq.get(s)?.code ?? `M${s}` })),
        reader: modsForRef.some((m) => !!m.reader_path),
        slides: modsForRef.some((m) => !!m.deck_path),
        quiz: e.count,
      });
    }
    rows.sort((a, b) => (a.modules[0]?.seq ?? 99) - (b.modules[0]?.seq ?? 99) || a.ref.localeCompare(b.ref));
    return rows;
  }

  const yes = (b: boolean) => b ? <span className="badge ok">✓</span> : <span className="badge idle">—</span>;

  return (
    <>
      <h1 className="page-title">{T.sm_title}</h1>
      <p className="page-sub">{T.sm_sub}</p>
      <p className="small" style={{ marginTop: -6 }}><Link href="/admin/quality">← {T.q_title}</Link></p>

      {courses.map((c) => {
        const rows = buildRows(c);
        const readerCov = rows.filter((r) => r.reader).length;
        const slidesCov = rows.filter((r) => r.slides).length;
        return (
          <div className="card" key={c.id}>
            <details open>
              <summary style={{ cursor: "pointer" }}>
                <strong>{c.code} — {c.title}</strong>
                <span className="muted small"> · {rows.length} {T.sm_refs} · reader {readerCov}/{rows.length} · slides {slidesCov}/{rows.length}</span>
              </summary>
              {rows.length === 0 ? (
                <p className="muted small" style={{ marginTop: 10 }}>{T.sm_none}</p>
              ) : (
                <table style={{ marginTop: 10 }}>
                  <thead>
                    <tr><th>{T.sm_req}</th><th>{T.sm_meaning}</th><th>{T.sm_modules}</th><th>{T.sm_reader}</th><th>{T.sm_slides}</th><th>{T.sm_quiz}</th></tr>
                  </thead>
                  <tbody>
                    {rows.map((r) => (
                      <tr key={r.ref}>
                        <td className="small"><strong>{r.ref}</strong></td>
                        <td className="small">
                          {r.official ? r.meaning : <span className="muted" style={{ fontStyle: "italic" }} title="Afgeleid uit de examenvraag (geen officiële omschrijving op dossier)">{r.meaning}</span>}
                        </td>
                        <td className="muted small">
                          {r.modules.length === 0 ? "—" : r.modules.map((m, i) => (
                            <span key={m.seq}>{i > 0 ? ", " : ""}<Link href={`/admin/content/${normCode(c.code)}/${m.seq}`}>{m.label}</Link></span>
                          ))}
                        </td>
                        <td>{yes(r.reader)}</td>
                        <td>{yes(r.slides)}</td>
                        <td><span className="badge ok">{r.quiz}</span></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </details>
          </div>
        );
      })}

      <p className="small muted">{T.sm_note} <em>Cursief = afgeleid uit de examenvraag; rechtop = officiële SCV/Annex 11-omschrijving.</em></p>
    </>
  );
}
