import { t } from "@/lib/i18n";

export default function Footer() {
  const T = t();
  return (
    <footer className="footer">
      <span>{T.footer_org}</span>
      <span className="muted">{T.footer_sub}</span>
    </footer>
  );
}
