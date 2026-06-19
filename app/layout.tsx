import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Plaza Boat College — Studentdossier",
  description: "Leerlingadministratie BM I/II/III",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="nl">
      <body>{children}</body>
    </html>
  );
}
