// ============================================================
// Generator — bouwt supabase/seed-elearning-bm3.sql uit de
// e-learning vragenbank (data.js). Eenmalig draaien wanneer de
// vragenbank wijzigt:  node scripts/gen-seed-bm3.mjs
//
// Bron: window.QUESTIONS (object) + window.COURSES uit data.js.
// Wij seeden alle 'bm3:'-vragen in tabel `questions`
// (course_code 'BM-III', module_seq = vraag.mod) en zetten per
// BM III-module de reader_path/deck_path/quiz_ids in `modules`.
// ============================================================
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(__dirname, "..");

// Pad naar data.js (relatief vanuit de repo). Override via argv[2].
const DATA_JS =
  process.argv[2] ||
  path.resolve(
    REPO,
    "../../Plaza Boat College Website/elearning/data.js"
  );

if (!fs.existsSync(DATA_JS)) {
  console.error("data.js niet gevonden op:", DATA_JS);
  console.error("Geef het pad mee:  node scripts/gen-seed-bm3.mjs /pad/naar/data.js");
  process.exit(1);
}

// data.js veilig laden in een sandbox-achtige scope
const code = fs.readFileSync(DATA_JS, "utf8");
const window = {};
// eslint-disable-next-line no-new-func
new Function("window", code)(window);

const Q = window.QUESTIONS || {};
const COURSES = window.COURSES || [];
const COURSE_CODE = "BM-III"; // moet matchen met courses.code in schema.sql

const bm3 = Object.keys(Q)
  .filter((k) => k.startsWith("bm3:"))
  .map((k) => Q[k])
  .sort((a, b) => (a.mod - b.mod) || a.id.localeCompare(b.id));

const bm3Course = COURSES.find((c) => c.id === "bm3");

const esc = (s) => String(s ?? "").replace(/'/g, "''");

let out = "";
out += "-- ============================================================\n";
out += "-- Plaza Boat College — Seed e-learning BM III\n";
out += "-- AUTOGEGENEREERD door scripts/gen-seed-bm3.mjs — niet handmatig bewerken.\n";
out += `-- Bron: ${path.basename(DATA_JS)}  ·  ${bm3.length} vragen\n`;
out += "-- Idempotent: on conflict (id) do update. Voer uit NA migrations/0002_elearning.sql.\n";
out += "-- ============================================================\n\n";

// 1. Vragen
out += "-- ---- Vragenbank (BM III) ----\n";
out += "insert into questions (id, course_code, module_seq, ref, stem, opts, correct, expl) values\n";
out += bm3
  .map((q) => {
    const opts = JSON.stringify(q.opts);
    return `  ('${esc(q.id)}', '${COURSE_CODE}', ${Number(q.mod)}, ${
      q.ref ? `'${esc(q.ref)}'` : "null"
    }, '${esc(q.stem)}', '${esc(opts)}'::jsonb, ${Number(q.correct)}, ${
      q.expl ? `'${esc(q.expl)}'` : "null"
    })`;
  })
  .join(",\n");
out +=
  "\non conflict (id) do update set\n" +
  "  course_code = excluded.course_code,\n" +
  "  module_seq  = excluded.module_seq,\n" +
  "  ref         = excluded.ref,\n" +
  "  stem        = excluded.stem,\n" +
  "  opts        = excluded.opts,\n" +
  "  correct     = excluded.correct,\n" +
  "  expl        = excluded.expl;\n\n";

// 2. Module-content (reader/deck-paden + gecureerde quiz-lijst)
out += "-- ---- Module-content (reader/deck-paden + gecureerde quizlijst) ----\n";
out += "-- Storage-paden in bucket 'course-content'. Volgnummer = modules.sequence.\n\n";

const modules = (bm3Course?.modules ?? []).slice().sort((a, b) => a.no - b.no);
for (const m of modules) {
  const seq = m.no;
  const mm = String(seq).padStart(2, "0");
  const reader = `bm3/readers/M${mm}.pdf`;
  const deck = `bm3/decks/M${mm}.pdf`;
  const quizIds = JSON.stringify(m.quiz ?? []);
  out += `update modules m set\n`;
  out += `  reader_path = '${reader}',\n`;
  out += `  deck_path   = '${deck}',\n`;
  out += `  quiz_ids    = '${esc(quizIds)}'::jsonb\n`;
  out += `from courses c\n`;
  out += `where m.course_id = c.id and c.code = '${COURSE_CODE}' and m.sequence = ${seq};\n`;
}

out += "\n-- Klaar.\n";

const target = path.resolve(REPO, "supabase", "seed-elearning-bm3.sql");
fs.writeFileSync(target, out, "utf8");
console.log(`Geschreven: ${target}`);
console.log(`Vragen: ${bm3.length} · Modules: ${modules.length}`);
