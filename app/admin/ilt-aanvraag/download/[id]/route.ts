import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

// Signed URL pas op het moment van downloaden — niet bij paginaweergave
// (256 stukken vooraf signen duurt langer dan de serverless-timeout).
export async function GET(_req: Request, { params }: { params: { id: string } }) {
  const supabase = createClient();
  const { data: row } = await supabase
    .from("ilt_files")
    .select("file_path")
    .eq("id", params.id)
    .single();
  if (!row) return new NextResponse("Niet gevonden", { status: 404 });

  const { data: s } = await supabase.storage
    .from("ilt-dossier")
    .createSignedUrl(row.file_path, 300);
  if (!s?.signedUrl) return new NextResponse("Kon downloadlink niet maken", { status: 500 });

  return NextResponse.redirect(s.signedUrl);
}
