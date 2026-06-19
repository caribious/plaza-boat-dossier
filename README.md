# Plaza Boat College — Studentdossier (prototype)

Een werkend leerlingadministratiesysteem voor de BM I/II/III-opleidingen, gebouwd op
**Supabase** (database + login) en **Next.js** (admin- en studentomgeving). Opgezet met
het oog op de ILT-eisen: een beschreven inschrijf-/registratiesysteem, een
certificatenregister per cursist, examens met een aparte examinator, en een
onveranderbaar audit-spoor van alle wijzigingen.

> Deze projectversie is gepusht naar `github.com/caribious/plaza-boat-dossier`
> op branch `main`. De drie ISO-kwaliteits-PDF's staan in de Supabase bucket
> `qms-documents` als:
> - `KH-001.pdf`
> - `onderbouwing-productie-8.pdf`
> - `routekaart-iso-9001.pdf`

## Wat zit erin

**Admin-omgeving** (voor administratie/instructeurs) — `/admin`
- Overzicht van alle cursisten met voortgangsbalk; **nieuwe cursist aanmaken**
- Volledig dossier per cursist: persoonsgegevens (bewerkbaar), inschrijving,
  voortgang per module (met uren en instructeur), examenresultaten, certificatenregister
- Module-status en examenuitslag direct aanpasbaar
- **Instructeurregister** (`/admin/instructors`): instructeurs met hun kwalificaties
  (RYA/MCA/FFA/PST e.d.), certificaatnummer, geldigheid met vervalsignalering en PDF-upload
- Wijzigingshistorie (audit-log): wie wijzigde wat en wanneer

### Welke velden zijn verplicht?

| Verplicht (identiteit + regelgeving) | Optioneel (operationeel / AVG-minimalisatie) |
|---|---|
| Voornaam, achternaam | E-mail, telefoon, adres/woonplaats |
| Geboortedatum (+ geboorteplaats aanbevolen) | Nationaliteit |
| Afgeronde modules + contacturen | RYA-nummer (alleen bij vrijstelling/vooropleiding) |
| Examenresultaten met examinator | ID-documenttype (géén nummer/BSN opslaan) |
| Behaalde certificaten (register) | |

Het **RYA-nummer hoort bij instructeurs**, niet bij cursisten: in het
instructeurregister leg je per instructeur de RYA/MCA-kwalificaties met nummer en
geldigheid vast (nodig voor ILT-component 5). Bij een cursist is een RYA-veld alleen
relevant als hij er een vrijstelling mee aanvraagt.

**Studentomgeving** (voor de cursist) — `/student`
- Alleen-lezen weergave van **uitsluitend het eigen dossier**
- Voortgang, modules, examens en behaalde certificaten
- Download van eigen certificaat-PDF's

**ILT-exportrapport** — `/report/[cursist-id]` (knop in het dossier)
- Print-/PDF-vriendelijk dossieroverzicht per cursist om aan ILT of een auditor te
  overleggen: persoonsgegevens, voortgang + contacturen, examens met examinator,
  certificatenregister en een handtekeningregel. Knop "Print / opslaan als PDF"
  gebruikt de browser (geen extra software nodig).

**Certificaat-PDF's** — opgeslagen in Supabase Storage
- Admin uploadt een PDF per certificaat; cursist kan zijn eigen certificaat downloaden.
- Toegang is afgeschermd: een cursist kan alleen zijn eigen bestanden ophalen.

De scheiding tussen admin en student is vastgelegd op databaseniveau met
**Row Level Security**, niet alleen in de schermen. Een student kan technisch geen
gegevens van een ander inzien of iets wijzigen.

## Hoe het ILT-relevant is

| ILT-aandachtspunt | Waar in het systeem |
|---|---|
| Inschrijf-/registratiesysteem | `students` + `enrollments` |
| Voortgang & contacturen | `module_progress` (status + uren per module) |
| Examen los van eigen instructeur | `exam_results.examiner_name` apart van `instructor_name` |
| Examenvorm SCV X/8.1 + X/8.5 | examenvormen mondeling / praktijk / kennistoets |
| Herkansing, geslaagd deel 1 jaar geldig (X/8.3) | `exam_results.valid_until` (automatisch +1 jaar bij "geslaagd") |
| Certificatenregister | `certificates` (nummer, kader, geldigheid) |
| Identiteitscontrole kandidaat | `students.identity_verified` + `id_document_type` |
| Instructeurskwalificaties (comp. 5) | `instructors` + `instructor_certificates` (RYA/MCA-nummer + geldigheid) |
| Traceerbaarheid / onveranderbaar spoor | `audit_log` via database-triggers |

---

## Installatie (stap voor stap)

### 1. Maak een Supabase-project
1. Ga naar [supabase.com](https://supabase.com) en maak een gratis account.
2. Klik **New project**. Kies bij **Region** een EU-locatie (bijv. *Frankfurt*) —
   belangrijk voor de AVG, omdat je persoonsgegevens van cursisten opslaat.
3. Wacht tot het project klaar is.

### 2. Zet de database op
1. Open in Supabase links **SQL Editor**.
2. Open het bestand `supabase/schema.sql`, kopieer de volledige inhoud, plak in de
   editor en klik **Run**. (Maakt tabellen, toegangsregels, audit-log en BM I/II/III.)
3. Doe hetzelfde met `supabase/storage.sql`. Dit maakt twee (private) buckets:
   `certificates` (cursistcertificaten) en `instructor-certificates`
   (instructeurkwalificaties), met de bijbehorende toegangsregels.
4. Optioneel maar aanbevolen voor een demo: doe hetzelfde met `supabase/seed-demo.sql`.
   Dit maakt twee inlogaccounts en een voorbeelddossier.

### 3. Verbind de app met Supabase
1. In Supabase: **Project Settings → API**. Noteer de **Project URL** en de
   **anon public** key.
2. In deze projectmap: kopieer `.env.local.example` naar `.env.local` en vul in:
   ```
   NEXT_PUBLIC_SUPABASE_URL=https://jouw-project.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=jouw-anon-public-key
   SUPABASE_SERVICE_ROLE_KEY=jouw-service-role-secret-key
   ```
   De **service_role** key (Project Settings → API) is nodig om vanuit de portal
   inlogaccounts aan te maken. Hij wordt alleen server-side gebruikt en mag nooit
   gedeeld of in een `NEXT_PUBLIC_`-variabele gezet worden.

### 4. Start de app
```bash
npm install
npm run dev
```
Open daarna **http://localhost:3000**.

### Inloggen (na seed-demo.sql)
| Rol | E-mail | Wachtwoord |
|---|---|---|
| Admin | admin@plazaboatcollege.test | Password123! |
| Student | student@plazaboatcollege.test | Password123! |
| ILT-inspecteur | ilt@plazaboatcollege.test | Password123! |

Log in als admin → je ziet de cursistenlijst. Log in als student → je ziet alleen
het eigen dossier.

---

## Inloggen — hoe het werkt

Eén portal, één inlogscherm, drie rollen. Iedereen logt in met **e-mail + wachtwoord**;
de portal stuurt elke persoon na het inloggen automatisch naar de juiste omgeving:

- **Admin** → beheeromgeving (alles).
- **Instructeur** → zelfde beheeromgeving (volledige rechten, rol `instructor`).
- **Cursist** → eigen dossier, alleen-lezen (rol `student`).
- **ILT-inspecteur** → `/ilt`: ziet **alles** read-only (rol `auditor`).

## ILT-inzage

Een aparte, volledig **alleen-lezen** omgeving (`/ilt`) voor de inspecteur:
- Dashboard met kerncijfers
- Alle cursistdossiers (voortgang, uren, examens met examinator, certificaten)
- Instructeurs met kwalificaties en geldigheid
- Lesprogramma (BM I/II/III + modulestructuur)
- Audit-log (onveranderbaar wijzigingsspoor)
- **Inspectierapport** (`/ilt/export`): alles gebundeld in één afdrukbaar/PDF-document
  om aan ILT te overhandigen.

De inspecteur kan op databaseniveau niets wijzigen — de rol `auditor` heeft alleen
leesrechten (afgedwongen via RLS), op alle tabellen en op de certificaat-PDF's.

## Koppeling met de e-learning

De e-learning stuurt resultaten naar het dossier via een beveiligd koppelpunt, zodat
ILT in één systeem zowel het lesmateriaal-resultaat als het dossier ziet.

- **Endpoint:** `POST /api/elearning/result`
- **Beveiliging:** header `x-api-key` gelijk aan `ELEARNING_API_KEY` (zie `.env.local`).
- **Voorbeeld** (module afgerond):
  ```bash
  curl -X POST https://jouwdomein.nl/api/elearning/result \
    -H "x-api-key: $ELEARNING_API_KEY" -H "Content-Type: application/json" \
    -d '{"student_email":"kandidaat@example.com","course_code":"BM-III",
         "type":"module_complete","module_code":"M05"}'
  ```
- **Types:** `module_complete` / `quiz` (markeert module afgerond) en `exam`
  (oefenexamen → kennistoets in het dossier, met score en geldigheid).
- Matching gebeurt op e-mail (of cursistnummer) + opleidingscode + module; een
  ontbrekende inschrijving wordt automatisch aangemaakt.

> De ontvangende kant zit in deze portal. De e-learning-app moet deze aanroep nog
> versturen op de juiste momenten (module afgerond, quiz/oefenexamen ingeleverd).

## Inlogaccounts aanmaken (vanuit de portal)

Je hoeft hiervoor **niet** in Supabase te zijn:

- **Cursist**: open het dossier → onder "Toegang tot studentportaal" → vul e-mail in →
  **Inlog aanmaken**. De portal maakt het account, koppelt het aan het dossier en
  toont een **tijdelijk wachtwoord** dat je aan de cursist doorgeeft.
- **Instructeur**: `/admin/instructors` → bij de instructeur → **Inlog aanmaken** (zelfde flow).

De persoon logt daarna in op `/login` en wijzigt zijn wachtwoord. Een nieuwe cursist
maak je aan via **+ Nieuwe cursist**; een instructeur via het instructeurregister.

## Wachtwoordbeheer

- **Zelf wijzigen**: iedere ingelogde gebruiker kan via **Account** (rechtsboven) zijn
  wachtwoord wijzigen — bedoeld om het tijdelijke wachtwoord direct te vervangen.
- **Wachtwoord vergeten**: op het inlogscherm staat "Wachtwoord vergeten?". De gebruiker
  ontvangt een herstel-link en stelt een nieuw wachtwoord in (`/reset-password`).

> De herstel-mail wordt door Supabase verstuurd. Voor losse tests werkt de ingebouwde
> mailer (gelimiteerd); **voor productie stel je eigen SMTP in** (Supabase →
> Authentication → Emails → SMTP) en voeg je de portal-URL toe bij
> Authentication → URL Configuration (Redirect URLs), bv. `https://jouwdomein.nl/**`.

## Belangrijk vóór productie
- Verwijder de demo-accounts uit `seed-demo.sql`.
- Stel **eigen SMTP** in voor herstel-/uitnodigingsmails en zet de productie-URL bij
  Authentication → URL Configuration (Redirect URLs).
- Stel **bewaartermijnen** en back-ups in (resultaten moeten voor inspectie
  bewaard en exporteerbaar blijven).
- Zet certificaat-PDF's in **Supabase Storage** en koppel het pad in `certificates.file_path`.
- Overweeg de **service-role key** alleen server-side te gebruiken voor beheertaken;
  de app gebruikt nu uitsluitend de veilige anon-key + RLS.

## Techniek
- **Next.js 14** (App Router), **TypeScript**
- **Supabase** (Postgres, Auth, Row Level Security)
- Geen extra UI-bibliotheek; eenvoudige eigen CSS in `app/globals.css`

## Mappenstructuur
```
supabase/
  schema.sql        Database + RLS + audit + BM I/II/III
  storage.sql       Bucket 'certificates' + toegangsregels
  seed-demo.sql     Demo-accounts + voorbeelddossier
app/
  login/            Inlogscherm
  admin/            Admin: cursistenlijst, dossier (bewerken + upload)
    students/new/   Nieuwe cursist aanmaken
    instructors/    Instructeurregister (kwalificaties + geldigheid)
  report/[id]/      ILT-exportrapport (print/PDF)
  student/          Student: eigen status (alleen-lezen + download)
lib/supabase/       Verbinding met Supabase (client/server/middleware)
```
