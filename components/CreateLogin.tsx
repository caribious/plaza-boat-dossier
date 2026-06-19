"use client";

import { useFormState } from "react-dom";
import type { LoginState } from "@/app/admin/account-actions";

export default function CreateLogin({
  action,
  recordId,
  idField,
  defaultEmail,
}: {
  action: (prev: LoginState, fd: FormData) => Promise<LoginState>;
  recordId: string;
  idField: "student_id" | "instructor_id";
  defaultEmail?: string | null;
}) {
  const [state, formAction] = useFormState(action, { status: "idle" } as LoginState);

  if (state.status === "ok") {
    return (
      <div className="login-created">
        <strong>Inlog aangemaakt.</strong> Geef deze gegevens door aan de persoon:
        <div style={{ marginTop: 6 }}>
          E-mail: <code>{state.email}</code>
          <br />
          Tijdelijk wachtwoord: <code>{state.password}</code>
        </div>
        <div className="muted small" style={{ marginTop: 6 }}>
          Vraag hem het wachtwoord na de eerste keer inloggen te wijzigen.
        </div>
      </div>
    );
  }

  return (
    <form action={formAction} style={{ display: "flex", gap: 6, alignItems: "center", flexWrap: "wrap" }}>
      <input type="hidden" name={idField} value={recordId} />
      <input name="email" type="email" defaultValue={defaultEmail ?? ""} placeholder="E-mail voor login" required />
      <button className="btn sm" type="submit">Inlog aanmaken</button>
      {state.status === "error" && <span className="login-error-inline">{state.message}</span>}
    </form>
  );
}
