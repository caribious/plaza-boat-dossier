// ============================================================
// Upload-script — zet de reader- en deck-PDF's in de private
// Supabase Storage-bucket 'course-content'. Grade-parametrisch.
//
// Gebruik:
//   node scripts/upload-content.mjs            # alle grades (bm1,bm2,bm3)
//   node scripts/upload-content.mjs bm3        # alleen bm3
//   node scripts/upload-content.mjs bm1 bm2    # meerdere
//
// Vereist in .env.local (worden automatisch ingelezen):
//   NEXT_PUBLIC_SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY   (service role — omzeilt RLS, alleen lokaal gebruiken!)
//
// Bron-PDF's: content/<grade>/readers/Mxx.pdf en content/<grade>/decks/Mxx.pdf
// Doel-paden: <grade>/readers/Mxx.pdf en <grade>/decks/Mxx.pdf
//
// Draai dit NA migrations/0002_elearning.sql + storage-elearning.sql
// (de bucket 'course-content' moet bestaan).
// ============================================================
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createClient } from "@supabase/supabase-js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(__dirname, "..");
const BUCKET = "course-content";

// --- .env.local minimaal inlezen (geen extra dependency nodig) ---
function loadEnv() {
  const f = path.resolve(REPO, ".env.local");
  if (!fs.existsSync(f)) return;
  for (const line of fs.readFileSync(f, "utf8").split("\n")) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) {
      process.env[m[1]] = m[2].replace(/^["']|["']$/g, "");
    }
  }
}
loadEnv();

const URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!URL || !KEY) {
  console.error(
    "Ontbrekende env-vars. Zet NEXT_PUBLIC_SUPABASE_URL en SUPABASE_SERVICE_ROLE_KEY in .env.local."
  );
  process.exit(1);
}

const supabase = createClient(URL, KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

async function ensureBucket() {
  const { data: buckets } = await supabase.storage.listBuckets();
  if (!buckets?.some((b) => b.id === BUCKET)) {
    const { error } = await supabase.storage.createBucket(BUCKET, { public: false });
    if (error && !/already exists/i.test(error.message)) {
      console.error("Bucket aanmaken mislukt:", error.message);
      process.exit(1);
    }
    console.log(`Bucket '${BUCKET}' aangemaakt.`);
  }
}

async function uploadDir(localDir, remotePrefix) {
  if (!fs.existsSync(localDir)) {
    console.warn("Map ontbreekt, overgeslagen:", localDir);
    return 0;
  }
  let n = 0;
  for (const name of fs.readdirSync(localDir).sort()) {
    if (!name.toLowerCase().endsWith(".pdf")) continue;
    const buf = fs.readFileSync(path.join(localDir, name));
    const remote = `${remotePrefix}/${name}`;
    const { error } = await supabase.storage.from(BUCKET).upload(remote, buf, {
      upsert: true,
      contentType: "application/pdf",
    });
    if (error) {
      console.error(`  ✗ ${remote}: ${error.message}`);
    } else {
      console.log(`  ✓ ${remote}`);
      n++;
    }
  }
  return n;
}

const ALL_GRADES = ["bm1", "bm2", "bm3"];
const args = process.argv.slice(2).map((s) => s.toLowerCase());
const grades = args.length ? args.filter((g) => ALL_GRADES.includes(g)) : ALL_GRADES;
if (!grades.length) {
  console.error("Onbekende grade. Kies uit:", ALL_GRADES.join(", "));
  process.exit(1);
}

(async () => {
  await ensureBucket();
  let totR = 0;
  let totD = 0;
  for (const grade of grades) {
    console.log(`\n== ${grade.toUpperCase()} ==`);
    console.log("Readers uploaden…");
    const r = await uploadDir(path.resolve(REPO, `content/${grade}/readers`), `${grade}/readers`);
    console.log("Decks uploaden…");
    const d = await uploadDir(path.resolve(REPO, `content/${grade}/decks`), `${grade}/decks`);
    totR += r;
    totD += d;
  }
  console.log(`\nKlaar. ${totR} readers + ${totD} decks geüpload naar '${BUCKET}' (${grades.join(", ")}).`);
})();
