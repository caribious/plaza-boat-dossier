import { NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";

// ============================================================
// Koppelpunt e-learning -> dossier
// De e-learning stuurt hier resultaten naartoe. Beveiligd met een
// gedeeld geheim (header x-api-key == ELEARNING_API_KEY).
//
// POST /api/elearning/result
// Header: x-api-key: <ELEARNING_API_KEY>
// Body (JSON):
// {
//   "student_email": "kandidaat@example.com",   // of "student_number"
//   "course_code": "BM-III",                       // BM-I / BM-II / BM-III (spaties/streepjes mogen)
//   "type": "module_complete" | "quiz" | "exam",
//   "module_code": "M05",                          // of "module_sequence": 5  (bij module/quiz)
//   "score": 44, "max": 50, "passed": true,         // bij quiz/exam
//   "exam_date": "2026-06-20"                        // optioneel
// }
// ============================================================

function norm(s: string) {
  return (s || "").toUpperCase().replace(/[\s\-_.]/g, "");
}

export async function POST(request: Request) {
  // 1. Authenticatie
  const key = request.headers.get("x-api-key");
  if (!key || key !== process.env.ELEARNING_API_KEY) {
    return NextResponse.json({ ok: false, error: "Ongeldige API-sleutel." }, { status: 401 });
  }

  let body: any;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ ok: false, error: "Ongeldige JSON." }, { status: 400 });
  }

  const { student_email, student_number, course_code, type } = body;
  if (!course_code || !type) {
    return NextResponse.json({ ok: false, error: "course_code en type zijn verplicht." }, { status: 400 });
  }

  const admin = createAdminClient();

  // 2. Cursist opzoeken (op e-mail of cursistnummer)
  let studentQuery = admin.from("students").select("id");
  if (student_email) studentQuery = studentQuery.ilike("email", student_email);
  else if (student_number) studentQuery = studentQuery.eq("student_number", student_number);
  else return NextResponse.json({ ok: false, error: "student_email of student_number vereist." }, { status: 400 });

  const { data: student } = await studentQuery.maybeSingle();
  if (!student) return NextResponse.json({ ok: false, error: "Cursist niet gevonden." }, { status: 404 });

  // 3. Opleiding matchen (genormaliseerd, dus 'BM III' == 'BM-III')
  const { data: courses } = await admin.from("courses").select("id, code");
  const course = (courses ?? []).find((c: any) => norm(c.code) === norm(course_code));
  if (!course) return NextResponse.json({ ok: false, error: "Opleiding niet gevonden." }, { status: 404 });

  // 4. Inschrijving zoeken of automatisch aanmaken
  let { data: enrollment } = await admin
    .from("enrollments")
    .select("id")
    .eq("student_id", student.id)
    .eq("course_id", course.id)
    .maybeSingle();

  if (!enrollment) {
    const { data: created } = await admin
      .from("enrollments")
      .insert({ student_id: student.id, course_id: course.id, status: "active",
                start_date: new Date().toISOString().slice(0, 10) })
      .select("id")
      .single();
    enrollment = created;
    // modulevoortgang klaarzetten
    const { data: modules } = await admin.from("modules").select("id").eq("course_id", course.id);
    if (created && modules?.length) {
      await admin.from("module_progress").insert(
        modules.map((m: any) => ({ enrollment_id: created.id, module_id: m.id, status: "not_started" }))
      );
    }
  }
  if (!enrollment) return NextResponse.json({ ok: false, error: "Inschrijving mislukt." }, { status: 500 });

  // 5. Resultaat verwerken
  if (type === "module_complete" || type === "quiz") {
    // module zoeken op code of volgnummer
    let modQuery = admin.from("modules").select("id").eq("course_id", course.id);
    if (body.module_code) modQuery = modQuery.eq("code", body.module_code);
    else if (body.module_sequence != null) modQuery = modQuery.eq("sequence", body.module_sequence);
    else return NextResponse.json({ ok: false, error: "module_code of module_sequence vereist." }, { status: 400 });

    const { data: mod } = await modQuery.maybeSingle();
    if (!mod) return NextResponse.json({ ok: false, error: "Module niet gevonden." }, { status: 404 });

    const passed = body.passed !== false; // standaard true bij module_complete
    await admin
      .from("module_progress")
      .update({
        status: passed ? "completed" : "in_progress",
        completed_at: passed ? new Date().toISOString() : null,
        updated_at: new Date().toISOString(),
      })
      .eq("enrollment_id", enrollment.id)
      .eq("module_id", mod.id);

    return NextResponse.json({ ok: true, recorded: "module_progress", module_id: mod.id });
  }

  if (type === "exam") {
    // Oefenexamen = ondersteunende kennistoets (knowledge_mcq)
    const outcome = body.passed === true ? "passed" : body.passed === false ? "failed" : "pending";
    const examDate = body.exam_date ?? new Date().toISOString().slice(0, 10);
    let valid_until: string | null = null;
    if (outcome === "passed") {
      const d = new Date(examDate); d.setFullYear(d.getFullYear() + 1);
      valid_until = d.toISOString().slice(0, 10);
    }

    // Bestaande kennistoets bijwerken, anders nieuwe aanmaken
    const { data: existing } = await admin
      .from("exam_results")
      .select("id, attempt")
      .eq("enrollment_id", enrollment.id)
      .eq("kind", "knowledge_mcq")
      .order("attempt", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (existing) {
      await admin.from("exam_results").update({
        exam_date: examDate, score: body.score ?? null, max_score: body.max ?? null,
        outcome, valid_until, remarks: "Bijgewerkt via e-learning",
      }).eq("id", existing.id);
    } else {
      await admin.from("exam_results").insert({
        enrollment_id: enrollment.id, kind: "knowledge_mcq", attempt: 1,
        exam_date: examDate, score: body.score ?? null, max_score: body.max ?? null,
        outcome, valid_until, examiner_name: "E-learning (automatisch)",
        remarks: "Oefenexamen e-learning",
      });
    }
    return NextResponse.json({ ok: true, recorded: "exam_results", outcome });
  }

  return NextResponse.json({ ok: false, error: "Onbekend type." }, { status: 400 });
}
