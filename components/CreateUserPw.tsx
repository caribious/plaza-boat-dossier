"use client";
import { useFormState } from "react-dom";
import { createUserWithPassword, type CreateState } from "@/app/admin/users/actions";

export default function CreateUserPw({ labels }: { labels: Record<string, string> }) {
  const [state, formAction] = useFormState(createUserWithPassword, { status: "idle" } as CreateState);
  return (
    <>
      <form action={formAction} style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr 1fr auto", gap: 10, alignItems: "center" }}>
        <input name="full_name" placeholder={labels.name} />
        <input name="email" type="email" placeholder={labels.email} required />
        <input name="password" placeholder={labels.pw_set} />
        <select name="role" defaultValue="admin">
          <option value="admin">{labels.admin}</option>
          <option value="instructor">{labels.instructor}</option>
          <option value="auditor">{labels.auditor}</option>
          <option value="student">{labels.student}</option>
        </select>
        <button className="btn" type="submit">{labels.create}</button>
        {state.status === "error" && <span className="login-error-inline" style={{ gridColumn: "1 / -1" }}>{state.message}</span>}
      </form>
      {state.status === "ok" && (
        <div className="login-created" style={{ marginTop: 12 }}>
          <strong>{labels.created}</strong>
          <div style={{ marginTop: 6 }}>
            {labels.email}: <code>{state.email}</code><br />
            {labels.temp_pw}: <code>{state.password}</code>
          </div>
          <div className="muted small" style={{ marginTop: 6 }}>{labels.change_hint}</div>
        </div>
      )}
    </>
  );
}
