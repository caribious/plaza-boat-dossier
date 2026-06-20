import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fmtDate } from "@/lib/format";
import { updateClause, addDocument, uploadDocFile } from "./actions";

export const dynamic = "force-dynamic";

export default async function QualityPage() {
  const supabase = createClient();
  const { data: clauses } = await supabase
    .from("qms_clauses")
    .select("id, clause_number, title, pbc_approach, updated_at")
    .order("sort_order");
  const { data: docs } = await supabase
    .from("qms_documents")
    .select("id, clause_number, title, doc_type, reference, file_path, created_at")
    .order("created_at");

  const docList = (docs as any[]) ?? [];
  const signed: Record<string, string> = {};
  for (const d of docList) {
    if (d.file_path) {
      const { data: s } = await supabase.storage
        .from("qms-documents")
        .createSignedUrl(d.file_path, 3600);
      if (s?.signedUrl) signed[d.id] = s.signedUrl;
    }
  }

  return (
    <>
      <h1 className="page-title">Kwaliteit — ISO 9001</h1>
      <p className="page-sub">
        Kwaliteitshandboek (KH-001) als werkend naslagdocument, met de documentenbibliotheek
        voor audits. Volgt de NEN-EN-ISO 9001:2015-structuur.
      </p>
      <p className="small" style={{ marginTop: -6 }}>
        <Link href="/admin/quality/registers">→ Naar de QMS-registers (incidenten, klachten, verbeteringen)</Link>
      </p>

      <div className="card">
        <h2>Documentenbibliotheek</h2>
        <p className="muted small" style={{ marginTop: -8 }}>
          De gezaghebbende documenten (handboek, onderbouwing, audits). Upload de PDF per document.
        </p>
        <table>
          <thead>
            <tr><th>Document</th><th>Type</th><th>Referentie</th><th>Hoofdstuk</th><th>PDF</th></tr>
          </thead>
          <tbody>
            {docList.length === 0 ? (
              <tr><td colSpan={5} className="muted small">Nog geen documenten. Voeg ze hieronder toe.</td></tr>
            ) : docList.map((d) => (
              <tr key={d.id}>
                <td>{d.title}</td>
                <td className="muted small">{d.doc_type ?? "—"}</td>
                <td className="muted small">{d.reference ?? "—"}</td>
                <td className="muted small">{d.clause_number ?? "—"}</td>
                <td>
                  {signed[d.id] ? (
                    <a className="small" href={signed[d.id]} target="_blank" rel="noreferrer">Download</a>
                  ) : (
                    <form action={uploadDocFile} encType="multipart/form-data" style={{ display: "flex", gap: 6 }}>
                      <input type="hidden" name="document_id" value={d.id} />
                      <input type="file" name="file" accept="application/pdf" className="small" required />
                      <button className="btn sm" type="submit">Upload</button>
                    </form>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <details style={{ marginTop: 14 }}>
          <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>+ Document toevoegen</summary>
          <form action={addDocument} style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, marginTop: 12, maxWidth: 620 }}>
            <input name="title" placeholder="Titel" required />
            <input name="doc_type" placeholder="Type (Procedure/Beleid/Audit/Bewijsstuk)" />
            <input name="reference" placeholder="Referentie (bv. KH-001 v2.0)" />
            <input name="clause_number" placeholder="Hoofdstuk (bv. 7, A)" />
            <button className="btn" type="submit">Opslaan</button>
          </form>
        </details>
      </div>

      <div className="card">
        <h2>Kwaliteitshandboek per hoofdstuk</h2>
        {(clauses as any[] ?? []).map((c) => (
          <div key={c.id} style={{ padding: "14px 0", borderTop: "1px solid var(--line)" }}>
            <strong>{c.clause_number}. {c.title}</strong>
            <p className="small" style={{ margin: "6px 0 0", whiteSpace: "pre-wrap" }}>{c.pbc_approach}</p>
            <details style={{ marginTop: 6 }}>
              <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>Bewerken</summary>
              <form action={updateClause} style={{ marginTop: 8 }}>
                <input type="hidden" name="clause_id" value={c.id} />
                <textarea name="pbc_approach" defaultValue={c.pbc_approach ?? ""} rows={5}
                          style={{ width: "100%", fontFamily: "inherit", fontSize: 14, padding: 8, borderRadius: 8, border: "1px solid var(--line)" }} />
                <button className="btn sm" type="submit" style={{ marginTop: 8 }}>Opslaan</button>
              </form>
            </details>
          </div>
        ))}
      </div>
    </>
  );
}
