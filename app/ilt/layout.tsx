import { redirect } from "next/navigation";
import { getProfile } from "@/lib/getProfile";
import TopBar from "@/components/TopBar";
import IltNav from "@/components/IltNav";
import Footer from "@/components/Footer";

// Toegankelijk voor ILT-inspecteur (auditor) en beheer (admin mag meekijken).
export default async function IltLayout({ children }: { children: React.ReactNode }) {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  if (profile.role === "student") redirect("/student");
  if (profile.role === "instructor") redirect("/admin");

  return (
    <>
      <TopBar name={profile.full_name || profile.email || ""} role={profile.role} />
      <IltNav />
      <div className="container">
        <div className="ilt-banner no-print">
          ILT-inzage · alleen-lezen — dit is een volledig, ongewijzigd beeld van de administratie.
        </div>
        {children}
      </div>
      <Footer />
    </>
  );
}
