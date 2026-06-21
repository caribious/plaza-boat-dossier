"use client";
import { useFormState } from "react-dom";
import { inviteUser, type InviteState } from "@/app/admin/users/actions";

export default function InviteUser({ labels }: { labels: Record<string, string> }) {
  const [state, formAction] = useFormState(inviteUser, { status: "idle" } as InviteState);
  return (
    <form action={formAction} style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr auto", gap: 10, alignItems: "center" }}>
      <input name="full_name" placeholder={labels.name} />
      <input name="email" type="email" placeholder={labels.email} required />
      <select name="role" defaultValue="admin">
        <option value="admin">{labels.admin}</option>
        <option value="instructor">{labels.instructor}</option>
        <option value="auditor">{labels.auditor}</option>
        <option value="student">{labels.student}</option>
      </select>
      <button className="btn" type="submit">{labels.send}</button>
      {state.status === "ok" && <span className="badge ok" style={{ gridColumn: "1 / -1" }}>{labels.sent} {state.email}</span>}
      {state.status === "error" && <span className="login-error-inline" style={{ gridColumn: "1 / -1" }}>{state.message}</span>}
    </form>
  );
}
