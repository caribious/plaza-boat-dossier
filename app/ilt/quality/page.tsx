import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { t } from "@/lib/i18n";

export const dynamic = "force-dynamic";

export default async function IltQuality() {
  const T = t();
  const supabase = createClient();
  const { data: clauses } = await supabase
    .from("qms_clauses").select("id, clause_number, title, pbc_approach").order("sort_order");
  const { data: docs } = await supabase
    .from("qms_documents").select("id, clause_number, title, doc_type, reference, file_path").order("created_at");

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
      <h1 className="page-title">{T.q_title}</h1>
      <p className="page-sub">{T.ilq_sub}</p>
      <p className="small" style={{ marginTop: -6 }}>
        <Link href="/ilt/quality/registers">{T.q_to_registers}</Link>
      </p>

      <div className="card">
        <h2>{T.ilq_docs}</h2>
        <table>
          <thead><tr><th>{T.q_doc}</th><th>{T.q_doctype}</th><th>{T.q_docref}</th><th>{T.q_chapter}</th><th>{T.q_pdf}</th></tr></thead>
          <tbody>
            {docList.length === 0 ? (
              <tr><td colSpan={5} className="muted small">{T.ilq_no_docs}</td></tr>
            ) : docList.map((d) => (
              <tr key={d.id}>
                <td>{d.title}</td>
                <td className="muted small">{d.doc_type ?? "—"}</td>
                <td className="muted small">{d.reference ?? "—"}</td>
                <td className="muted small">{d.clause_number ?? "—"}</td>
                <td>{signed[d.id] ? <a className="small" href={signed[d.id]} target="_blank" rel="noreferrer">{T.q_download}</a> : <span className="muted small">—</span>}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="card">
        <h2>{T.q_handbook}</h2>
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
