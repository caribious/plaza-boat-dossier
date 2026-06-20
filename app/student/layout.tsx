import { redirect } from "next/navigation";
import { getProfile } from "@/lib/getProfile";
import TopBar from "@/components/TopBar";
import StudentNav from "@/components/StudentNav";
import Footer from "@/components/Footer";

export default async function StudentLayout({ children }: { children: React.ReactNode }) {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  // Staff hoort in de admin-omgeving
  if (profile.role !== "student") redirect("/admin");

  return (
    <>
      <TopBar name={profile.full_name || profile.email || ""} role={profile.role} />
      <StudentNav />
      <div className="container">{children}</div>
      <Footer />
    </>
  );
}
