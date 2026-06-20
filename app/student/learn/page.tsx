import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { normCode } from "@/lib/learn";

export const dynamic = "force-dynamic";

export default async function LearnHome() {
  const supabase = createClient();

  // Inschrijvingen van de cursist (RLS beperkt tot eigen dossier).
  const { data: enrollments } = await supabase
    .from("enrollments")
    .select("id, status, courses ( code, title, description )")
    .order("created_at", { ascending: false });

  const enr = (enrollments as any[]) ?? [];

  // Voortgang per inschrijving uitrekenen.
  const cards: {
    code: string;
    title: string;
    description: string | null;
    done: number;
    total: number;
    pct: number;
  }[] = [];

  for (const e of enr) {
    const { data: prog } = await supabase
      .from("module_progress")
      .select("status")
      .eq("enrollment_id", e.id);
    const mods = (prog as any[]) ?? [];
    const done = mods.filter((m) => m.status === "completed").length;
    const total = mods.length;
    cards.push({
      code: e.courses?.code ?? "",
      title: e.courses?.title ?? "Cursus",
      description: e.courses?.description ?? null,
      done,
      total,
      pct: total ? Math.round((done / total) * 100) : 0,
    });
  }

  return (
    <>
      <h1 className="page-title">Mijn cursus</h1>
      <p className="page-sub">
        Bekijk de readers en slides, maak de quizzen en doe het oefenexamen. Je voortgang
        wordt automatisch in je dossier bijgehouden.
      </p>

      {cards.length === 0 ? (
        <div className="card">
          <h2>Nog geen cursus toegankelijk</h2>
          <p className="muted small">
            Er staat nog geen inschrijving voor je klaar. Neem contact op met de administratie
            van Plaza Boat College.
          </p>
        </div>
      ) : (
        cards.map((c) => (
          <div className="card" key={c.code}>
            <h2>{c.title}</h2>
            {c.description && <p className="muted small">{c.description}</p>}
            <div className="progress-wrap" style={{ maxWidth: 360 }}>
              <div className="progress-bar" style={{ width: `${c.pct}%` }} />
            </div>
            <p className="muted small">
              {c.done} van {c.total} modules afgerond ({c.pct}%).
            </p>
            <Link className="btn sm" href={`/student/learn/${normCode(c.code)}`}>
              Open cursus
            </Link>
          </div>
        ))
      )}
    </>
  );
}
