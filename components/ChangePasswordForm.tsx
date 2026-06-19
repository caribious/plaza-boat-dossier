"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

export default function ChangePasswordForm() {
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setDone(false);
    if (password.length < 8) {
      setError("Kies een wachtwoord van minimaal 8 tekens.");
      return;
    }
    if (password !== confirm) {
      setError("De wachtwoorden komen niet overeen.");
      return;
    }
    setLoading(true);
    const supabase = createClient();
    const { error } = await supabase.auth.updateUser({ password });
    if (error) {
      setError("Wijzigen mislukt. Probeer opnieuw.");
      setLoading(false);
      return;
    }
    setPassword("");
    setConfirm("");
    setDone(true);
    setLoading(false);
  }

  return (
    <form onSubmit={handleSubmit} style={{ maxWidth: 360 }}>
      <label className="flabel">Nieuw wachtwoord</label>
      <input type="password" value={password} onChange={(e) => setPassword(e.target.value)}
             style={{ width: "100%" }} required />
      <label className="flabel" style={{ marginTop: 10 }}>Bevestig wachtwoord</label>
      <input type="password" value={confirm} onChange={(e) => setConfirm(e.target.value)}
             style={{ width: "100%" }} required />
      <div style={{ marginTop: 14 }}>
        <button className="btn" type="submit" disabled={loading}>
          {loading ? "Bezig…" : "Wachtwoord wijzigen"}
        </button>
      </div>
      {error && <div className="login-error" style={{ maxWidth: 360 }}>{error}</div>}
      {done && <div className="login-created" style={{ maxWidth: 360 }}>Je wachtwoord is gewijzigd.</div>}
    </form>
  );
}
