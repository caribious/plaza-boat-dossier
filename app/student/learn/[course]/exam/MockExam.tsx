"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import type { QuestionRow } from "@/lib/learn";
import { recordMockExam } from "../../actions";

export default function MockExam({
  courseCode,
  questions,
  durationMin,
  passMark,
}: {
  courseCode: string;
  questions: QuestionRow[];
  durationMin: number;
  passMark: number;
}) {
  const router = useRouter();
  const total = questions.length;
  const [chosen, setChosen] = useState<(number | null)[]>(
    () => questions.map(() => null)
  );
  const [submitted, setSubmitted] = useState(false);
  const [score, setScore] = useState(0);
  const [passed, setPassed] = useState(false);
  const [secondsLeft, setSecondsLeft] = useState(durationMin * 60);
  const [saving, setSaving] = useState(false);
  const [saveMsg, setSaveMsg] = useState<string | null>(null);

  const submit = useCallback(
    async (auto = false) => {
      if (submitted) return;
      const sc = questions.reduce(
        (n, q, i) => (chosen[i] === q.correct ? n + 1 : n),
        0
      );
      const ok = sc >= passMark;
      setScore(sc);
      setPassed(ok);
      setSubmitted(true);

      setSaving(true);
      const payload = questions.map((q, i) => ({
        id: q.id,
        chosen: chosen[i] ?? -1,
        correct: q.correct,
      }));
      const res = await recordMockExam({
        courseCode,
        score: sc,
        max: total,
        passed: ok,
        answers: payload,
      });
      setSaving(false);
      setSaveMsg(
        res.ok
          ? "Resultaat opgeslagen in je dossier." + (auto ? " (tijd verstreken)" : "")
          : "Opslaan mislukt: " + (res.error ?? "onbekende fout.")
      );
      if (res.ok) router.refresh();
    },
    [submitted, questions, chosen, passMark, courseCode, total, router]
  );

  // Timer
  useEffect(() => {
    if (submitted) return;
    if (secondsLeft <= 0) {
      submit(true);
      return;
    }
    const t = setTimeout(() => setSecondsLeft((s) => s - 1), 1000);
    return () => clearTimeout(t);
  }, [secondsLeft, submitted, submit]);

  const mm = String(Math.floor(secondsLeft / 60)).padStart(2, "0");
  const ss = String(secondsLeft % 60).padStart(2, "0");
  const answeredCount = chosen.filter((c) => c !== null).length;

  function pick(qi: number, oi: number) {
    if (submitted) return;
    setChosen((prev) => {
      const next = [...prev];
      next[qi] = oi;
      return next;
    });
  }

  return (
    <div className="card">
      {!submitted && (
        <div className="exam-bar">
          <span>
            Beantwoord: {answeredCount}/{total}
          </span>
          <span className={`exam-timer ${secondsLeft < 300 ? "warn" : ""}`}>
            ⏱ {mm}:{ss}
          </span>
        </div>
      )}

      {submitted && (
        <div className={`exam-result ${passed ? "ok" : "warn"}`}>
          <h2 style={{ marginTop: 0 }}>
            {passed ? "Geslaagd 🎉" : "Niet geslaagd"}
          </h2>
          <p>
            Score: <strong>{score}/{total}</strong> — slagen vanaf {passMark} ({Math.round(
              (passMark / total) * 100
            )}
            %).
          </p>
          {saveMsg && <p className="muted small">{saveMsg}</p>}
          <div className="quiz-actions">
            <button
              className="btn sm"
              type="button"
              onClick={() => router.push("/student")}
            >
              Naar mijn dossier
            </button>
            <button
              className="btn ghost sm"
              type="button"
              onClick={() => window.location.reload()}
            >
              Nieuw oefenexamen
            </button>
          </div>
        </div>
      )}

      {questions.map((q, qi) => {
        const myChoice = chosen[qi];
        return (
          <div className="quiz-q" key={q.id}>
            <p className="quiz-stem">
              <strong>
                {qi + 1}. {q.stem}
              </strong>
            </p>
            <div className="quiz-opts">
              {q.opts.map((opt, oi) => {
                let cls = "quiz-opt";
                if (!submitted && myChoice === oi) cls += " chosen";
                if (submitted) {
                  if (oi === q.correct) cls += " correct";
                  else if (oi === myChoice) cls += " wrong";
                }
                return (
                  <button
                    key={oi}
                    className={cls}
                    disabled={submitted}
                    onClick={() => pick(qi, oi)}
                    type="button"
                  >
                    <span className="quiz-letter">{String.fromCharCode(65 + oi)}</span>
                    {opt}
                  </button>
                );
              })}
            </div>
            {submitted && q.expl && (
              <p className="quiz-feedback muted">{q.expl}</p>
            )}
          </div>
        );
      })}

      {!submitted && (
        <div className="quiz-foot">
          <button
            className="btn"
            type="button"
            disabled={saving}
            onClick={() => submit(false)}
          >
            {saving ? "Opslaan…" : "Examen inleveren"}
          </button>
          <p className="muted small" style={{ marginTop: 8 }}>
            Je kunt inleveren wanneer je wilt; onbeantwoorde vragen tellen als fout.
          </p>
        </div>
      )}
    </div>
  );
}
