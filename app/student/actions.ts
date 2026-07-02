"use server";

import { createClient } from "@/lib/supabase/server";
import { revalidatePath } from "next/cache";

// De cursist corrigeert zijn eigen gegevens. RLS + de trigger
// protect_student_fields() bewaken dat administratieve/identiteitsvelden
// niet door de cursist gewijzigd kunnen worden.
export async function updateOwnDetails(formData: FormData) {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return;

  const str = (k: string) => {
    const v = String(formData.get(k) ?? "").trim();
    return v === "" ? null : v;
  };

  await supabase
    .from("students")
    .update({
      first_name: String(formData.get("first_name") ?? "").trim(),
      last_name: String(formData.get("last_name") ?? "").trim(),
      date_of_birth: str("date_of_birth"),
      place_of_birth: str("place_of_birth"),
      email: str("email"),
      phone: str("phone"),
      nationality: str("nationality"),
      address: str("address"),
    })
    .eq("profile_id", user.id);

  revalidatePath("/student");
}
