-- ============================================================
-- Plaza Boat College — Storage voor cursuscontent (readers + decks)
-- Voer dit uit NA migrations/0002_elearning.sql (1x).
-- Maakt een private bucket 'course-content' met toegangsregels:
--   - ingelogde gebruikers (student/staff/auditor): mogen LEZEN
--   - staff (admin/instructor): mogen uploaden/wijzigen/verwijderen
-- Bestandspad-conventie: bm3/readers/Mxx.pdf  en  bm3/decks/Mxx.pdf
-- ============================================================

insert into storage.buckets (id, name, public)
values ('course-content', 'course-content', false)
on conflict (id) do nothing;

-- Lezen: elke ingelogde gebruiker (cursusmateriaal is voor alle cursisten)
drop policy if exists p_course_content_read on storage.objects;
create policy p_course_content_read on storage.objects for select
  using ( bucket_id = 'course-content' and auth.uid() is not null );

-- Uploaden: alleen staff
drop policy if exists p_course_content_insert on storage.objects;
create policy p_course_content_insert on storage.objects for insert
  with check ( bucket_id = 'course-content' and is_staff() );

-- Wijzigen: alleen staff
drop policy if exists p_course_content_update on storage.objects;
create policy p_course_content_update on storage.objects for update
  using ( bucket_id = 'course-content' and is_staff() )
  with check ( bucket_id = 'course-content' and is_staff() );

-- Verwijderen: alleen staff
drop policy if exists p_course_content_delete on storage.objects;
create policy p_course_content_delete on storage.objects for delete
  using ( bucket_id = 'course-content' and is_staff() );
