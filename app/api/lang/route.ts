import { NextRequest, NextResponse } from "next/server";

// Zet de taalvoorkeur (cookie) en stuur terug naar de vorige pagina.
export function GET(req: NextRequest) {
  const l = req.nextUrl.searchParams.get("l") === "en" ? "en" : "nl";
  const back = req.nextUrl.searchParams.get("next") || req.headers.get("referer") || "/admin";
  const res = NextResponse.redirect(new URL(back, req.url));
  res.cookies.set("lang", l, { path: "/", maxAge: 60 * 60 * 24 * 365 });
  return res;
}
