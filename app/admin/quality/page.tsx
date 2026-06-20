import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { fmtDate } from "@/lib/format";
import { t } from "@/lib/i18n";
import { updateClause, addDocument, uploadDocFile, signDocument } from "./actions";

export const dynamic = "force-dynamic";

export default async function QualityPage() {
  const T = t();
  const supabase = createClient();
  const { data: { user } } = await supabase.auth.getUser();
  const { data: clauses } = await supabase
    .from("qms_clauses").select("id, clause_number, title, pbc_approach, updated_at").order("sort_order");
  const { data: docs } = await supabase
    .from("qms_documents").select("id, clause_number, title, doc_type, reference, file_path, created_at").order("created_at");
  const { data: sigData } = await supabase
    .from("qms_document_signatures").select("document_id, signer_profile_id, signer_name, signer_role, signed_at");

  const docList = (docs as any[]) ?? [];
  const sigs = (sigData as any[]) ?? [];
  const sigsFor = (id: string) => sigs.filter((s) => s.document_id === id);
  const iSigned = (id: string) => sigs.some((s) => s.document_id === id && s.signer_profile_id === user?.id);

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
      <p className="page-sub">{T.q_sub}</p>
      <p className="small" style={{ marginTop: -6 }}>
        <Link href="/admin/quality/kpi">{T.q_to_kpi}</Link>
        {" · "}
        <Link href="/admin/quality/registers">{T.q_to_registers_short}</Link>
        {" · "}
        <Link href="/admin/quality/registers/risks">{T.q_to_risks}</Link>
      </p>

      <div className="card">
        <h2>{T.q_how_title}</h2>
        <p className="muted small" style={{ marginTop: -8 }}>{T.q_how_intro}</p>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
          <div>
            <span className="flabel">{T.q_in_app}</span>
            <ul className="small" style={{ margin: "6px 0 0", paddingLeft: 18 }}>
              <li>{T.q_app_1a}<Link href="/admin/quality/registers">{T.q_app_1b}</Link></li>
              <li>{T.q_app_2a}<Link href="/admin/quality/agenda">{T.q_app_2b}</Link></li>
              <li>{T.q_app_3a}<Link href="/admin/quality/reviews">{T.q_app_3b}</Link></li>
              <li>{T.q_app_4}</li>
            </ul>
          </div>
          <div>
            <span className="flabel">{T.q_around}</span>
            <ul className="small" style={{ margin: "6px 0 0", paddingLeft: 18 }}>
              <li>{T.q_ar_1}</li><li>{T.q_ar_2}</li><li>{T.q_ar_3}</li><li>{T.q_ar_4}</li>
            </ul>
          </div>
        </div>
      </div>

      <div className="card">
        <h2>{T.q_lib}</h2>
        <p className="muted small" style={{ marginTop: -8 }}>{T.q_lib_sub} {T.rv_sign_note}</p>
        <table>
          <thead>
            <tr><th>{T.q_doc}</th><th>{T.q_doctype}</th><th>{T.q_docref}</th><th>{T.q_pdf}</th><th>{T.rv_signatures}</th><th></th></tr>
          </thead>
          <tbody>
            {docList.length === 0 ? (
              <tr><td colSpan={6} className="muted small">{T.q_no_docs}</td></tr>
            ) : docList.map((d) => {
              const dsigs = sigsFor(d.id);
              return (
              <tr key={d.id}>
                <td>{d.title}{d.clause_number ? <span className="muted small"> · §{d.clause_number}</span> : null}</td>
                <td className="muted small">{d.doc_type ?? "—"}</td>
                <td className="muted small">{d.reference ?? "—"}</td>
                <td>
                  {signed[d.id] ? (
                    <a className="small" href={signed[d.id]} target="_blank" rel="noreferrer">{T.q_download}</a>
                  ) : (
                    <form action={uploadDocFile} encType="multipart/form-data" style={{ display: "flex", gap: 6 }}>
                      <input type="hidden" name="document_id" value={d.id} />
                      <input type="file" name="file" accept="application/pdf" className="small" required />
                      <button className="btn sm" type="submit">{T.q_upload}</button>
                    </form>
                  )}
                </td>
                <td className="small">
                  {dsigs.length === 0 ? <span className="muted small">{T.rv_no_sign}</span> :
                    dsigs.map((s, i) => (
                      <div key={i}><span className="badge ok">✓</span> {s.signer_name}
                        {s.signer_role ? <span className="muted"> · {s.signer_role}</span> : null}
                        <span className="muted"> · {fmtDate(s.signed_at)}</span></div>
                    ))}
                </td>
                <td>
                  {iSigned(d.id) ? <span className="badge ok">{T.rv_you_signed}</span> : (
                    <form action={signDocument}>
                      <input type="hidden" name="document_id" value={d.id} />
                      <button className="btn sm" type="submit">{T.rv_signoff}</button>
                    </form>
                  )}
                </td>
              </tr>
            );})}
          </tbody>
        </table>

        <details style={{ marginTop: 14 }}>
          <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>{T.q_add_doc}</summary>
          <form action={addDocument} style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, marginTop: 12, maxWidth: 620 }}>
            <input name="title" placeholder={T.q_doc} required />
            <input name="doc_type" placeholder={T.q_doctype} />
            <input name="reference" placeholder={T.q_docref} />
            <input name="clause_number" placeholder={T.q_chapter} />
            <button className="btn" type="submit">{T.save}</button>
          </form>
        </details>
      </div>

      <div className="card">
        <h2>{T.q_handbook}</h2>
        {(clauses as any[] ?? []).map((c) => (
          <div key={c.id} style={{ padding: "14px 0", borderTop: "1px solid var(--line)" }}>
            <strong>{c.clause_number}. {c.title}</strong>
            <p className="small" style={{ margin: "6px 0 0", whiteSpace: "pre-wrap" }}>{c.pbc_approach}</p>
            <details style={{ marginTop: 6 }}>
              <summary className="small" style={{ cursor: "pointer", color: "var(--sea)" }}>{T.q_editbtn}</summary>
              <form action={updateClause} style={{ marginTop: 8 }}>
                <input type="hidden" name="clause_id" value={c.id} />
                <textarea name="pbc_approach" defaultValue={c.pbc_approach ?? ""} rows={5}
                          style={{ width: "100%", fontFamily: "inherit", fontSize: 14, padding: 8, borderRadius: 8, border: "1px solid var(--line)" }} />
                <button className="btn sm" type="submit" style={{ marginTop: 8 }}>{T.save}</button>
              </form>
            </details>
          </div>
        ))}
      </div>
    </>
  );
}
