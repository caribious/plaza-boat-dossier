"use client";

import { useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

export default function ForgotPassword() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    const supabase = createClient();
    await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/callback?next=/reset-password`,
    });
    // Altijd een neutrale bevestiging tonen (geen info lekken of e-mail bestaat)
    setSent(true);
    setLoading(false);
  }

  return (
    <div className="login-wrap">
      <div className="login-card">
        <h1>Wachtwoord vergeten</h1>
        {sent ? (
          <>
            <p className="sub">
              Als er een account bij dit e-mailadres hoort, is er een herstel-link
              verstuurd. Controleer je inbox.
            </p>
            <Link className="btn" href="/login" style={{ display: "block", textAlign: "center", marginTop: 18 }}>
              Terug naar inloggen
            </Link>
          </>
        ) : (
          <>
            <p className="sub">Vul je e-mailadres in; je ontvangt een herstel-link.</p>
            <form onSubmit={handleSubmit}>
              <label>E-mailadres</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
              <button className="btn" type="submit" disabled={loading}>
                {loading ? "Bezig…" : "Stuur herstel-link"}
              </button>
            </form>
            <div className="login-demo">
              <Link href="/login">← Terug naar inloggen</Link>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
