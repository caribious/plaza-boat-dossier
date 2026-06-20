// ============================================================
// Generator — bouwt supabase/seed-elearning-<grade>.sql uit de
// e-learning vragenbank (data.js). Grade-parametrisch: bm1/bm2/bm3.
//
// Gebruik:
//   node scripts/gen-seed.mjs bm1
//   node scripts/gen-seed.mjs bm2
//   node scripts/gen-seed.mjs bm3
//   node scripts/gen-seed.mjs all            # genereert alle drie
//   node scripts/gen-seed.mjs bm3 /pad/naar/data.js
//
// Bron: window.QUESTIONS (object) + window.COURSES uit data.js.
// Wij seeden alle '<grade>:'-vragen in tabel `questions`
// (course_code 'BM-I' / 'BM-II' / 'BM-III', module_seq = vraag.mod) en
// zetten per module de reader_path/deck_path/quiz_ids in `modules`.
// ============================================================
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(__dirname, "..");

// grade -> course_code (moet matchen met courses.code in schema.sql)
const COURSE_CODES = { bm1: "BM-I", bm2: "BM-II", bm3: "BM-III" };
const TITLES = { bm1: "BM I", bm2: "BM II", bm3: "BM III" };

const gradeArg = (process.argv[2] || "").toLowerCase();
if (!gradeArg || (gradeArg !== "all" && !COURSE_CODES[gradeArg])) {
  console.error("Geef een grade mee: bm1 | bm2 | bm3 | all");
  console.error("  node scripts/gen-seed.mjs bm3 [pad/naar/data.js]");
  process.exit(1);
}

// Pad naar data.js (relatief vanuit de repo). Override via argv[3].
const DATA_JS =
  process.argv[3] ||
  [
    path.resolve(REPO, "../Plaza Boat College Website/elearning/data.js"),
    path.resolve(REPO, "../../Plaza Boat College Website/elearning/data.js"),
  ].find((p) => fs.existsSync(p)) ||
  path.resolve(REPO, "../Plaza Boat College Website/elearning/data.js");

if (!fs.existsSync(DATA_JS)) {
  console.error("data.js niet gevonden op:", DATA_JS);
  console.error("Geef het pad mee:  node scripts/gen-seed.mjs <grade> /pad/naar/data.js");
  process.exit(1);
}

// data.js veilig laden in een sandbox-achtige scope
const code = fs.readFileSync(DATA_JS, "utf8");
const window = {};
// eslint-disable-next-line no-new-func
new Function("window", code)(window);

const Q = window.QUESTIONS || {};
const COURSES = window.COURSES || [];

const esc = (s) => String(s ?? "").replace(/'/g, "''");

function genGrade(grade) {
  const COURSE_CODE = COURSE_CODES[grade];

  const qs = Object.keys(Q)
    .filter((k) => k.startsWith(grade + ":"))
    .map((k) => Q[k])
    .sort((a, b) => (a.mod - b.mod) || a.id.localeCompare(b.id));

  const course = COURSES.find((c) => c.id === grade);

  let out = "";
  out += "-- ============================================================\n";
  out += `-- Plaza Boat College — Seed e-learning ${TITLES[grade]}\n`;
  out += "-- AUTOGEGENEREERD door scripts/gen-seed.mjs — niet handmatig bewerken.\n";
  out += `-- Bron: ${path.basename(DATA_JS)}  ·  ${qs.length} vragen\n`;
  out += "-- Idempotent: on conflict (id) do update. Voer uit NA migrations/0002_elearning.sql.\n";
  out += "-- ============================================================\n\n";

  // 1. Vragen
  out += `-- ---- Vragenbank (${TITLES[grade]}) ----\n`;
  out += "insert into questions (id, course_code, module_seq, ref, stem, opts, correct, expl) values\n";
  out += qs
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

  const modules = (course?.modules ?? []).slice().sort((a, b) => a.no - b.no);
  for (const m of modules) {
    const seq = m.no;
    const mm = String(seq).padStart(2, "0");
    const reader = `${grade}/readers/M${mm}.pdf`;
    const deck = `${grade}/decks/M${mm}.pdf`;
    const quizIds = JSON.stringify(m.quiz ?? []);
    out += `update modules m set\n`;
    out += `  reader_path = '${reader}',\n`;
    out += `  deck_path   = '${deck}',\n`;
    out += `  quiz_ids    = '${esc(quizIds)}'::jsonb\n`;
    out += `from courses c\n`;
    out += `where m.course_id = c.id and c.code = '${COURSE_CODE}' and m.sequence = ${seq};\n`;
  }

  out += "\n-- Klaar.\n";

  const target = path.resolve(REPO, "supabase", `seed-elearning-${grade}.sql`);
  fs.writeFileSync(target, out, "utf8");
  console.log(`Geschreven: ${target}`);
  console.log(`  Vragen: ${qs.length} · Modules: ${modules.length}`);
}

const grades = gradeArg === "all" ? ["bm1", "bm2", "bm3"] : [gradeArg];
for (const g of grades) genGrade(g);
