-- ============================================================
-- Plaza Boat College — Fix beschermtrigger cursistgegevens
-- Migratie 0012 — de guard uit 0011 draaide óók legitieme admin-/
-- server-updates (profile_id, identity_verified) terug, omdat die met
-- de service-role draaien en is_staff() daar geen auth.uid heeft.
-- ------------------------------------------------------------
-- Nieuwe regel: bescherm ALLEEN bij een ingelogde niet-staff (= cursist).
-- Backend-contexten (service-role, direct DB-beheer) hebben geen auth.uid()
-- en mogen ongehinderd schrijven; staff ook.
-- ============================================================
create or replace function public.protect_student_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or is_staff() then
    return new;
  end if;

  new.student_number   := old.student_number;
  new.profile_id       := old.profile_id;
  new.id_document_type := old.id_document_type;
  new.rya_number       := old.rya_number;
  new.created_at       := old.created_at;

  if new.first_name    is distinct from old.first_name
     or new.last_name  is distinct from old.last_name
     or new.date_of_birth is distinct from old.date_of_birth then
    new.identity_verified := false;
  else
    new.identity_verified := old.identity_verified;
  end if;

  return new;
end;
$$;
