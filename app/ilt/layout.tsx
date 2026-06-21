import { redirect } from "next/navigation";
import { getProfile } from "@/lib/getProfile";
import TopBar from "@/components/TopBar";
import IltNav from "@/components/IltNav";
import Footer from "@/components/Footer";
import { t } from "@/lib/i18n";

export default async function IltLayout({ children }: { children: React.ReactNode }) {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  if (profile.role === "student") redirect("/student");
  if (profile.role === "instructor") redirect("/admin");
  const T = t();

  return (
    <>
      <TopBar name={profile.full_name || profile.email || ""} role={profile.role} />
      <IltNav />
      <div className="container">
        <div className="ilt-banner no-print">{T.il_banner}</div>
        {children}
      </div>
      <Footer />
    </>
  );
}
