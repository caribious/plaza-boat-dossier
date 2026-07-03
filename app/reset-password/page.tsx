"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

export default function ResetPassword() {
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const [hasSession, setHasSession] = useState(false);
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    async function init() {
      // Uitnodigings-/herstellinks leveren de sessie als hash-fragment
      // (#access_token=…&refresh_token=…). Die zetten we hier expliciet.
      if (typeof window !== "undefined" && window.location.hash.includes("access_token")) {
        const p = new URLSearchParams(window.location.hash.slice(1));
        const access_token = p.get("access_token");
        const refresh_token = p.get("refresh_token");
        if (access_token && refresh_token) {
          await supabase.auth.setSession({ access_token, refresh_token });
          history.replaceState(null, "", window.location.pathname);
        }
      }
      const { data } = await supabase.auth.getSession();
      setHasSession(!!data.session);
      setReady(true);
    }
    init();
  }, []);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
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
      setError("Wijzigen mislukt. Vraag eventueel een nieuwe herstel-link aan.");
      setLoading(false);
      return;
    }
    setDone(true);
    setLoading(false);
    setTimeout(() => {
      router.push("/login");
      router.refresh();
    }, 1500);
  }

  return (
    <div className="login-wrap">
      <div className="login-card">
        <h1>Nieuw wachtwoord</h1>
        {!ready ? (
          <p className="sub">Even laden…</p>
        ) : done ? (
          <p className="sub">Je wachtwoord is gewijzigd. Je wordt doorgestuurd naar inloggen…</p>
        ) : !hasSession ? (
          <>
            <p className="sub">
              Deze link is verlopen of ongeldig. Vraag een nieuwe herstel-link aan.
            </p>
            <Link className="btn" href="/forgot-password"
                  style={{ display: "block", textAlign: "center", marginTop: 18 }}>
              Nieuwe herstel-link
            </Link>
          </>
        ) : (
          <>
            <p className="sub">Kies een nieuw wachtwoord (minimaal 8 tekens).</p>
            <form onSubmit={handleSubmit}>
              <label>Nieuw wachtwoord</label>
              <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
              <label>Bevestig wachtwoord</label>
              <input type="password" value={confirm} onChange={(e) => setConfirm(e.target.value)} required />
              <button className="btn" type="submit" disabled={loading}>
                {loading ? "Bezig…" : "Wachtwoord opslaan"}
              </button>
              {error && <div className="login-error">{error}</div>}
            </form>
          </>
        )}
      </div>
    </div>
  );
}
