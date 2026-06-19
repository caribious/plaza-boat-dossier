-- ============================================================
-- Plaza Boat College — Storage voor certificaat-PDF's
-- Voer dit uit NA schema.sql (1x).
-- Maakt een private bucket 'certificates' met toegangsregels:
--   - staff (admin/instructor): mag uploaden, lezen, verwijderen
--   - student: mag ALLEEN zijn eigen certificaten lezen
-- Bestandspad-conventie: <student_id>/<certificate_id>.pdf
-- ============================================================

insert into storage.buckets (id, name, public)
values ('certificates', 'certificates', false)
on conflict (id) do nothing;

-- Lezen: staff alles, student alleen eigen map (eerste paddeel = zijn student_id)
drop policy if exists p_cert_read on storage.objects;
create policy p_cert_read on storage.objects for select
  using (
    bucket_id = 'certificates'
    and (
      can_read_all()
      or (storage.foldername(name))[1] = my_student_id()::text
    )
  );

-- Uploaden/wijzigen/verwijderen: alleen staff
drop policy if exists p_cert_write on storage.objects;
create policy p_cert_write on storage.objects for insert
  with check ( bucket_id = 'certificates' and is_staff() );

drop policy if exists p_cert_update on storage.objects;
create policy p_cert_update on storage.objects for update
  using ( bucket_id = 'certificates' and is_staff() )
  with check ( bucket_id = 'certificates' and is_staff() );

drop policy if exists p_cert_delete on storage.objects;
create policy p_cert_delete on storage.objects for delete
  using ( bucket_id = 'certificates' and is_staff() );

-- ------------------------------------------------------------
-- Bucket voor instructeurcertificaten — uitsluitend staff
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('instructor-certificates', 'instructor-certificates', false)
on conflict (id) do nothing;

drop policy if exists p_instrcert_all on storage.objects;
create policy p_instrcert_all on storage.objects for all
  using ( bucket_id = 'instructor-certificates' and is_staff() )
  with check ( bucket_id = 'instructor-certificates' and is_staff() );
drop policy if exists p_instrcert_read on storage.objects;
create policy p_instrcert_read on storage.objects for select
  using ( bucket_id = 'instructor-certificates' and can_read_all() );
