import { createClient } from "@/lib/supabase/server";
import { fmtDate } from "@/lib/format";
import { uploadIltFile, deleteIltFile } from "./actions";

export const dynamic = "force-dynamic";

const GRADES: { code: string; label: string }[] = [
  { code: "BM-III", label: "Boatmaster Grade III" },
  { code: "BM-II", label: "Boatmaster Grade II" },
  { code: "BM-I", label: "Boatmaster Grade I" },
];

interface IltFile {
  id: string;
  file_name: string;
  file_path: string;
  created_at: string;
}

interface IltFolder {
  id: string;
  course_code: string;
  component_no: number;
  title: string;
  description: string | null;
  ilt_files: IltFile[];
}

export default async function IltAanvraag() {
  const supabase = createClient();
  const { data } = await supabase
    .from("ilt_folders")
    .select("id, course_code, component_no, title, description, ilt_files ( id, file_name, file_path, created_at )")
    .order("component_no");
  const folders = (data as IltFolder[]) ?? [];

  return (
    <>
      <h1 className="page-title">ILT-aanvraag — erkenning maritieme opleiding</h1>
      <p className="page-sub">
        Indieningsdossier per graad, geordend volgens de 14 ILT-componenten (SCV Code 2021).
        Upload hier de stukken; de status toont per component of er al iets klaarstaat.
      </p>

      {GRADES.map((g) => {
        const rows = folders.filter((f) => f.course_code === g.code);
        const filled = rows.filter((r) => (r.ilt_files ?? []).length > 0).length;
        return (
          <div className="card" key={g.code}>
            <h2 style={{ marginTop: 0 }}>
              {g.label}{" "}
              <span className={`badge ${filled === rows.length && rows.length > 0 ? "ok" : filled > 0 ? "warn" : "idle"}`} style={{ marginLeft: 8 }}>
                {filled}/{rows.length} componenten gevuld
              </span>
            </h2>
            <table>
              <thead>
                <tr>
                  <th style={{ width: 30 }}>#</th>
                  <th style={{ width: 260 }}>Component</th>
                  <th>Documenten</th>
                  <th style={{ width: 110 }}>Status</th>
                  <th style={{ width: 220 }}>Upload</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => {
                  const docs = r.ilt_files ?? [];
                  return (
                    <tr key={r.id}>
                      <td className="muted">{String(r.component_no).padStart(2, "0")}</td>
                      <td>
                        <strong>{r.title}</strong>
                        {r.description ? <div className="small muted">{r.description}</div> : null}
                      </td>
                      <td>
                        {docs.length === 0 ? (
                          <span className="small muted">Nog geen documenten.</span>
                        ) : (
                          <ul style={{ margin: 0, paddingLeft: 18 }}>
                            {docs.map((d) => (
                              <li key={d.id} className="small">
                                <a href={`/admin/ilt-aanvraag/download/${d.id}`} target="_blank" rel="noreferrer">{d.file_name}</a>{" "}
                                <span className="muted">({fmtDate(d.created_at)})</span>{" "}
                                <form action={deleteIltFile} style={{ display: "inline" }}>
                                  <input type="hidden" name="file_id" value={d.id} />
                                  <button
                                    type="submit"
                                    className="small"
                                    style={{ background: "none", border: "none", color: "#b3261e", cursor: "pointer", padding: 0 }}
                                  >
                                    verwijderen
                                  </button>
                                </form>
                              </li>
                            ))}
                          </ul>
                        )}
                      </td>
                      <td>
                        <span className={`badge ${docs.length > 0 ? "ok" : "warn"}`}>
                          {docs.length > 0 ? "Aanwezig" : "Ontbreekt"}
                        </span>
                      </td>
                      <td>
                        <form action={uploadIltFile} className="small" style={{ display: "flex", gap: 6, alignItems: "center" }}>
                          <input type="hidden" name="folder_id" value={r.id} />
                          <input type="hidden" name="course_code" value={r.course_code} />
                          <input type="hidden" name="component_no" value={r.component_no} />
                          <input type="file" name="file" multiple required style={{ maxWidth: 140 }} />
                          <button className="btn" type="submit">Upload</button>
                        </form>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        );
      })}
    </>
  );
}
