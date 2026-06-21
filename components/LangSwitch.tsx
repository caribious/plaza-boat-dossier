import Link from "next/link";
import { getLocale } from "@/lib/i18n";

// NL/EN-schakelaar; gebruikt de referer om terug te keren naar dezelfde pagina.
export default function LangSwitch() {
  const loc = getLocale();
  const item = (code: "nl" | "en", label: string) => (
    <Link
      href={`/api/lang?l=${code}`}
      prefetch={false}
      className="langswitch-item"
      style={{
        color: "#fff",
        opacity: loc === code ? 1 : 0.55,
        fontWeight: loc === code ? 700 : 400,
        textDecoration: "none",
      }}
    >
      {label}
    </Link>
  );
  return (
    <span className="langswitch" style={{ display: "inline-flex", gap: 4, alignItems: "center", fontSize: 13 }}>
      {item("nl", "NL")}
      <span style={{ opacity: 0.4 }}>|</span>
      {item("en", "EN")}
    </span>
  );
}
