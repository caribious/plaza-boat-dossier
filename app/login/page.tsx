"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) {
      setError("Inloggen mislukt. Controleer e-mail en wachtwoord.");
      setLoading(false);
      return;
    }
    router.push("/");
    router.refresh();
  }

  return (
    <div className="login-wrap">
      <div className="login-card">
        <h1>Plaza Boat College</h1>
        <p className="sub">Studentdossier — log in om verder te gaan</p>
        <form onSubmit={handleSubmit}>
          <label>E-mailadres</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="naam@plazaboatcollege.test"
            required
          />
          <label>Wachtwoord</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
          <button className="btn" type="submit" disabled={loading}>
            {loading ? "Bezig…" : "Inloggen"}
          </button>
          {error && <div className="login-error">{error}</div>}
        </form>
        <p className="small" style={{ marginTop: 14 }}>
          <a href="/forgot-password">Wachtwoord vergeten?</a>
        </p>
        {/* demo-accounts verwijderd vóór productie/inspectie */}
      </div>
    </div>
  );
}
