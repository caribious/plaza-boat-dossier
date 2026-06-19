import { redirect } from "next/navigation";
import { getProfile } from "@/lib/getProfile";

// Startpagina: stuur door op basis van de rol.
export default async function Home() {
  const profile = await getProfile();
  if (!profile) redirect("/login");
  if (profile.role === "student") redirect("/student");
  if (profile.role === "auditor") redirect("/ilt");
  redirect("/admin");
}
