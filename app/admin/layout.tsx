import { redirect } from "next/navigation";
import { getProfile } from "@/lib/getProfile";
import TopBar from "@/components/TopBar";
import AdminNav from "@/components/AdminNav";
import Footer from "@/components/Footer";

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  // Alleen staff mag in de admin-omgeving (cursist + inspecteur niet)
  if (profile.role === "student") redirect("/student");
  if (profile.role === "auditor") redirect("/ilt");

  return (
    <>
      <TopBar name={profile.full_name || profile.email || ""} role={profile.role} />
      <AdminNav />
      <div className="container">{children}</div>
      <Footer />
    </>
  );
}
