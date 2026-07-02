-- ============================================================
-- Plaza Boat College — Cursist corrigeert eigen gegevens
-- Migratie 0011 — RLS-update voor eigen studentrij + beschermtrigger.
-- ------------------------------------------------------------
-- Een cursist mag zijn eigen persoons-/contactgegevens corrigeren,
-- maar NIET de administratieve/identiteitsvelden zetten. Wijzigt hij
-- naam of geboortedatum, dan vervalt de identiteitscontrole (school
-- verifieert opnieuw). Staff behoudt volledige rechten.
-- Idempotent; volgt de stijl van schema.sql.
-- ============================================================

-- Cursist mag zijn eigen rij bijwerken (naast de bestaande staff-policy).
drop policy if exists p_students_self_update on students;
create policy p_students_self_update on students for update
  using ( profile_id = auth.uid() )
  with check ( profile_id = auth.uid() );

-- Beschermtrigger: bij niet-staff blijven administratieve velden ongewijzigd.
create or replace function public.protect_student_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if is_staff() then
    return new;
  end if;

  -- Administratieve velden mogen door de cursist niet gewijzigd worden.
  new.student_number   := old.student_number;
  new.profile_id       := old.profile_id;
  new.id_document_type := old.id_document_type;
  new.rya_number       := old.rya_number;
  new.created_at       := old.created_at;

  -- Identiteit: cursist kan 'gecontroleerd' nooit zelf zetten.
  -- Wijzigt hij naam of geboortedatum, dan vervalt de controle.
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

drop trigger if exists trg_protect_student_fields on students;
create trigger trg_protect_student_fields
  before update on students
  for each row execute function public.protect_student_fields();
