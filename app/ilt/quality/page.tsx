import { createClient } from "@/lib/supabase/server";
import { fmtDate } from "@/lib/format";

export const dynamic = "force-dynamic";

export default async function IltQuality() {
  const supabase = createClient();
  const { data: clauses } = await supabase
    .from("qms_clauses")
    .select("id, clause_number, title, pbc_approach")
    .order("sort_order");
  const { data: docs } = await supabase
    .from("qms_documents")
    .select("id, clause_number, title, doc_type, reference, file_path")
    .order("created_at");

  const docList = (docs as any[]) ?? [];
  const signed: Record<string, string> = {};
  for (const d of docList) {
    if (d.file_path) {
      const { data: s } = await supabase.storage.from("qms-documents").createSignedUrl(d.file_path, 3600);
      if (s?.signedUrl) signed[d.id] = s.signedUrl;
    }
  }

  return (
    <>
      <h1 className="page-title">Kwaliteit — ISO 9001</h1>
      <p className="page-sub">
        Kwaliteitshandboek (KH-001) en kwaliteitsdocumenten (alleen-lezen). Conform NEN-EN-ISO 9001:2015.
      </p>

      <div className="card">
        <h2>Documenten</h2>
        <table>
          <thead><tr><th>Document</th><th>Type</th><th>Referentie</th><th>Hoofdstuk</th><th>PDF</th></tr></thead>
          <tbody>
            {docList.length === 0 ? (
              <tr><td colSpan={5} className="muted small">Geen documenten beschikbaar.</td></tr>
            ) : docList.map((d) => (
              <tr key={d.id}>
                <td>{d.title}</td>
                <td className="muted small">{d.doc_type ?? "—"}</td>
                <td className="muted small">{d.reference ?? "—"}</td>
                <td className="muted small">{d.clause_number ?? "—"}</td>
                <td>{signed[d.id] ? <a className="small" href={signed[d.id]} target="_blank" rel="noreferrer">Download</a> : <span className="muted small">—</span>}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="card">
        <h2>Kwaliteitshandboek per hoofdstuk</h2>
        {(clauses as any[] ?? []).map((c) => (
          <div key={c.id} style={{ padding: "12px 0", borderTop: "1px solid var(--line)" }}>
            <strong>{c.clause_number}. {c.title}</strong>
            <p className="small" style={{ margin: "6px 0 0", whiteSpace: "pre-wrap" }}>{c.pbc_approach}</p>
          </div>
        ))}
      </div>
    </>
  );
}
