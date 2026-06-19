-- ============================================================
-- Plaza Boat College — VOLLEDIGE INSTALLATIE (1 plak-actie)
-- Plak dit hele bestand in Supabase > SQL Editor en klik Run.
-- Bevat: schema + toegangsregels + audit + storage-buckets.
-- (Demo-data staat apart in seed-demo.sql — optioneel.)
-- ============================================================

-- ============================================================
-- Plaza Boat College — Student Records System
-- Supabase / Postgres schema + Row Level Security + audit-log
-- ------------------------------------------------------------
-- Voer dit bestand 1x uit in de Supabase SQL Editor.
-- Het maakt: tabellen, toegangsregels (RLS), audit-logging en
-- de basis-referentiedata (BM I/II/III + modules).
-- ============================================================

-- Benodigde extensie (voor wachtwoord-hashing in de demo-seed)
create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- 1. ENUMS (vaste keuzelijsten)
-- ------------------------------------------------------------
do $$ begin
  -- 'auditor' = ILT-inspecteur (read-only, ziet alles)
  create type user_role        as enum ('admin','instructor','student','auditor');
exception when duplicate_object then null; end $$;
-- Voor wie het oude enum al had (zonder auditor) — veilig her-uitvoerbaar:
alter type user_role add value if not exists 'auditor';
do $$ begin
  create type enrollment_status as enum ('enrolled','active','completed','withdrawn');
exception when duplicate_object then null; end $$;
do $$ begin
  create type progress_status   as enum ('not_started','in_progress','completed');
exception when duplicate_object then null; end $$;
do $$ begin
  -- Examenvormen conform SCV Code X/8.1 (mondeling + praktijk) en X/8.5 (kennistoets)
  create type exam_kind         as enum ('oral','practical','knowledge_mcq');
exception when duplicate_object then null; end $$;
do $$ begin
  create type exam_outcome      as enum ('pending','passed','failed');
exception when duplicate_object then null; end $$;

-- ------------------------------------------------------------
-- 2. PROFILES — koppeling aan Supabase Auth (login-accounts)
-- ------------------------------------------------------------
create table if not exists profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  role        user_role not null default 'student',
  full_name   text not null default '',
  email       text,
  created_at  timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 3. STUDENTS — het volledige cursistdossier
-- ------------------------------------------------------------
create table if not exists students (
  id                uuid primary key default gen_random_uuid(),
  profile_id        uuid unique references profiles(id) on delete set null, -- login-koppeling
  student_number    text unique not null,
  first_name        text not null,          -- VERPLICHT
  last_name         text not null,          -- VERPLICHT
  date_of_birth     date not null,          -- VERPLICHT (identiteit + certificaat)
  place_of_birth    text,                   -- aanbevolen op SCV-certificaat
  email             text,                   -- optioneel (operationeel)
  phone             text,                   -- optioneel
  nationality       text,                   -- optioneel
  address           text,                   -- optioneel
  identity_verified boolean default false,  -- ID gecontroleerd bij examen (ja/nee)
  id_document_type  text,                   -- bv. 'Paspoort' / 'ID-kaart' (geen nummer/BSN)
  rya_number        text,                   -- optioneel: alleen bij vrijstelling/vooropleiding
  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 4. COURSES — lesprogramma's (BM I / II / III)
-- ------------------------------------------------------------
create table if not exists courses (
  id                   uuid primary key default gen_random_uuid(),
  code                 text unique not null,   -- 'BM-I' / 'BM-II' / 'BM-III'
  title                text not null,
  description          text,
  regulatory_reference text,                   -- bv. 'SCV Code Ch X / RVZ Bijlage 6'
  created_at           timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 5. MODULES — onderdelen binnen een lesprogramma
-- ------------------------------------------------------------
create table if not exists modules (
  id             uuid primary key default gen_random_uuid(),
  course_id      uuid not null references courses(id) on delete cascade,
  sequence       int not null default 0,
  code           text,                  -- 'M05' / 'EFA'
  title          text not null,         -- 'Fire Fighting'
  required_hours numeric(5,1) default 0,
  is_practical   boolean default false
);

-- ------------------------------------------------------------
-- 6. ENROLLMENTS — inschrijving van cursist op lesprogramma
-- ------------------------------------------------------------
create table if not exists enrollments (
  id              uuid primary key default gen_random_uuid(),
  student_id      uuid not null references students(id) on delete cascade,
  course_id       uuid not null references courses(id) on delete restrict,
  status          enrollment_status not null default 'enrolled',
  start_date      date,
  target_end_date date,
  created_at      timestamptz not null default now(),
  unique (student_id, course_id)
);

-- ------------------------------------------------------------
-- 7. MODULE_PROGRESS — voortgang + uren per module
-- ------------------------------------------------------------
create table if not exists module_progress (
  id              uuid primary key default gen_random_uuid(),
  enrollment_id   uuid not null references enrollments(id) on delete cascade,
  module_id       uuid not null references modules(id) on delete cascade,
  status          progress_status not null default 'not_started',
  hours_logged    numeric(5,1) default 0,
  completed_at    timestamptz,
  instructor_name text,
  updated_at      timestamptz not null default now(),
  unique (enrollment_id, module_id)
);

-- ------------------------------------------------------------
-- 8. EXAM_RESULTS — examenresultaten (mondeling/praktijk/kennistoets)
--    examiner_name = examinator (ILT-eis: niet de eigen instructeur)
--    valid_until   = X/8.3: geslaagd deel 1 jaar geldig bij herkansing
-- ------------------------------------------------------------
create table if not exists exam_results (
  id            uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references enrollments(id) on delete cascade,
  kind          exam_kind not null,
  attempt       int not null default 1,
  exam_date     date,
  examiner_name text,
  score         numeric(5,1),
  max_score     numeric(5,1),
  outcome       exam_outcome not null default 'pending',
  valid_until   date,
  remarks       text,
  created_at    timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 9. CERTIFICATES — certificatenregister per cursist
-- ------------------------------------------------------------
create table if not exists certificates (
  id                   uuid primary key default gen_random_uuid(),
  student_id           uuid not null references students(id) on delete cascade,
  course_id            uuid references courses(id) on delete set null,
  certificate_number   text unique not null,
  title                text not null,
  regulatory_reference text,
  issued_date          date,
  expiry_date          date,
  file_path            text,   -- pad in Supabase Storage (PDF)
  created_at           timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 10. INSTRUCTORS — personeels-/instructeurregister
-- ------------------------------------------------------------
create table if not exists instructors (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid references profiles(id) on delete set null,
  first_name  text not null,
  last_name   text not null,
  title       text,            -- bv. 'RYA Chief Instructor'
  email       text,
  phone       text,
  active      boolean default true,
  notes       text,
  created_at  timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 11. INSTRUCTOR_CERTIFICATES — kwalificaties per instructeur
--     (RYA / MCA / FFA / PST / EFR) met nummer + geldigheid (ILT comp. 5)
-- ------------------------------------------------------------
create table if not exists instructor_certificates (
  id                 uuid primary key default gen_random_uuid(),
  instructor_id      uuid not null references instructors(id) on delete cascade,
  cert_type          text not null,   -- 'RYA Powerboat Instructor', 'VHF/SRC', 'FFA', 'PST', 'EFR'
  certificate_number text,
  issuing_body       text,            -- 'RYA' / 'MCA' / ...
  issued_date        date,
  expiry_date        date,
  file_path          text,            -- pad in Supabase Storage (PDF)
  created_at         timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 12. AUDIT_LOG — onveranderbaar spoor van alle wijzigingen
-- ------------------------------------------------------------
create table if not exists audit_log (
  id              bigserial primary key,
  table_name      text not null,
  record_id       text,
  action          text not null,        -- INSERT / UPDATE / DELETE
  changed_by      uuid,
  changed_by_email text,
  changed_at      timestamptz not null default now(),
  old_data        jsonb,
  new_data        jsonb
);

-- ============================================================
-- HELPER-FUNCTIES (security definer = omzeilen RLS-recursie)
-- ============================================================
create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles
    where id = auth.uid() and role in ('admin','instructor')
  );
$$;

create or replace function public.my_student_id()
returns uuid language sql stable security definer set search_path = public as $$
  select id from students where profile_id = auth.uid();
$$;

-- Mag alles lezen: admin, instructor én auditor (ILT-inspecteur).
create or replace function public.can_read_all()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from profiles
    where id = auth.uid() and role in ('admin','instructor','auditor')
  );
$$;

-- Profiel automatisch aanmaken zodra een Auth-gebruiker ontstaat
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name',''),
    coalesce((new.raw_user_meta_data->>'role')::user_role,'student')
  )
  on conflict (id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- AUDIT-TRIGGER — logt elke insert/update/delete
-- ============================================================
create or replace function public.fn_audit()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_email text;
begin
  select email into v_email from profiles where id = auth.uid();
  if (tg_op = 'DELETE') then
    insert into audit_log(table_name, record_id, action, changed_by, changed_by_email, old_data)
    values (tg_table_name, old.id::text, tg_op, auth.uid(), v_email, to_jsonb(old));
    return old;
  elsif (tg_op = 'UPDATE') then
    insert into audit_log(table_name, record_id, action, changed_by, changed_by_email, old_data, new_data)
    values (tg_table_name, new.id::text, tg_op, auth.uid(), v_email, to_jsonb(old), to_jsonb(new));
    return new;
  else
    insert into audit_log(table_name, record_id, action, changed_by, changed_by_email, new_data)
    values (tg_table_name, new.id::text, tg_op, auth.uid(), v_email, to_jsonb(new));
    return new;
  end if;
end; $$;

do $$
declare t text;
begin
  foreach t in array array['students','enrollments','module_progress','exam_results','certificates','instructors','instructor_certificates']
  loop
    execute format('drop trigger if exists audit_%1$s on %1$s;', t);
    execute format('create trigger audit_%1$s after insert or update or delete on %1$s
                    for each row execute function public.fn_audit();', t);
  end loop;
end $$;

-- ============================================================
-- ROW LEVEL SECURITY
-- Staff (admin/instructor) = volledige toegang.
-- Student = alleen-lezen op uitsluitend zijn eigen dossier.
-- ============================================================
alter table profiles        enable row level security;
alter table students        enable row level security;
alter table courses         enable row level security;
alter table modules         enable row level security;
alter table enrollments     enable row level security;
alter table module_progress enable row level security;
alter table exam_results    enable row level security;
alter table certificates    enable row level security;
alter table instructors     enable row level security;
alter table instructor_certificates enable row level security;
alter table audit_log       enable row level security;

-- PROFILES: eigen profiel of staff
drop policy if exists p_profiles_select on profiles;
create policy p_profiles_select on profiles for select
  using ( id = auth.uid() or can_read_all() );
drop policy if exists p_profiles_staff_all on profiles;
create policy p_profiles_staff_all on profiles for all
  using ( is_staff() ) with check ( is_staff() );

-- COURSES & MODULES: leesbaar voor alle ingelogde gebruikers, schrijven = staff
drop policy if exists p_courses_read on courses;
create policy p_courses_read on courses for select using ( auth.uid() is not null );
drop policy if exists p_courses_staff on courses;
create policy p_courses_staff on courses for all using ( is_staff() ) with check ( is_staff() );

drop policy if exists p_modules_read on modules;
create policy p_modules_read on modules for select using ( auth.uid() is not null );
drop policy if exists p_modules_staff on modules;
create policy p_modules_staff on modules for all using ( is_staff() ) with check ( is_staff() );

-- STUDENTS: staff alles; student leest eigen rij
drop policy if exists p_students_select on students;
create policy p_students_select on students for select
  using ( can_read_all() or profile_id = auth.uid() );
drop policy if exists p_students_staff on students;
create policy p_students_staff on students for all
  using ( is_staff() ) with check ( is_staff() );

-- ENROLLMENTS
drop policy if exists p_enroll_select on enrollments;
create policy p_enroll_select on enrollments for select
  using ( can_read_all() or student_id = my_student_id() );
drop policy if exists p_enroll_staff on enrollments;
create policy p_enroll_staff on enrollments for all
  using ( is_staff() ) with check ( is_staff() );

-- MODULE_PROGRESS
drop policy if exists p_progress_select on module_progress;
create policy p_progress_select on module_progress for select
  using ( can_read_all() or enrollment_id in (
    select id from enrollments where student_id = my_student_id() ) );
drop policy if exists p_progress_staff on module_progress;
create policy p_progress_staff on module_progress for all
  using ( is_staff() ) with check ( is_staff() );

-- EXAM_RESULTS
drop policy if exists p_exam_select on exam_results;
create policy p_exam_select on exam_results for select
  using ( can_read_all() or enrollment_id in (
    select id from enrollments where student_id = my_student_id() ) );
drop policy if exists p_exam_staff on exam_results;
create policy p_exam_staff on exam_results for all
  using ( is_staff() ) with check ( is_staff() );

-- CERTIFICATES
drop policy if exists p_cert_select on certificates;
create policy p_cert_select on certificates for select
  using ( can_read_all() or student_id = my_student_id() );
drop policy if exists p_cert_staff on certificates;
create policy p_cert_staff on certificates for all
  using ( is_staff() ) with check ( is_staff() );

-- INSTRUCTORS + CERTIFICATEN: staff bewerkt; staff + inspecteur lezen
drop policy if exists p_instr_all on instructors;
create policy p_instr_all on instructors for all
  using ( is_staff() ) with check ( is_staff() );
drop policy if exists p_instr_select on instructors;
create policy p_instr_select on instructors for select
  using ( can_read_all() );

drop policy if exists p_instr_cert_all on instructor_certificates;
create policy p_instr_cert_all on instructor_certificates for all
  using ( is_staff() ) with check ( is_staff() );
drop policy if exists p_instr_cert_select on instructor_certificates;
create policy p_instr_cert_select on instructor_certificates for select
  using ( can_read_all() );

-- AUDIT_LOG: staff + inspecteur mogen lezen (niemand mag wijzigen/verwijderen)
drop policy if exists p_audit_select on audit_log;
create policy p_audit_select on audit_log for select using ( can_read_all() );

-- ============================================================
-- REFERENTIEDATA — BM I / II / III + modules (Grade III uitgewerkt)
-- ============================================================
insert into courses (code, title, description, regulatory_reference) values
  ('BM-I',  'Boatmaster Grade I',  'Inland / nabij de kust — basisniveau.', 'SCV Code / RVZ Bijlage 6'),
  ('BM-II', 'Boatmaster Grade II', 'Uitgebreid vaargebied.',                  'SCV Code / RVZ Bijlage 6'),
  ('BM-III','Boatmaster Grade III','Small Commercial Vessels — SCV Code Ch X.', 'SCV Code Ch X / RVZ Bijlage 6')
on conflict (code) do nothing;

-- Modules per opleiding — titels gelijk aan de e-learning (matching op volgnummer).
insert into modules (course_id, sequence, code, title, required_hours, is_practical)
select c.id, v.seq, 'M' || lpad(v.seq::text, 2, '0'), v.title, v.hours, v.practical
from courses c
join (values
  -- BM I (modulestructuur; content in ontwikkeling)
  ('BM-I',  1,'Introduction & Grade 1 Scope',                4.0, false),
  ('BM-I',  2,'Legislation & Operational Requirements',      4.0, false),
  ('BM-I',  3,'Chartwork, Position Fixing & Voyage Planning',6.0, false),
  ('BM-I',  4,'COLREG (Full Knowledge)',                     6.0, false),
  ('BM-I',  5,'Seamanship & Boat Handling (12-24 m)',        8.0, true),
  ('BM-I',  6,'Engineering',                                 4.0, false),
  ('BM-I',  7,'Passenger Safety & Emergencies',              4.0, false),
  ('BM-I',  8,'MARPOL',                                      4.0, false),
  ('BM-I',  9,'Fire Fighting',                               8.0, true),
  ('BM-I', 10,'Sea Survival',                                8.0, true),
  ('BM-I', 11,'Buoyage & Electronic Navigation',            4.0, false),
  ('BM-I', 12,'Vessel Construction & Stability',            4.0, false),
  ('BM-I', 13,'GMDSS',                                       4.0, false),
  ('BM-I', 14,'Elementary First Aid',                        8.0, true),
  -- BM II (volledig gevuld)
  ('BM-II', 1,'Introduction & Grade 2 Scope',               4.0, false),
  ('BM-II', 2,'Legislation, Operational Requirements & SMS', 4.0, false),
  ('BM-II', 3,'Chartwork, Navigation & Electronic Aids',    6.0, false),
  ('BM-II', 4,'COLREG (Full Knowledge)',                    6.0, false),
  ('BM-II', 5,'Seamanship 1',                               6.0, true),
  ('BM-II', 6,'Seamanship 2 & Boat Handling',              8.0, true),
  ('BM-II', 7,'Engineering',                                4.0, false),
  ('BM-II', 8,'Passenger Safety, Emergencies & SAR',       4.0, false),
  ('BM-II', 9,'MARPOL',                                     4.0, false),
  ('BM-II',10,'Fire Fighting',                              8.0, true),
  ('BM-II',11,'Sea Survival',                               8.0, true),
  ('BM-II',12,'Elementary First Aid',                       8.0, true),
  -- BM III (volledig gevuld)
  ('BM-III', 1,'Introduction',                             4.0, false),
  ('BM-III', 2,'Legislation (Caribbean NL)',               4.0, false),
  ('BM-III', 3,'Chartwork, Navigation & Meteorology',      6.0, false),
  ('BM-III', 4,'COLREG',                                   6.0, false),
  ('BM-III', 5,'Seamanship 1',                             6.0, true),
  ('BM-III', 6,'Seamanship 2 & Boat Handling',            8.0, true),
  ('BM-III', 7,'Engineering',                              4.0, false),
  ('BM-III', 8,'Passenger Safety & Emergencies',          4.0, false),
  ('BM-III', 9,'MARPOL',                                   4.0, false),
  ('BM-III',10,'Fire Fighting',                            8.0, true),
  ('BM-III',11,'Sea Survival',                             8.0, true),
  ('BM-III',12,'Elementary First Aid',                     8.0, true)
) as v(course_code, seq, title, hours, practical) on true
where c.code = v.course_code
  and not exists (select 1 from modules m where m.course_id = c.id and m.sequence = v.seq);

-- ============================================================
-- KOPPELING E-LEARNING (client-side, veilig)
-- Een ingelogde cursist roept deze functie aan om ZIJN EIGEN
-- voortgang weg te schrijven. security definer schrijft door de
-- read-only RLS heen, maar uitsluitend voor de eigen inschrijving
-- (via my_student_id() = auth.uid()). Geen geheime sleutel in de browser.
-- ============================================================
create or replace function public.record_elearning_result(
  p_course_code     text,
  p_type            text,
  p_module_sequence int     default null,
  p_score           numeric default null,
  p_max             numeric default null,
  p_passed          boolean default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_student  uuid;
  v_course   uuid;
  v_enroll   uuid;
  v_module   uuid;
  v_existing uuid;
  v_outcome  exam_outcome;
  v_valid    date;
begin
  v_student := my_student_id();
  if v_student is null then
    return jsonb_build_object('ok', false, 'error', 'Geen cursistdossier voor dit account.');
  end if;

  -- Opleiding matchen, genormaliseerd ('BM II' == 'BM-II')
  select id into v_course from courses
   where upper(regexp_replace(code, '[\s\-_.]', '', 'g')) =
         upper(regexp_replace(p_course_code, '[\s\-_.]', '', 'g'))
   limit 1;
  if v_course is null then
    return jsonb_build_object('ok', false, 'error', 'Opleiding niet gevonden.');
  end if;

  -- Inschrijving zoeken of aanmaken (alleen voor de cursist zelf)
  select id into v_enroll from enrollments
    where student_id = v_student and course_id = v_course limit 1;
  if v_enroll is null then
    insert into enrollments (student_id, course_id, status, start_date)
    values (v_student, v_course, 'active', current_date) returning id into v_enroll;
    insert into module_progress (enrollment_id, module_id, status)
      select v_enroll, m.id, 'not_started' from modules m where m.course_id = v_course;
  end if;

  if p_type in ('module_complete','quiz') then
    if p_module_sequence is null then
      return jsonb_build_object('ok', false, 'error', 'module_sequence vereist.');
    end if;
    select id into v_module from modules
      where course_id = v_course and sequence = p_module_sequence limit 1;
    if v_module is null then
      return jsonb_build_object('ok', false, 'error', 'Module niet gevonden.');
    end if;
    update module_progress
       set status = case when coalesce(p_passed, true)
                         then 'completed'::progress_status
                         else 'in_progress'::progress_status end,
           completed_at = case when coalesce(p_passed, true) then now() else null end,
           updated_at = now()
     where enrollment_id = v_enroll and module_id = v_module;
    return jsonb_build_object('ok', true, 'recorded', 'module_progress');

  elsif p_type = 'exam' then
    v_outcome := case when p_passed is true then 'passed'
                      when p_passed is false then 'failed'
                      else 'pending' end::exam_outcome;
    if v_outcome = 'passed' then v_valid := current_date + interval '1 year'; end if;
    select id into v_existing from exam_results
      where enrollment_id = v_enroll and kind = 'knowledge_mcq'
      order by attempt desc limit 1;
    if v_existing is not null then
      update exam_results set exam_date = current_date, score = p_score, max_score = p_max,
             outcome = v_outcome, valid_until = v_valid, remarks = 'Bijgewerkt via e-learning'
       where id = v_existing;
    else
      insert into exam_results (enrollment_id, kind, attempt, exam_date, score, max_score,
                                outcome, valid_until, examiner_name, remarks)
      values (v_enroll, 'knowledge_mcq', 1, current_date, p_score, p_max,
              v_outcome, v_valid, 'E-learning (automatisch)', 'Oefenexamen e-learning');
    end if;
    return jsonb_build_object('ok', true, 'recorded', 'exam_results');
  end if;

  return jsonb_build_object('ok', false, 'error', 'Onbekend type.');
end; $$;

grant execute on function public.record_elearning_result(text,text,int,numeric,numeric,boolean) to authenticated;

-- ============================================================
-- MIGRATIE — voor wie een eerdere versie van het schema al draaide.
-- Voegt de nieuwe kolommen toe als ze nog ontbreken (veilig her-uitvoerbaar).
-- ============================================================
alter table students
  add column if not exists place_of_birth    text,
  add column if not exists identity_verified boolean default false,
  add column if not exists id_document_type  text,
  add column if not exists rya_number        text;

-- Klaar. Voer hierna storage.sql uit, en optioneel seed-demo.sql voor demo-data.

-- ===== STORAGE =====

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
