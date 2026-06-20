# Live zetten — stap voor stap

Twee onderdelen gaan online: het **dossiersysteem** (deze map, draait op Vercel) en
de **database/login** (Supabase). De **e-learning** is een aparte statische map die je
op elke webhost kunt zetten. Reken op ~15–20 minuten.

Wat alleen jij kunt doen (login/betaling): de accounts en het klikken op "Deploy".
Alles wat code/SQL is, staat hieronder kant-en-klaar.

---

## Deel 1 — Supabase (database + login)

1. Ga naar **supabase.com** en log in. Klik **New project**.
2. Kies een naam, een database-wachtwoord (bewaar dit) en bij **Region** een
   EU-locatie (**Frankfurt**) — belangrijk voor de AVG.
3. Wacht tot het project klaar is. Open links **SQL Editor** → **New query**.
4. Open `supabase/INSTALL.sql` (in deze map), kopieer **alles**, plak in de editor,
   klik **Run**. Dit zet de hele database op (tabellen, toegangsregels, audit,
   storage-buckets, de e-learning-koppelfunctie en de opleidingen BM I/II/III).
5. (Optioneel, voor een demo) Doe hetzelfde met `supabase/seed-demo.sql` →
   maakt demo-accounts (admin/student/ILT, wachtwoord `Password123!`).
6. Ga naar **Project Settings → API** en noteer drie waarden:
   - **Project URL**
   - **anon public** key
   - **service_role** key (geheim!)

> Eigen admin-account zonder demo-seed? Maak een gebruiker via **Authentication →
> Add user**, en zet in zijn **User metadata** `{"role":"admin"}`.

---

## Deel 2 — Dossiersysteem op Vercel

### Optie A — snelst (terminal, geen GitHub nodig)
In deze projectmap:
```bash
npm i -g vercel
vercel
```
Volg de prompts (inloggen gaat via je browser). Bij de vraag naar environment
variables, of achteraf in het Vercel-dashboard (**Settings → Environment Variables**),
zet je:

| Naam | Waarde |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | je Project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | je anon public key |
| `SUPABASE_SERVICE_ROLE_KEY` | je service_role key |
| `ELEARNING_API_KEY` | (optioneel) lange willekeurige string |

Daarna: `vercel --prod` voor de productieversie.

### Optie B — zonder terminal (via GitHub)
1. Maak een gratis **GitHub**-account, maak een nieuwe repository.
2. Upload de inhoud van deze map `student-records` naar de repo
   (zonder `node_modules` en `.next` — die staan al in `.gitignore`).
3. Ga naar **vercel.com** → **Add New → Project** → **Import** je repo.
4. Framework wordt automatisch herkend als **Next.js**. Vul bij
   **Environment Variables** dezelfde vier waarden in als in de tabel hierboven.
5. Klik **Deploy**. Na ~1 minuut heb je een URL (bv. `https://jouwproject.vercel.app`).

### Na de eerste deploy (belangrijk)
Zet je nieuwe webadres in Supabase: **Authentication → URL Configuration**:
- **Site URL**: `https://jouwproject.vercel.app`
- **Redirect URLs**: `https://jouwproject.vercel.app/**`

Dit is nodig voor de "wachtwoord vergeten"- en uitnodigingslinks.
(Optioneel: **Authentication → Emails → SMTP** instellen voor betrouwbare e-mail.)

---

## Deel 3 — E-learning online + koppelen

1. Host de map **`BM E-Learning (Plaza Boat College)`** als statische site
   (sleep de map naar **app.netlify.com/drop**, of gebruik GitHub Pages / je eigen host).
2. Open in die map **`config.js`** en vul je Supabase-gegevens in:
   ```js
   window.PBC_SUPABASE = {
     url: "https://jouwproject.supabase.co",
     anonKey: "je anon public key"
   };
   ```
3. Vanaf nu loggen cursisten in de e-learning in met hun eigen dossier-account, en
   stroomt hun voortgang automatisch het dossier in. Laat je `config.js` leeg, dan
   blijft de e-learning offline werken met de demo-login.

---

## Deel 4 — Online cursus BM III (in-app e-learning)

De BM III-cursus draait nu **in de app zelf** (readers, slides, quizzes, oefenexamen),
naast de losse e-learning uit Deel 3. Eenmalige stappen:

1. **Database**: `supabase/INSTALL.sql` bevat de e-learning al (migratie 0002,
   `course-content`-bucket en de 183 BM III-vragen). Draaide je INSTALL.sql vóór deze
   uitbreiding? Voer dan in de **SQL Editor** los uit, in deze volgorde:
   1. `supabase/migrations/0002_elearning.sql`
   2. `supabase/storage-elearning.sql`
   3. `supabase/seed-elearning-bm3.sql`
2. **Content uploaden** (PDF-readers + slide-decks naar de private bucket). Lokaal,
   met `NEXT_PUBLIC_SUPABASE_URL` en `SUPABASE_SERVICE_ROLE_KEY` in `.env.local`:
   ```bash
   node scripts/upload-content.mjs
   ```
   Dit zet `content/bm3/readers/*.pdf` en `content/bm3/decks/*.pdf` in
   `course-content/bm3/...`. De `content/`-map staat in `.gitignore` (grote binaries).
3. Een ingelogde cursist gaat naar **Mijn cursus** in de bovenbalk. Voortgang,
   quizscores en het oefenexamen-resultaat verschijnen automatisch in zijn dossier
   (en daarmee voor admin/ILT).

> Vragenbank gewijzigd in de e-learning (`data.js`)? Genereer de seed opnieuw:
> `node scripts/gen-seed-bm3.mjs "/pad/naar/data.js"` en draai de nieuwe
> `seed-elearning-bm3.sql` (idempotent: `on conflict do update`).

---

## Klaar — controle

- Open je Vercel-URL → log in (demo: `admin@plazaboatcollege.test` / `Password123!`).
- Maak een echte cursist aan, geef hem een inlog, en log als die cursist in de
  e-learning in. Rond een module af → je ziet de voortgang in het dossier verschijnen.
- Log in als `ilt@plazaboatcollege.test` om de read-only ILT-inzage te zien.

> Vergeet niet de demo-accounts te verwijderen voordat je echt live gaat.
