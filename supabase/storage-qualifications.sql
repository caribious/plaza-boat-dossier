-- ============================================================
-- Plaza Boat College — Storage voor kwalificatie-documenten
-- (toelatingseisen: VHF, medisch, EHBO, GMDSS/GOC, vaartijd, ...)
-- Voer dit uit NA 0005_student_qualifications.sql (1x).
-- ------------------------------------------------------------
-- Maakt een private bucket 'student-qualifications' met
-- toegangsregels NAAR HET VOORBEELD van de 'certificates'-bucket:
--   - staff (admin/instructor): mag uploaden, lezen, wijzigen, verwijderen
--   - cursist: mag ALLEEN zijn eigen documenten lezen
--   - ILT-inspecteur (auditor): leest mee (can_read_all())
-- Bestandspad-conventie: <student_id>/<bestand>
-- Weergave gebeurt via server-side gegenereerde signed URL's.
-- ============================================================

insert into storage.buckets (id, name, public)
values ('student-qualifications', 'student-qualifications', false)
on conflict (id) do nothing;

-- Lezen: staff + auditor alles, cursist alleen eigen map
-- (eerste paddeel = zijn student_id)
drop policy if exists p_qual_read on storage.objects;
create policy p_qual_read on storage.objects for select
  using (
    bucket_id = 'student-qualifications'
    and (
      can_read_all()
      or (storage.foldername(name))[1] = my_student_id()::text
    )
  );

-- Uploaden: alleen staff
drop policy if exists p_qual_write on storage.objects;
create policy p_qual_write on storage.objects for insert
  with check ( bucket_id = 'student-qualifications' and is_staff() );

-- Wijzigen: alleen staff
drop policy if exists p_qual_update on storage.objects;
create policy p_qual_update on storage.objects for update
  using ( bucket_id = 'student-qualifications' and is_staff() )
  with check ( bucket_id = 'student-qualifications' and is_staff() );

-- Verwijderen: alleen staff
drop policy if exists p_qual_delete on storage.objects;
create policy p_qual_delete on storage.objects for delete
  using ( bucket_id = 'student-qualifications' and is_staff() );
