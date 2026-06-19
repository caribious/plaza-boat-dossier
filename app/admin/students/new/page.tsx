import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { createStudent } from "./actions";

export const dynamic = "force-dynamic";

export default async function NewStudent() {
  const supabase = createClient();
  const { data: courses } = await supabase
    .from("courses")
    .select("id, code, title")
    .order("code");

  return (
    <>
      <p className="small">
        <Link href="/admin">← Terug naar cursisten</Link>
      </p>
      <h1 className="page-title">Nieuwe cursist</h1>
      <p className="page-sub">
        Velden met <span style={{ color: "#b3261e" }}>*</span> zijn verplicht. Overige
        gegevens alleen invullen als je ze nodig hebt (AVG — dataminimalisatie).
      </p>

      <form action={createStudent}>
        <div className="card">
          <h2>Identiteit (verplicht)</h2>
          <div className="grid-2">
            <div>
              <label className="flabel">Voornaam *</label>
              <input name="first_name" required style={{ width: "100%" }} />
            </div>
            <div>
              <label className="flabel">Achternaam *</label>
              <input name="last_name" required style={{ width: "100%" }} />
            </div>
            <div>
              <label className="flabel">Geboortedatum *</label>
              <input name="date_of_birth" type="date" required style={{ width: "100%" }} />
            </div>
            <div>
              <label className="flabel">Geboorteplaats</label>
              <input name="place_of_birth" style={{ width: "100%" }} placeholder="bv. Kralendijk, Bonaire" />
            </div>
          </div>
          <div style={{ marginTop: 12 }}>
            <label className="flabel">
              <input type="checkbox" name="identity_verified" style={{ width: "auto", marginRight: 8 }} />
              Identiteit gecontroleerd
            </label>
            <input name="id_document_type" placeholder="Documenttype (bv. Paspoort) — géén nummer/BSN"
                   style={{ width: "100%", marginTop: 8 }} />
          </div>
        </div>

        <div className="card">
          <h2>Contact &amp; overig (optioneel)</h2>
          <div className="grid-2">
            <div>
              <label className="flabel">E-mail</label>
              <input name="email" type="email" style={{ width: "100%" }} />
            </div>
            <div>
              <label className="flabel">Telefoon</label>
              <input name="phone" style={{ width: "100%" }} />
            </div>
            <div>
              <label className="flabel">Nationaliteit</label>
              <input name="nationality" style={{ width: "100%" }} />
            </div>
            <div>
              <label className="flabel">Adres / woonplaats</label>
              <input name="address" style={{ width: "100%" }} />
            </div>
            <div>
              <label className="flabel">RYA-nummer (alleen bij vrijstelling/vooropleiding)</label>
              <input name="rya_number" style={{ width: "100%" }} />
            </div>
          </div>
        </div>

        <div className="card">
          <h2>Inschrijving</h2>
          <label className="flabel">Opleiding (optioneel — kan later)</label>
          <select name="course_id" style={{ width: "100%", maxWidth: 360 }}>
            <option value="">— Geen / later inschrijven —</option>
            {(courses ?? []).map((c: any) => (
              <option key={c.id} value={c.id}>
                {c.code} — {c.title}
              </option>
            ))}
          </select>
          <p className="muted small">
            Bij het kiezen van een opleiding worden de bijbehorende modules automatisch
            klaargezet op "nog niet gestart".
          </p>
        </div>

        <button className="btn" type="submit">Cursist aanmaken</button>
      </form>
    </>
  );
}
