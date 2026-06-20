"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import type { QuestionRow } from "@/lib/learn";
import { recordModuleQuiz } from "../../actions";

type Tab = "reader" | "slides" | "quiz";

export default function ModuleTabs({
  courseCode,
  moduleSeq,
  readerUrl,
  deckUrl,
  questions,
}: {
  courseCode: string;
  moduleSeq: number;
  readerUrl: string | null;
  deckUrl: string | null;
  questions: QuestionRow[];
}) {
  const [tab, setTab] = useState<Tab>("reader");

  return (
    <div className="card">
      <div className="learn-tabs">
        <button
          className={`learn-tab ${tab === "reader" ? "active" : ""}`}
          onClick={() => setTab("reader")}
        >
          Reader
        </button>
        <button
          className={`learn-tab ${tab === "slides" ? "active" : ""}`}
          onClick={() => setTab("slides")}
        >
          Slides
        </button>
        <button
          className={`learn-tab ${tab === "quiz" ? "active" : ""}`}
          onClick={() => setTab("quiz")}
        >
          Quiz ({questions.length})
        </button>
      </div>

      {tab === "reader" && <PdfFrame url={readerUrl} label="reader" />}
      {tab === "slides" && <PdfFrame url={deckUrl} label="slides" />}
      {tab === "quiz" && (
        <Quiz courseCode={courseCode} moduleSeq={moduleSeq} questions={questions} />
      )}
    </div>
  );
}

function PdfFrame({ url, label }: { url: string | null; label: string }) {
  if (!url) {
    return (
      <p className="muted small">
        Dit {label === "reader" ? "lesmateriaal" : "presentatie"} is nog niet beschikbaar.
        Het wordt geüpload door Plaza Boat College.
      </p>
    );
  }
  return (
    <div>
      <iframe className="pdf-frame" src={url} title={label} />
      <p className="muted small" style={{ marginTop: 8 }}>
        Lukt het bekijken niet?{" "}
        <a href={url} target="_blank" rel="noreferrer">
          Open in een nieuw tabblad
        </a>
        .
      </p>
    </div>
  );
}

interface AnswerState {
  chosen: number | null;
  revealed: boolean;
}

function Quiz({
  courseCode,
  moduleSeq,
  questions,
}: {
  courseCode: string;
  moduleSeq: number;
  questions: QuestionRow[];
}) {
  const router = useRouter();
  const [answers, setAnswers] = useState<AnswerState[]>(
    () => questions.map(() => ({ chosen: null, revealed: false }))
  );
  const [finished, setFinished] = useState(false);
  const [saving, setSaving] = useState(false);
  const [saveMsg, setSaveMsg] = useState<string | null>(null);

  const total = questions.length;
  const score = useMemo(
    () =>
      answers.reduce(
        (n, a, i) => (a.chosen === questions[i]?.correct ? n + 1 : n),
        0
      ),
    [answers, questions]
  );
  const passMark = Math.ceil(total * 0.7);
  const passed = score >= passMark;

  if (total === 0) {
    return (
      <p className="muted small">
        Voor deze module zijn nog geen quizvragen beschikbaar. Je kunt de module afronden
        nadat je de reader en slides hebt doorgenomen.
      </p>
    );
  }

  function choose(qi: number, oi: number) {
    setAnswers((prev) => {
      if (prev[qi].revealed) return prev; // antwoord staat vast
      const next = [...prev];
      next[qi] = { chosen: oi, revealed: true };
      return next;
    });
  }

  function reset() {
    setAnswers(questions.map(() => ({ chosen: null, revealed: false })));
    setFinished(false);
    setSaveMsg(null);
  }

  const allAnswered = answers.every((a) => a.revealed);

  async function completeModule() {
    setSaving(true);
    setSaveMsg(null);
    const payload = questions.map((q, i) => ({
      id: q.id,
      chosen: answers[i].chosen ?? -1,
      correct: q.correct,
    }));
    const res = await recordModuleQuiz({
      courseCode,
      moduleSeq,
      score,
      max: total,
      passed,
      answers: payload,
    });
    setSaving(false);
    if (res.ok) {
      setSaveMsg("Module afgerond — je voortgang is opgeslagen in je dossier.");
      router.refresh();
    } else {
      setSaveMsg("Opslaan mislukt: " + (res.error ?? "onbekende fout."));
    }
  }

  return (
    <div>
      {questions.map((q, qi) => {
        const a = answers[qi];
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
                if (a.revealed) {
                  if (oi === q.correct) cls += " correct";
                  else if (oi === a.chosen) cls += " wrong";
                }
                return (
                  <button
                    key={oi}
                    className={cls}
                    disabled={a.revealed}
                    onClick={() => choose(qi, oi)}
                  >
                    <span className="quiz-letter">
                      {String.fromCharCode(65 + oi)}
                    </span>
                    {opt}
                  </button>
                );
              })}
            </div>
            {a.revealed && (
              <p
                className={`quiz-feedback ${
                  a.chosen === q.correct ? "ok" : "warn"
                }`}
              >
                {a.chosen === q.correct ? "Goed!" : "Fout."}{" "}
                {q.expl && <span className="muted">{q.expl}</span>}
                {q.ref && <span className="muted small"> (bron: {q.ref})</span>}
              </p>
            )}
          </div>
        );
      })}

      <div className="quiz-foot">
        <div>
          <strong>
            Score: {score}/{total}
          </strong>{" "}
          <span className="muted small">
            (geslaagd vanaf {passMark} — 70%)
          </span>
        </div>
        {allAnswered && (
          <p className={`quiz-result ${passed ? "ok" : "warn"}`}>
            {passed
              ? "Je hebt de quiz gehaald."
              : "Net niet — bekijk de uitleg en probeer opnieuw."}
          </p>
        )}
        <div className="quiz-actions">
          <button className="btn ghost sm" onClick={reset} type="button">
            Opnieuw proberen
          </button>
          <button
            className="btn sm"
            type="button"
            disabled={saving || !allAnswered}
            onClick={completeModule}
          >
            {saving ? "Opslaan…" : "Module afronden"}
          </button>
        </div>
        {saveMsg && <p className="quiz-savemsg muted small">{saveMsg}</p>}
      </div>
    </div>
  );
}
