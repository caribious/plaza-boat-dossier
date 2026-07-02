// Server-side e-mailverzending via Resend (auth-uitnodigingen).
// Vereist env: RESEND_API_KEY en (optioneel) RESEND_FROM.
// Zonder RESEND_API_KEY is Resend "uit" en valt de aanroeper terug op Supabase.

const RESEND_ENDPOINT = "https://api.resend.com/emails";

export function resendConfigured(): boolean {
  return !!process.env.RESEND_API_KEY;
}

function fromAddress(): string {
  return process.env.RESEND_FROM || "Plaza Boat College <noreply@plazaboatcollege.com>";
}

const ROLE_NL: Record<string, string> = {
  admin: "beheerder",
  instructor: "instructeur",
  auditor: "ILT-inspecteur (alleen-lezen)",
  student: "cursist",
};

function inviteHtml(name: string, link: string, role: string): string {
  const hi = name ? `Beste ${name},` : "Beste,";
  const rol = ROLE_NL[role] || role;
  return `<!doctype html><html><body style="margin:0;background:#f4f7f9;font-family:'Helvetica Neue',Arial,sans-serif;color:#16324a;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f7f9;padding:28px 0;">
    <tr><td align="center">
      <table role="presentation" width="560" cellpadding="0" cellspacing="0" style="background:#fff;border:1px solid #e3e9ee;border-radius:12px;overflow:hidden;">
        <tr><td style="background:#10293d;padding:20px 28px;color:#fff;font-size:18px;font-weight:700;">Plaza Boat College</td></tr>
        <tr><td style="padding:26px 28px;font-size:14px;line-height:1.6;">
          <p style="margin:0 0 14px;">${hi}</p>
          <p style="margin:0 0 14px;">Je bent uitgenodigd voor het studentdossier-systeem van Plaza Boat College als <strong>${rol}</strong>. Klik op de knop hieronder om je account te activeren en je eigen wachtwoord in te stellen.</p>
          <p style="margin:22px 0;"><a href="${link}" style="display:inline-block;background:#0e7d8a;color:#fff;text-decoration:none;padding:12px 22px;border-radius:8px;font-weight:700;">Account activeren</a></p>
          <p style="margin:0 0 6px;font-size:12px;color:#5a6e7f;">Werkt de knop niet? Kopieer deze link:</p>
          <p style="margin:0 0 18px;font-size:12px;color:#0e7d8a;word-break:break-all;">${link}</p>
          <p style="margin:0;font-size:12px;color:#8b9aa6;">Heb je deze uitnodiging niet verwacht? Dan kun je deze e-mail negeren.</p>
        </td></tr>
        <tr><td style="padding:16px 28px;border-top:1px solid #e3e9ee;font-size:11px;color:#8b9aa6;">Plaza Boat College · Kralendijk, Bonaire · info@plazaboatcollege.com</td></tr>
      </table>
    </td></tr>
  </table></body></html>`;
}

export async function sendInviteEmail(
  to: string,
  name: string,
  link: string,
  role: string
): Promise<{ ok: boolean; error?: string }> {
  const key = process.env.RESEND_API_KEY;
  if (!key) return { ok: false, error: "RESEND_API_KEY ontbreekt" };
  try {
    const res = await fetch(RESEND_ENDPOINT, {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from: fromAddress(),
        to,
        subject: "Uitnodiging — Plaza Boat College studentdossier",
        html: inviteHtml(name, link, role),
      }),
    });
    if (!res.ok) {
      const body = await res.text();
      return { ok: false, error: `Resend ${res.status}: ${body.slice(0, 200)}` };
    }
    return { ok: true };
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : "onbekende fout" };
  }
}
