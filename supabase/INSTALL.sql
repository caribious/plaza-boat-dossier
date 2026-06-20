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
  -- BM I (13 modules — gelijk aan e-learning data.js / readers BMI)
  ('BM-I',  1,'Introduction & Grade 1 Scope',                4.0, false),
  ('BM-I',  2,'Legislation, Operational Requirements & SMS', 4.0, false),
  ('BM-I',  3,'Chartwork, Navigation & Passage Planning',    6.0, false),
  ('BM-I',  4,'COLREG (Full Knowledge)',                     6.0, false),
  ('BM-I',  5,'Seamanship 1',                                6.0, true),
  ('BM-I',  6,'Seamanship 2 & Boat Handling (12–24 m)',      8.0, true),
  ('BM-I',  7,'Engineering',                                 4.0, false),
  ('BM-I',  8,'Passenger Safety, Emergencies & SAR',         4.0, false),
  ('BM-I',  9,'MARPOL & Dangerous Goods',                    4.0, false),
  ('BM-I', 10,'Fire Fighting',                               8.0, true),
  ('BM-I', 11,'Sea Survival & GMDSS',                        8.0, true),
  ('BM-I', 12,'Elementary First Aid',                        8.0, true),
  ('BM-I', 13,'Vessel Construction, Stability & Buoyage',    4.0, false),
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


-- ############################################################
-- E-LEARNING (BM III online cursus) — migratie 0002 + storage + seed
-- Toegevoegd zodat INSTALL.sql de volledige installatie blijft.
-- ############################################################

-- ============================================================
-- Plaza Boat College — E-learning (BM III online cursus)
-- Migratie 0002 — vragenbank, quiz-pogingen, module-content
-- ------------------------------------------------------------
-- Idempotent (veilig her-uitvoerbaar). Volgt de stijl van schema.sql.
-- Voer dit 1x uit in de Supabase SQL Editor NA schema.sql.
-- ============================================================

-- ------------------------------------------------------------
-- 1. MODULES — extra kolommen voor content + samenvatting
--    reader_path / deck_path = storage-pad in bucket 'course-content'
-- ------------------------------------------------------------
alter table modules
  add column if not exists reader_path text,
  add column if not exists deck_path   text,
  add column if not exists summary     text,
  -- gecureerde vragenlijst per module (array van question-id's). Optioneel:
  -- de quiz gebruikt deze lijst als hij gevuld is, anders alle vragen met
  -- het bijbehorende module_seq.
  add column if not exists quiz_ids    jsonb;

-- ------------------------------------------------------------
-- 2. QUESTIONS — vragenbank (per opleiding + module)
--    correct = 0-based index in opts (jsonb-array van strings)
-- ------------------------------------------------------------
create table if not exists questions (
  id          text primary key,            -- bv. 'bm3:M01-001'
  course_code text not null,               -- 'BM-III'
  module_seq  int,                         -- volgnummer module (matcht modules.sequence)
  ref         text,                         -- bronverwijzing (annex/paragraaf)
  stem        text not null,               -- de vraag
  opts        jsonb not null,              -- ["A","B","C","D"]
  correct     int  not null,               -- 0-based index van juiste antwoord
  expl        text,                         -- uitleg / toelichting
  created_at  timestamptz not null default now()
);

create index if not exists idx_questions_course_module
  on questions (course_code, module_seq);

-- ------------------------------------------------------------
-- 3. QUIZ_ATTEMPTS — pogingen (oefenquiz per module + mock-examen)
--    kind via check-constraint (geen apart enum nodig).
-- ------------------------------------------------------------
create table if not exists quiz_attempts (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid not null references students(id) on delete cascade,
  course_code text not null,
  module_seq  int,                          -- null bij mock-examen
  kind        text not null check (kind in ('quiz','mock')),
  score       int  not null default 0,
  max         int  not null default 0,
  passed      boolean not null default false,
  answers     jsonb,                        -- [{id, chosen, correct}]
  created_at  timestamptz not null default now()
);

create index if not exists idx_quiz_attempts_student
  on quiz_attempts (student_id, created_at desc);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table questions      enable row level security;
alter table quiz_attempts  enable row level security;

-- QUESTIONS: alle ingelogde gebruikers mogen lezen; staff beheert
drop policy if exists p_questions_read on questions;
create policy p_questions_read on questions for select
  using ( auth.uid() is not null );
drop policy if exists p_questions_staff on questions;
create policy p_questions_staff on questions for all
  using ( is_staff() ) with check ( is_staff() );

-- QUIZ_ATTEMPTS: student ziet/insert eigen rijen; staff alles
drop policy if exists p_attempts_select on quiz_attempts;
create policy p_attempts_select on quiz_attempts for select
  using ( can_read_all() or student_id = my_student_id() );

drop policy if exists p_attempts_insert on quiz_attempts;
create policy p_attempts_insert on quiz_attempts for insert
  with check ( student_id = my_student_id() or is_staff() );

drop policy if exists p_attempts_staff on quiz_attempts;
create policy p_attempts_staff on quiz_attempts for all
  using ( is_staff() ) with check ( is_staff() );

-- ============================================================
-- RPC's voor de in-app cursus (SECURITY DEFINER).
-- De cursist roept deze aan met zijn ingelogde server-client. De
-- functie schrijft uitsluitend voor ZIJN EIGEN dossier (via
-- my_student_id() = auth.uid()), zodat de read-only RLS op
-- enrollments/module_progress/exam_results netjes wordt nageleefd.
-- Geen service-role in de browser of server-action nodig.
-- ============================================================

-- Zorgt dat de ingelogde cursist een inschrijving op de opleiding heeft
-- (en zet de modulevoortgang klaar). Geeft enrollment-id terug.
create or replace function public.ensure_my_enrollment(p_course_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_student uuid;
  v_course  uuid;
  v_enroll  uuid;
begin
  v_student := my_student_id();
  if v_student is null then
    raise exception 'Geen cursistdossier voor dit account.';
  end if;

  select id into v_course from courses
   where upper(regexp_replace(code, '[\s\-_.]', '', 'g')) =
         upper(regexp_replace(p_course_code, '[\s\-_.]', '', 'g'))
   limit 1;
  if v_course is null then
    raise exception 'Opleiding niet gevonden.';
  end if;

  select id into v_enroll from enrollments
    where student_id = v_student and course_id = v_course limit 1;
  if v_enroll is null then
    insert into enrollments (student_id, course_id, status, start_date)
    values (v_student, v_course, 'active', current_date) returning id into v_enroll;
    insert into module_progress (enrollment_id, module_id, status)
      select v_enroll, m.id, 'not_started' from modules m where m.course_id = v_course;
  end if;
  return v_enroll;
end; $$;

grant execute on function public.ensure_my_enrollment(text) to authenticated;

-- Module afronden + quizpoging vastleggen. Schrijft:
--   - module_progress.status = completed (of in_progress als niet geslaagd)
--   - quiz_attempts (kind 'quiz')
create or replace function public.record_module_quiz(
  p_course_code     text,
  p_module_sequence int,
  p_score           int,
  p_max             int,
  p_passed          boolean,
  p_answers         jsonb default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_student uuid;
  v_course  uuid;
  v_enroll  uuid;
  v_module  uuid;
begin
  v_student := my_student_id();
  if v_student is null then
    return jsonb_build_object('ok', false, 'error', 'Geen cursistdossier.');
  end if;

  v_enroll := ensure_my_enrollment(p_course_code);

  select c.id into v_course from courses c
   where upper(regexp_replace(c.code, '[\s\-_.]', '', 'g')) =
         upper(regexp_replace(p_course_code, '[\s\-_.]', '', 'g')) limit 1;

  select m.id into v_module from modules m
   where m.course_id = v_course and m.sequence = p_module_sequence limit 1;
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

  insert into quiz_attempts (student_id, course_code, module_seq, kind, score, max, passed, answers)
  values (v_student, p_course_code, p_module_sequence, 'quiz',
          coalesce(p_score,0), coalesce(p_max,0), coalesce(p_passed,false), p_answers);

  return jsonb_build_object('ok', true);
end; $$;

grant execute on function public.record_module_quiz(text,int,int,int,boolean,jsonb) to authenticated;

-- Mock-examen vastleggen. Schrijft:
--   - exam_results (kind knowledge_mcq, examiner_name 'E-learning (oefenexamen)')
--   - quiz_attempts (kind 'mock')
create or replace function public.record_mock_exam(
  p_course_code text,
  p_score       int,
  p_max         int,
  p_passed      boolean,
  p_answers     jsonb default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_student  uuid;
  v_enroll   uuid;
  v_outcome  exam_outcome;
  v_valid    date;
  v_attempt  int;
begin
  v_student := my_student_id();
  if v_student is null then
    return jsonb_build_object('ok', false, 'error', 'Geen cursistdossier.');
  end if;

  v_enroll := ensure_my_enrollment(p_course_code);

  v_outcome := case when p_passed then 'passed' else 'failed' end::exam_outcome;
  if v_outcome = 'passed' then v_valid := current_date + interval '1 year'; end if;

  select coalesce(max(attempt),0) + 1 into v_attempt from exam_results
    where enrollment_id = v_enroll and kind = 'knowledge_mcq';

  insert into exam_results (enrollment_id, kind, attempt, exam_date, score, max_score,
                            outcome, valid_until, examiner_name, remarks)
  values (v_enroll, 'knowledge_mcq', v_attempt, current_date, p_score, p_max,
          v_outcome, v_valid, 'E-learning (oefenexamen)', 'Oefenexamen via online cursus');

  insert into quiz_attempts (student_id, course_code, module_seq, kind, score, max, passed, answers)
  values (v_student, p_course_code, null, 'mock',
          coalesce(p_score,0), coalesce(p_max,0), coalesce(p_passed,false), p_answers);

  return jsonb_build_object('ok', true, 'outcome', v_outcome);
end; $$;

grant execute on function public.record_mock_exam(text,int,int,boolean,jsonb) to authenticated;

-- ------------------------------------------------------------
-- Klaar. Voer hierna seed-elearning-bm3.sql en storage-elearning.sql uit.
-- ------------------------------------------------------------


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


-- ============================================================
-- Plaza Boat College — Seed e-learning BM III
-- AUTOGEGENEREERD door scripts/gen-seed-bm3.mjs — niet handmatig bewerken.
-- Bron: data.js  ·  183 vragen
-- Idempotent: on conflict (id) do update. Voer uit NA migrations/0002_elearning.sql.
-- ============================================================

-- ---- Vragenbank (BM III) ----
insert into questions (id, course_code, module_seq, ref, stem, opts, correct, expl) values
  ('bm3:M01-001', 'BM-III', 1, 'Annex 11', 'Which chapter of the SCV Code 2021 covers licences for boatmasters and boat engineers?', '["Chapter VIII","Chapter X","Chapter I","Chapter V"]'::jsonb, 1, 'Answer B. Chapter X of the SCV Code covers licences for boatmasters and boat engineers.'),
  ('bm3:M01-002', 'BM-III', 1, 'Annex 11', 'What does Annex 11 of the SCV Code contain?', '["The examination syllabus for boatmaster and engineer licences","The construction and stability standards for the vessel","The list of life-saving appliances to be carried","The international rules to prevent collisions at sea"]'::jsonb, 0, 'Answer A. Annex 11 is the examination syllabus for the licences, set under Regulation X/8.'),
  ('bm3:M01-003', 'BM-III', 1, 'Table X/5.2', 'Under Table X/5.2, on what type of vessel and in which waters may a Grade 3 boatmaster operate?', '["A decked vessel in exposed waters","A passenger ship in coastal waters","An open boat in protected or coastal waters","Any vessel in protected waters at night"]'::jsonb, 2, 'Answer C. Table X/5.2: a Grade 3 boatmaster may command an open boat in protected or coastal waters. SCV Code 2021 · Caribbean Netherlands Page 2 / 40'),
  ('bm3:M01-004', 'BM-III', 1, 'Table X/5.2', 'What time-of-day restriction applies to a Grade 3 boatmaster licence?', '["No restriction","Daylight only","Night only","Between sunset and sunrise"]'::jsonb, 1, 'Answer B. A Grade 3 licence permits operation in daylight only (Table X/5.2).'),
  ('bm3:M01-005', 'BM-III', 1, 'X/6.1', 'What is the minimum age to be issued a Boatmaster Licence Grade 3 under Regulation X/6.1?', '["16 years","17 years","18 years","21 years"]'::jsonb, 2, 'Answer C. Regulation X/6.1 requires an applicant to be eighteen years of age or over.'),
  ('bm3:M01-006', 'BM-III', 1, 'X/6.1', 'A candidate is 18, holds a valid medical certificate, has completed practical instruction under a licensed boatmaster and has passed the Grade 3 theory exam, but cannot produce one further document required by X/6.1. What is most likely missing?', '["A VHF certificate","A passport photograph","A first aid instructor qualification","A vessel registration document"]'::jsonb, 0, 'Answer A. Regulation X/6.1 also requires the applicant to produce a VHF certificate.'),
  ('bm3:M01-007', 'BM-III', 1, 'X/8', 'What is the minimum mark needed to pass the BM III theory examination, out of a maximum of 50 points?', '["25","30","35","40"]'::jsonb, 2, 'Answer C. The theory exam requires a minimum of 35 out of a maximum of 50 points (about 70%).'),
  ('bm3:M01-008', 'BM-III', 1, null, 'A candidate has passed the theory paper and the fire-fighting, survival/passenger-safety and boat-handling practicals. Which separate assessment must they still complete to qualify?', '["A navigation chartwork test","An engine overhaul test","A Grade 2 oral examination","Elementary First Aid"]'::jsonb, 3, 'Answer D. Elementary First Aid is a separate assessment run outside the theory paper but required to qualify. SCV Code 2021 · Caribbean Netherlands Page 3 / 40'),
  ('bm3:M02-001', 'BM-III', 2, 'B3', 'Which islands make up the Caribbean Netherlands (BES)?', '["Aruba, Curacao and Sint Maarten","Bonaire, Sint Eustatius and Saba","Bonaire, Aruba and Curacao","Saba, Sint Maarten and Sint Eustatius"]'::jsonb, 1, 'Answer B. The Caribbean Netherlands (BES) comprises Bonaire, Sint Eustatius and Saba.'),
  ('bm3:M02-002', 'BM-III', 2, 'B3', 'To whom does a vessel owner apply for island registration in the Caribbean Netherlands?', '["The harbour master","The coastguard","The Administration of Shipping in The Hague","The local police"]'::jsonb, 0, 'Answer A. Island registration is required and you apply to the harbour master.'),
  ('bm3:M02-003', 'BM-III', 2, 'B3', 'An owner wants to operate a small commercial vessel in Bonaire. After island registration, what is the next step before it may operate?', '["Issue tickets to passengers immediately","Submit the vessel for certification under Annex 6 or the SCV Code","Apply for an international voyage permit","Register the vessel a second time with the coastguard"]'::jsonb, 1, 'Answer B. After registration the vessel is submitted for certification under either Annex 6 or the SCV Code.'),
  ('bm3:M02-004', 'BM-III', 2, 'B3', 'Your vessel previously held a Local certification and is now being certified under the SCV Code. What must you confirm regarding equipment?', '["That no equipment is required under the SCV Code","That Local and SCV certification always require identical equipment","That the equipment requirements may differ between Local and SCV certification","That equipment is decided solely by the boatmaster"]'::jsonb, 2, 'Answer C. Required equipment can differ between a Local and an SCV certification, so always confirm which applies.'),
  ('bm3:M02-005', 'BM-III', 2, null, 'What does RVZ Article 41b, first paragraph, establish for the Caribbean Netherlands?', '["The medical certificate validity period","The operating area for the Caribbean Netherlands, excluding certain parts","The minimum age for a boatmaster","The renewal cycle of the safety certificate"]'::jsonb, 1, 'Answer B. RVZ Article 41b, first paragraph, sets the operating area for the Caribbean Netherlands and excludes certain parts. SCV Code 2021 · Caribbean Netherlands Page 4 / 40'),
  ('bm3:M02-006', 'BM-III', 2, 'RVZ 62a', 'What does RVZ Article 62a contain?', '["The list of distress signals","The construction standards for open boats","The transitional regulations for Dutch Caribbean (Annex 6) ships","The pass mark for the theory examination"]'::jsonb, 2, 'Answer C. RVZ Article 62a contains the transitional regulations for Dutch Caribbean (Annex 6) ships.'),
  ('bm3:M02-007', 'BM-III', 2, null, 'How many passengers must a vessel carry to be classed as a passenger ship?', '["More than 6 passengers","More than 8 passengers","More than 12 passengers","More than 20 passengers"]'::jsonb, 2, 'Answer C. A passenger ship is a vessel, other than a pleasure vessel, carrying more than 12 passengers.'),
  ('bm3:M02-008', 'BM-III', 2, 'B3 / definitions', 'A skipper holding only a Grade 3 licence is asked to take charge of a vessel carrying 14 passengers. What is the correct position?', '["It is permitted because the vessel is small","It is permitted in daylight only","It is not permitted, as this is a passenger ship not covered by a Grade 3 licence","It is permitted in protected waters only"]'::jsonb, 2, 'Answer C. Carrying more than 12 passengers makes the vessel a passenger ship, which a Grade 3 licence does not cover.'),
  ('bm3:M02-009', 'BM-III', 2, null, 'Which of the following is excluded from the definition of a commercial vessel?', '["An excursion boat carrying passengers for reward","A fishing vessel","A vessel carrying cargo for reward","A boat carrying passengers on a voyage for reward"]'::jsonb, 1, 'Answer B. A commercial vessel carries cargo or passengers for reward; it does not include a fishing vessel.'),
  ('bm3:M02-010', 'BM-III', 2, 'Reg 10.8', 'Which regulation covers the crew certificate for a CN ship?', '["Reg 10.8","Reg 10.9","Reg 10.10","Reg 10.11"]'::jsonb, 0, 'Answer A. Reg 10.8 covers the crew certificate for a CN ship. SCV Code 2021 · Caribbean Netherlands Page 5 / 40'),
  ('bm3:M02-011', 'BM-III', 2, 'Reg 10.11', 'Which regulation applies to the master of a local CN ship (BM III)?', '["Reg 10.8","Reg 10.9","Reg 10.10","Reg 10.11"]'::jsonb, 3, 'Answer D. Reg 10.11 covers the master of a local CN ship (BM III).'),
  ('bm3:M02-012', 'BM-III', 2, 'Reg 10.10', 'Under Reg 10.10, how long is a medical fitness certificate valid for an Annex 6 ship and for an SCV Code ship respectively?', '["2 years (Annex 6) and 3 years (SCV Code)","3 years (Annex 6) and 2 years (SCV Code)","5 years (Annex 6) and 2 years (SCV Code)","3 years (Annex 6) and 5 years (SCV Code)"]'::jsonb, 1, 'Answer B. Reg 10.10: medical fitness is valid 3 years under Annex 6 and 2 years under the SCV Code.'),
  ('bm3:M02-013', 'BM-III', 2, 'Reg 10.11', 'A BM III applicant brings a BM III course certificate and a doctor''s medical statement to the harbour master for the RS licence. Which further document must they produce under Reg 10.11?', '["A tonnage certificate","A radar endorsement","A VHF certificate","An insurance policy"]'::jsonb, 2, 'Answer C. Reg 10.11 requires a BM III course certificate, a VHF certificate and a doctor''s medical statement.'),
  ('bm3:M02-014', 'BM-III', 2, 'Reg 10.11', 'Your RS licence is due for its three-year renewal. You provide a fresh doctor''s medical statement. What is the other requirement, including the minimum sailing time?', '["A re-sit of the theory paper","A statement of sailing time of at least 45 days in 3 years","A statement of sailing time of at least 90 days in 3 years","A new island registration"]'::jsonb, 1, 'Answer B. Renewal after three years requires a fresh medical statement plus a statement of sailing time of at least 45 days in 3 years.'),
  ('bm3:M02-015', 'BM-III', 2, 'Annex 6', 'How often must the engine of an Annex 6 vessel be serviced?', '["Once every 5 years","Once every 2 years","Once a year","Once every 6 months"]'::jsonb, 2, 'Answer C. Under Annex 6 the engine must be serviced periodically, once a year. SCV Code 2021 · Caribbean Netherlands Page 6 / 40'),
  ('bm3:M02-016', 'BM-III', 2, 'Annex 6', 'How often is the RS National Safety Certificate renewed, and when is the intermediate survey carried out?', '["Every 3 years, with an intermediate survey in the 1st year","Every 5 years, with no intermediate survey","Every 2 years, with an intermediate survey each year","Every 5 years, with an intermediate survey in the 2nd-3rd year"]'::jsonb, 3, 'Answer D. The RS National Safety Certificate is renewed every 5 years, with an intermediate survey in the 2nd-3rd year.'),
  ('bm3:M02-017', 'BM-III', 2, 'B9', 'Before crew handle paint and chemicals on board, which document should the boatmaster make sure they read?', '["The vessel''s tonnage certificate","The Material Safety Data Sheets (MSDS)","The passenger manifest","The COLREGs"]'::jsonb, 1, 'Answer B. Safe working practice requires reading the MSDS (Material Safety Data Sheets) for chemicals and paint.'),
  ('bm3:M02-018', 'BM-III', 2, null, 'Under SCV reg I/15, what does the SCV Safety Certificate record about persons carried?', '["The names of all crew on the voyage","The total number of persons permitted to be carried, as determined by the Administration","The number of passengers who have paid","The maximum cargo weight"]'::jsonb, 1, 'Answer B. Under SCV reg I/15 the total number of persons permitted to be carried is determined by the Administration and recorded on the SCV Safety Certificate.'),
  ('bm3:M02-019', 'BM-III', 2, null, 'Which of the following is part of a boatmaster''s basic security responsibilities on board?', '["Control who comes aboard and stay alert to unauthorised persons or suspicious activity","Allow anyone aboard at any time to keep the operation friendly","Leave the vessel unattended and unlocked between trips","Treat security as not applicable to small commercial vessels"]'::jsonb, 0, 'Answer A. B9.4 basic security: as part of legal responsibilities the boatmaster controls access to the vessel and stays alert to unauthorised access or suspicious activity.'),
  ('bm3:M03-001', 'BM-III', 3, null, 'In a written position, which coordinate is given first and what letters can it carry?', '["Latitude first, labelled N or S","Longitude first, labelled E or W","Latitude first, labelled E or W","Longitude first, labelled N or S"]'::jsonb, 0, 'Answer A. Latitude (distance N or S of the equator) is always written first, followed by longitude (E or W). SCV Code 2021 · Caribbean Netherlands Page 7 / 40'),
  ('bm3:M03-002', 'BM-III', 3, 'A1.8', 'What does longitude measure?', '["The depth of water below chart datum","Distance east or west of the Greenwich (prime) meridian","Distance north or south of the equator","The height of land above sea level"]'::jsonb, 1, 'Answer B. Longitude is the distance east or west of the Greenwich (prime) meridian, labelled E or W.'),
  ('bm3:M03-003', 'BM-III', 3, 'A1.8', 'Why is distance on a chart measured up the side rather than along the top?', '["Because the side scale is printed larger","Because the top edge is distorted by the chart projection","Because one minute of latitude equals one nautical mile","Because one minute of longitude equals one nautical mile"]'::jsonb, 2, 'Answer C. One minute of latitude equals one nautical mile, so distance is read off the latitude scale up the side.'),
  ('bm3:M03-004', 'BM-III', 3, 'A1.8', 'On the compass card, which direction corresponds to a bearing of 270°?', '["North","East","South","West"]'::jsonb, 3, 'Answer D. Directions increase clockwise from north: N 000°, E 090°, S 180°, W 270°.'),
  ('bm3:M03-005', 'BM-III', 3, 'A1.8', 'What is the compass bearing of due East?', '["090°","045°","135°","180°"]'::jsonb, 0, 'Answer A. East is 090° on the 360° compass card, increasing clockwise from north at 000°.'),
  ('bm3:M03-006', 'BM-III', 3, 'A1.8', 'Your vessel is steering a heading of 045°. In which direction is she travelling?', '["North-west","North-east","South-east","South-west"]'::jsonb, 1, 'Answer B. 045° is the intercardinal point north-east, midway between north (000°) and east (090°).'),
  ('bm3:M03-007', 'BM-III', 3, null, 'Why should a course or bearing always be expressed as three figures, such as 005°?', '["Because charts only accept three-figure entries","Because the compass card has exactly three rings","To avoid confusion between, for example, 5° and 50°","To convert degrees into nautical miles"]'::jsonb, 2, 'Answer C. Three figures (005°, 045°, 180°) prevent confusion between similar single- and double-digit values. SCV Code 2021 · Caribbean Netherlands Page 8 / 40'),
  ('bm3:M03-008', 'BM-III', 3, 'A1.8', 'What is the difference between a heading and a bearing?', '["A heading is where the boat is pointing; a bearing is the direction to an object","A heading is the direction to an object; a bearing is where the boat is pointing","A heading is measured in miles; a bearing is measured in degrees","They are two words for exactly the same thing"]'::jsonb, 0, 'Answer A. A heading (course) is where the boat is pointing; a bearing is the direction to an object.'),
  ('bm3:M03-009', 'BM-III', 3, 'A1.8', 'You take rough bearings of three charted landmarks and draw each on the chart. What does the point where they cross give you?', '["Your speed over the ground","The tidal set and drift","A simple position fix","The depth of water beneath you"]'::jsonb, 2, 'Answer C. Two or three crossed rough bearings of charted objects give a simple position fix.'),
  ('bm3:M03-010', 'BM-III', 3, 'B5.1', 'On a nautical chart, what does a small number (a sounding) tell you?', '["The distance to the nearest buoy","The height of a lighthouse","The charted depth of water at that spot","The compass bearing to a landmark"]'::jsonb, 2, 'Answer C. Soundings are charted depths of water in metres below chart datum, not distances.'),
  ('bm3:M03-011', 'BM-III', 3, 'B5.1', 'What does an underlined number (a drying height) on a chart indicate?', '["A height that uncovers at low water — a hazard","A safe deep-water channel","A recommended anchorage","The range of a nearby light"]'::jsonb, 0, 'Answer A. An underlined number is a drying height that uncovers at low water and is a hazard.'),
  ('bm3:M03-012', 'BM-III', 3, 'B5.1', 'On a chart the bottom abbreviation ''S'' tells the skipper the nature of the seabed is which of the following?', '["Stone","Sand","Shoal","Swell"]'::jsonb, 1, 'Answer B. Nature-of-bottom abbreviations include S (sand), M (mud), R (rock) and Co (coral).'),
  ('bm3:M03-013', 'BM-III', 3, 'B10.1', 'On the Beaufort scale, which force is described as a gale?', '["Force 6","Force 7","Force 8","Force 10"]'::jsonb, 2, 'Answer C. Force 8 is a gale (34–40 knots); a Grade III skipper stays in port well before then. SCV Code 2021 · Caribbean Netherlands Page 9 / 40'),
  ('bm3:M03-014', 'BM-III', 3, null, 'A hurricane on the Beaufort scale is force 12. From what wind speed does it begin?', '["34 knots and over","48 knots and over","56 knots and over","64 knots and over"]'::jsonb, 3, 'Answer D. Force 12 (hurricane) is 64 knots and over on the Beaufort scale.'),
  ('bm3:M03-015', 'BM-III', 3, 'B10.1', 'Which VHF channel should you keep a listening watch on for coastguard safety announcements and weather warnings?', '["Channel 6","Channel 16","Channel 12","Channel 72"]'::jsonb, 1, 'Answer B. VHF Channel 16 carries coastguard safety announcements and weather warnings; broadcasts then move to a working channel.'),
  ('bm3:M03-016', 'BM-III', 3, null, 'A marine bulletin states winds ''easterly, force 3 to 4, gusting force 5 in showers'' and seas ''slight to moderate, 0.5 to 1.5 m''. Which four things should you pull out for your trip?', '["Barometric pressure, tide times, moon phase and sunrise","Water temperature, salinity, current and chart datum","Wind direction and force, visibility, wave height, and any warning of change later","Engine load, fuel state, crew number and ETA"]'::jsonb, 2, 'Answer C. From a bulletin pull the wind (direction and force), visibility, wave height, and any warning of change later.'),
  ('bm3:M03-017', 'BM-III', 3, 'B10.2', 'An anchorage on a lee shore is calm in trade-wind weather, but the bulletin warns of a northerly swell. Why is this a concern?', '["The trade wind will drop to a flat calm","Swell only affects vessels under power, not at anchor","Swell raises the water temperature and fouls the engine intake","Northerly swell can break heavily on lee shores even when local wind is light, making the anchorage untenable ✓"]'::jsonb, 0, 'Answer D. Northerly swell from distant systems can break heavily on lee shores even in light wind, so have an alternative anchorage ready.'),
  ('bm3:M03-018', 'BM-III', 3, 'B10.3', 'You notice the barometer falling steadily, towering cumulonimbus building, and the wind beginning to shift and freshen. What does this classic combination indicate?', '["Settled fair weather is on the way","Bad weather is approaching — head for shelter early","A land breeze setting in for the night","Nothing of concern in the tropics"]'::jsonb, 1, 'Answer B. Falling pressure, building cumulonimbus and a shifting, freshening wind warn of approaching bad weather — seek shelter early. SCV Code 2021 · Caribbean Netherlands Page 10 / 40'),
  ('bm3:M04-001', 'BM-III', 4, 'B2.1', 'Which part of the COLREGs covers General matters such as application, responsibility and definitions?', '["Part A (Rules 1–3)","Part B (Rules 4–19)","Part C (Rules 20–31)","Part D (Rules 32–37)"]'::jsonb, 0, 'Answer A. Part A — General covers application, responsibility and definitions in Rules 1–3.'),
  ('bm3:M04-002', 'BM-III', 4, 'B7.1 / Annex IV', 'Which of the following is a recognised distress signal under Annex IV?', '["A single green flare","A white all-round light flashing twice","A black ball hoisted at the masthead","A red rocket or red hand flare, or an orange smoke signal"]'::jsonb, 3, 'Answer D. Annex IV distress signals include red rockets or hand flares and an orange smoke signal.'),
  ('bm3:M04-003', 'BM-III', 4, 'B7.1', 'Which Annex of the COLREGs contains the distress signals?', '["Annex I","Annex II","Annex III","Annex IV"]'::jsonb, 3, 'Answer D. Annex IV contains the distress signals; Annexes I–III cover lights/shapes, fishing signals and sound appliances.'),
  ('bm3:M04-004', 'BM-III', 4, null, 'Which spoken word, transmitted by radio, is a distress signal under Annex IV?', '["MAYDAY","PAN-PAN","SECURITE","ROGER"]'::jsonb, 0, 'Answer A. Annex IV lists the spoken word MAYDAY by radio, and SOS by any signalling method, as distress signals.'),
  ('bm3:M04-005', 'BM-III', 4, 'B2.3 / Rule 5', 'What does Rule 5 require of every vessel?', '["To carry radar at all times","To sound a fog signal every two minutes","To maintain a proper look-out by sight and hearing and by all available means at all times","To keep to the starboard side of any channel"]'::jsonb, 2, 'Answer C. Rule 5 requires a proper look-out by sight and hearing, and by all available means, at all times. SCV Code 2021 · Caribbean Netherlands Page 11 / 40'),
  ('bm3:M04-006', 'BM-III', 4, 'B2.3 / Rule 5', 'While conning your small craft you are tempted to keep your eyes on the chartplotter and your phone. What does Rule 5 require instead?', '["Use your eyes and ears first and do not let devices distract the person conning the boat","Rely on the chartplotter, which counts as a proper look-out","Post the look-out only when other vessels are visible","Keep a look-out only after dark or in fog"]'::jsonb, 0, 'Answer A. Rule 5: a proper look-out uses sight and hearing first; chartplotters and phones must not distract the conning skipper.'),
  ('bm3:M04-007', 'BM-III', 4, 'Rule 6', 'Which of the following is a factor a skipper must weigh in deciding a safe speed under Rule 6?', '["The colour of the other vessel''s hull","The nationality of the other vessel","The visibility at the time","The price of fuel"]'::jsonb, 2, 'Answer C. Rule 6 safe-speed factors include visibility, traffic density, wind/sea/current, navigational hazards and draft.'),
  ('bm3:M04-008', 'BM-III', 4, 'Rule 6', 'You are entering an area of fog, heavy traffic and shoals, with little depth under your keel. What does Rule 6 require?', '["Maintain full cruising speed to clear the area quickly","Proceed at a safe speed so you can take proper action and stop within an appropriate distance","Stop the engine and drift until the fog lifts","Increase speed to improve steerage"]'::jsonb, 1, 'Answer B. Rule 6 requires a safe speed — judged by visibility, traffic, hazards and draft — allowing effective action and stopping in time.'),
  ('bm3:M04-009', 'BM-III', 4, null, 'Under Rule 7, what is the key test when you are unsure whether risk of collision exists?', '["Assume no risk exists until you can prove otherwise","Wait for the other vessel to signal her intentions","If there is any doubt, assume that risk of collision exists and act accordingly","Increase speed to pass ahead before risk develops"]'::jsonb, 2, 'Answer C. Rule 7: if there is any doubt, risk of collision is deemed to exist and you must act accordingly.'),
  ('bm3:M04-010', 'BM-III', 4, 'Rule 7', 'An approaching vessel is getting steadily closer but its compass bearing is not changing. What does this tell you under Rule 7?', '["There is no risk because the bearing is steady","The other vessel will alter course in good time","You have right of way and need take no action","Risk of collision is present"]'::jsonb, 3, 'Answer D. Rule 7: a steady compass bearing of an approaching vessel that is closing means risk of collision exists. SCV Code 2021 · Caribbean Netherlands Page 12 / 40'),
  ('bm3:M04-011', 'BM-III', 4, null, 'Under Rule 8, an alteration of course to avoid collision should be which of the following?', '["Late, small and gradual","Early, substantial and obvious","Made only after the other vessel acts first","A series of small changes to keep options open"]'::jsonb, 1, 'Answer B. Rule 8 requires action that is positive, made in good time and seamanlike — early, substantial and obvious.'),
  ('bm3:M04-012', 'BM-III', 4, 'Rule 9', 'In a narrow channel, to which side should a vessel keep as far as is safe?', '["The port side","The centre of the channel","The starboard side","Whichever side has deepest water"]'::jsonb, 2, 'Answer C. Rule 9 requires a vessel in a narrow channel to keep to the starboard side as far as is safe.'),
  ('bm3:M04-013', 'BM-III', 4, 'Rule 9', 'You are skippering an 8 m power boat in a narrow channel where a large ship can only stay safe within the channel. What does Rule 9 require of you?', '["Insist on your right of way and hold your course","Not impede the large vessel, since you are under 20 m","Anchor in the middle of the channel and wait","Cross ahead of the large vessel as quickly as possible"]'::jsonb, 1, 'Answer B. Rule 9: a vessel under 20 m, or a sailing vessel, shall not impede a vessel that can only navigate safely within the channel.'),
  ('bm3:M04-014', 'BM-III', 4, 'Rule 12', 'When two sailing vessels have the wind on different sides, which one keeps out of the way?', '["The vessel with the wind on the starboard side","The vessel with the wind on the port side","The larger vessel","The vessel to leeward"]'::jsonb, 1, 'Answer B. Rule 12: with the wind on different sides, the vessel with the wind on the port side keeps out of the way.'),
  ('bm3:M04-015', 'BM-III', 4, null, 'Two sailing vessels have the wind on the same side. Which one must keep clear?', '["The vessel to leeward keeps clear of the one to windward","Neither — they pass freely","The vessel to windward keeps clear of the one to leeward","The faster of the two keeps clear"]'::jsonb, 2, 'Answer C. Rule 12: with the wind on the same side, the windward vessel keeps clear of the leeward vessel. SCV Code 2021 · Caribbean Netherlands Page 13 / 40'),
  ('bm3:M04-016', 'BM-III', 4, 'Rule 13', 'Until what point does an overtaking vessel remain the give-way vessel?', '["Until she draws level with the other vessel","Until the other vessel sounds a signal","Until she is finally past and clear","Until she has overtaken by one boat length"]'::jsonb, 2, 'Answer C. Rule 13: the overtaking vessel keeps out of the way and stays give-way until finally past and clear.'),
  ('bm3:M04-017', 'BM-III', 4, null, 'Your sailing vessel is overtaking a slower power-driven vessel. Who must keep clear?', '["Your sailing vessel, because the overtaking vessel always keeps clear","The power-driven vessel, because power gives way to sail","Neither, because they are different vessel types","Whichever vessel is the smaller"]'::jsonb, 0, 'Answer A. Rule 13 outranks other situations: even a sailing vessel overtaking a power-driven vessel must keep clear.'),
  ('bm3:M04-018', 'BM-III', 4, null, 'When two power-driven vessels meet head-on with risk of collision, what must each do?', '["Each alter course to port and pass starboard to starboard","Each alter course to starboard and pass port to port","The smaller vessel gives way to the larger","Each hold course and sound one short blast"]'::jsonb, 1, 'Answer B. Rule 14: each power-driven vessel alters course to starboard so they pass port to port.'),
  ('bm3:M04-019', 'BM-III', 4, 'Rule 14', 'At night you see another power-driven vessel''s masthead lights in line and both her sidelights, almost dead ahead. What action does Rule 14 require?', '["Hold your course and let her decide","Alter course to port and pass starboard to starboard","Stop and reverse engines","Alter course to starboard so you pass port to port"]'::jsonb, 3, 'Answer D. Rule 14: in a head-on situation alter to starboard and pass port to port; if in doubt, assume it is head-on.'),
  ('bm3:M04-020', 'BM-III', 4, null, 'In a crossing situation between two power-driven vessels, which vessel must give way?', '["The vessel which has the other on her own port side","The vessel which has the other on her own starboard side","The larger of the two vessels","The faster of the two vessels"]'::jsonb, 1, 'Answer B. Rule 15: the vessel which has the other on her starboard side keeps out of the way. SCV Code 2021 · Caribbean Netherlands Page 14 / 40'),
  ('bm3:M04-021', 'BM-III', 4, 'Rule 15', 'You are in a power-driven vessel and another power-driven vessel is crossing from your starboard side. What should you do?', '["Stand on and hold your course and speed","Cross ahead of her quickly","Give way — alter to starboard and pass astern of her","Alter to port and pass ahead of her"]'::jsonb, 2, 'Answer C. Rule 15: with the other vessel on your starboard side you are give-way — alter to starboard and pass astern.'),
  ('bm3:M04-022', 'BM-III', 4, 'Rule 17', 'You are the stand-on vessel, but it has become clear the give-way vessel is taking no action and collision is now imminent. What does Rule 17 permit and require?', '["You may act once it is clear the other is not acting, and you must act if collision cannot be avoided by her alone ✓","You must continue to stand on regardless","You must immediately turn to port","You have no authority to alter course as the stand-on vessel"]'::jsonb, 0, 'Answer A. Rule 17: the stand-on vessel may act when the give-way vessel is clearly not acting and must act if she alone cannot avoid collision.'),
  ('bm3:M04-023', 'BM-III', 4, 'Rule 18', 'In the Rule 18 ''pecking order'', which vessel keeps clear of all the others?', '["A vessel not under command","A vessel restricted in her ability to manoeuvre","A sailing vessel","A power-driven vessel"]'::jsonb, 3, 'Answer D. Rule 18 order (top to bottom): NUC, RAM, fishing, sailing, power — a power-driven vessel keeps clear of the rest.'),
  ('bm3:M04-024', 'BM-III', 4, 'Rule 18', 'You are skippering a power-driven vessel and a sailing vessel and a fishing vessel are both nearby with risk of collision. Under Rule 18, who keeps clear?', '["Your power-driven vessel keeps clear of both","The fishing vessel, because she is working","The sailing vessel, because she has no engine","Whichever vessel is largest"]'::jsonb, 0, 'Answer A. Rule 18: a power-driven vessel sits at the bottom of the order and keeps clear of fishing and sailing vessels.'),
  ('bm3:M04-025', 'BM-III', 4, 'Part C', 'What colour are the sidelights of a vessel underway?', '["Green to port and red to starboard","White both sides","Green to starboard and red to port","Red both sides"]'::jsonb, 2, 'Answer C. Sidelights are green to starboard and red to port. SCV Code 2021 · Caribbean Netherlands Page 15 / 40'),
  ('bm3:M04-026', 'BM-III', 4, 'Part C', 'By day you see a vessel showing three black balls in a vertical line. What does this tell you?', '["She is at anchor","She is engaged in fishing","She is aground","She is restricted in her ability to manoeuvre"]'::jsonb, 2, 'Answer C. A vessel aground shows two all-round red lights at night and three black balls by day.'),
  ('bm3:M05-001', 'BM-III', 5, 'B4.1', 'What does the term ''starboard'' refer to?', '["The right-hand side of the vessel when looking forward","The left-hand side of the vessel when looking forward","The forward end of the vessel","The widest part of the vessel"]'::jsonb, 0, 'Answer A. Starboard is the right-hand side looking forward, marked by a green light (Module 05, nautical terms).'),
  ('bm3:M05-002', 'BM-III', 5, null, 'Which term describes the vertical distance from the waterline up to the deck edge?', '["Draft","Air draft","Beam","Freeboard"]'::jsonb, 3, 'Answer D. Freeboard is the vertical distance from the waterline to the deck edge (Module 05, ship dimensions).'),
  ('bm3:M05-003', 'BM-III', 5, 'B4.1', 'What is meant by the ''draft'' of a vessel?', '["The greatest width of the hull","The full extreme length from bow to stern","The vertical distance from the waterline to the lowest point of the hull","The height of the highest fixed point above the waterline"]'::jsonb, 2, 'Answer C. Draft is the vertical distance from the waterline to the lowest point of the hull, governing minimum safe water depth (Module 05).'),
  ('bm3:M05-004', 'BM-III', 5, 'B4.1', 'You plan to pass beneath a fixed bridge. Which of the vessel''s dimensions tells you whether you can safely pass under it?', '["Air draft","Draft","Beam","Freeboard"]'::jsonb, 0, 'Answer A. Air draft — the height of the highest fixed point above the waterline — governs whether you can pass under a bridge or cable (Module 05). SCV Code 2021 · Caribbean Netherlands Page 16 / 40'),
  ('bm3:M05-005', 'BM-III', 5, 'B4.1', 'Which vessel type is described as carrying liquefied gases (LPG/LNG) under pressure and/or refrigerated?', '["Chemical tanker","Bulk carrier","Oil tanker","Gas tanker"]'::jsonb, 3, 'Answer D. A gas tanker carries liquefied gases such as LPG/LNG under pressure and/or refrigerated (Module 05, vessel types).'),
  ('bm3:M05-006', 'BM-III', 5, 'B4.1', 'A bulk carrier is designed to carry which kind of cargo?', '["Standardised containers stacked on deck and in holds","Dry bulk cargo such as ore, grain and coal in large holds","Liquid chemicals in segregated coated tanks","Vehicles on multiple internal decks"]'::jsonb, 1, 'Answer B. A bulk carrier carries dry bulk cargo (ore, grain, coal) in large holds (Module 05, vessel types).'),
  ('bm3:M05-007', 'BM-III', 5, 'Reserve buoyancy', 'What is ''reserve buoyancy''?', '["The weight of water a vessel displaces when floating","The watertight volume of the hull above the waterline","The total weight of cargo a vessel can carry","The depth of water below the keel"]'::jsonb, 1, 'Answer B. Reserve buoyancy is the watertight hull volume above the waterline, which lifts the vessel over waves and keeps it afloat if water comes aboard (Module 05).'),
  ('bm3:M05-008', 'BM-III', 5, 'Reserve buoyancy', 'As a vessel is progressively loaded with more weight, what happens to its freeboard and reserve buoyancy?', '["Freeboard increases and reserve buoyancy increases","Freeboard stays the same but reserve buoyancy increases","Both freeboard and reserve buoyancy reduce","Freeboard reduces but reserve buoyancy increases"]'::jsonb, 2, 'Answer C. As a vessel is loaded it sits deeper, freeboard reduces, and reserve buoyancy reduces with it (Module 05).'),
  ('bm3:M05-009', 'BM-III', 5, 'B17.16', 'For any vessel, the maximum load capacity is calculated from which factor?', '["The maximum permitted air draft","The greatest beam of the hull","The number of lifejackets carried","The minimum permitted freeboard"]'::jsonb, 3, 'Answer D. Maximum load capacity is calculated from the minimum permitted freeboard; at that freeboard no more weight may be added (Module 05, B17.16). SCV Code 2021 · Caribbean Netherlands Page 17 / 40'),
  ('bm3:M05-010', 'BM-III', 5, 'B17.16', 'The maximum number of persons on board is set by three things together. Which combination is correct?', '["Freeboard, stability and available life-saving appliances","Length, beam and air draft","Engine power, fuel capacity and range","Draft, displacement and cargo weight"]'::jsonb, 0, 'Answer A. Maximum persons is governed by freeboard (reserve buoyancy), stability and the available life-saving appliances, whichever gives the lowest figure (Module 05).'),
  ('bm3:M05-011', 'BM-III', 5, 'Loss of buoyancy', 'Which measure helps prevent loss of buoyancy through hull-penetrating piping below the waterline?', '["Fitting a valve at the hull so the pipe can be shut off if it fails","Painting the pipe with anti-fouling","Increasing the vessel''s freeboard","Carrying a spare bilge pump"]'::jsonb, 0, 'Answer A. Hull-penetrating piping below the waterline must have a valve at the hull so it can be shut off if it fails (Module 05).'),
  ('bm3:M05-012', 'BM-III', 5, 'A1.9', 'Which VHF channel is the international distress, safety and calling channel?', '["Channel 11","Channel 12","Channel 16","Channel 14"]'::jsonb, 2, 'Answer C. Channel 16 is the international distress, safety and calling channel (Module 05, VHF communications).'),
  ('bm3:M05-013', 'BM-III', 5, 'A1.9', 'Your vessel is taking on water and is in grave and imminent danger of sinking with people aboard. Which spoken priority word should you use on VHF?', '["SECURITE","PAN-PAN","MAYDAY","ROGER"]'::jsonb, 2, 'Answer C. MAYDAY signals distress — grave and imminent danger to a vessel or person — and has the highest priority (Module 05).'),
  ('bm3:M05-014', 'BM-III', 5, 'A1.9', 'You are approaching Bonaire and need to call Port Control on its working channel. After calling on Ch 16, which working channel does Bonaire Port Control use?', '["Channel 11","Channel 12","Channel 14","Channel 10"]'::jsonb, 0, 'Answer A. Bonaire Port Control uses channels 16 and 11; Ch 11 is the working channel (Module 05, VHF channel overview). SCV Code 2021 · Caribbean Netherlands Page 18 / 40'),
  ('bm3:M06-001', 'BM-III', 6, 'A1', 'What does the ''neutral (free)'' position of the gearbox do?', '["The propeller drives the vessel forward","The propeller drives the vessel backwards","The shaft is disconnected so the propeller does not drive","The engine is switched off"]'::jsonb, 2, 'Answer C. In neutral (free) the shaft is disconnected; the engine runs but the propeller does not drive (Module 06, gearbox).'),
  ('bm3:M06-002', 'BM-III', 6, 'A1', 'When changing between ahead and astern, why should you pause in neutral?', '["To allow the propeller to change direction by itself","To avoid shock-loading the gearbox","To increase the transverse thrust effect","To cool the engine before reversing"]'::jsonb, 1, 'Answer B. Move the control firmly but smoothly and pause in neutral when changing between ahead and astern to avoid shock-loading the gearbox (Module 06).'),
  ('bm3:M06-003', 'BM-III', 6, 'A1', 'For a right-handed propeller going ahead, which way does the stern walk?', '["To starboard","To port","Straight aft, with no sideways effect","Towards the wind"]'::jsonb, 0, 'Answer A. For a right-handed (clockwise) propeller going ahead, the stern walks to starboard and the bow swings to port (Module 06).'),
  ('bm3:M06-004', 'BM-III', 6, 'A1', 'For a right-handed propeller going astern, which way does the stern walk?', '["To port","To starboard","It does not move sideways","Always to leeward"]'::jsonb, 0, 'Answer A. For a right-handed propeller going astern, the stern walks to port (the bow swings to starboard) (Module 06).'),
  ('bm3:M06-005', 'BM-III', 6, 'A1', 'Your boat has a right-handed propeller and you wish to use the astern ''kick'' to draw the stern neatly in to the quay. Which berth should you approach?', '["A starboard-side berth","Either berth gives the same effect","A port-side berth","A berth directly downwind"]'::jsonb, 2, 'Answer C. Going astern the stern walks to port, so approaching a port-side berth lets the astern kick pull the stern in to the quay (Module 06). SCV Code 2021 · Caribbean Netherlands Page 19 / 40'),
  ('bm3:M06-006', 'BM-III', 6, 'B4.2', 'Two vessels are about to pass in a narrow channel. About a ship''s length apart, which way should both vessels initially alter?', '["Both alter to port","Both alter to starboard","Both hold the centre-line","The smaller vessel alters, the larger holds course"]'::jsonb, 1, 'Answer B. About a ship''s length apart both vessels alter to starboard (helm well over), then ease the rudder (Module 06, interaction procedure).'),
  ('bm3:M06-007', 'BM-III', 6, 'B4.2', 'What is the single best defence against dangerous interaction forces between passing vessels in a narrow or shallow channel?', '["Increase speed to pass quickly","Steer hard to port throughout","Slow down, since suction and cushion effects are small at low speed","Pass as close as possible to the bank"]'::jsonb, 2, 'Answer C. Interaction forces grow rapidly with speed and in shallow water; slowing down keeps the effects small and controllable (Module 06).'),
  ('bm3:M06-008', 'BM-III', 6, 'B4.3', 'A vessel with a large exposed superstructure is manoeuvring slowly in a strong beam wind. What effect should you expect?', '["It will be pushed bodily to leeward, especially at low speed","It will be drawn towards the wind","Wind has no effect below planing speed","It will only be affected if the engine is in neutral"]'::jsonb, 0, 'Answer A. High windage hulls are pushed bodily to leeward, especially at low speed when little water flows over the rudder to resist it (Module 06).'),
  ('bm3:M06-009', 'BM-III', 6, 'B4.3', 'What is Under-Keel Clearance (UKC)?', '["The distance from the waterline to the deck edge","The clearance between the propeller and the rudder","The water between the keel and the seabed","The depth of water needed to launch the anchor"]'::jsonb, 2, 'Answer C. UKC is the water between your keel and the seabed and must stay positive with a safe margin (Module 06).'),
  ('bm3:M06-010', 'BM-III', 6, 'B4.6', 'You are about to pass a row of berthed yachts at close distance. What is the correct action regarding your wash?', '["Maintain speed; wash is the other vessels'' concern","Ease back well before you reach them to limit your wash","Increase speed to clear the area quickly","Slow down only once you are level with them"]'::jsonb, 1, 'Answer B. You are responsible for damage your wash causes; ease back well before the hazard, not as you pass it (Module 06). SCV Code 2021 · Caribbean Netherlands Page 20 / 40'),
  ('bm3:M06-011', 'BM-III', 6, 'B4.4 / Annex 7', 'Under SCV Annex 7, what is the general minimum length of anchor line relative to a vessel that is 8 metres long overall?', '["Not less than 32 metres (4 x LOA)","Not less than 24 metres (3 x LOA)","Not less than 16 metres (2 x LOA)","Not less than 8 metres (1 x LOA)"]'::jsonb, 0, 'Answer A. SCV Annex 7: anchor line shall generally be not less than 4 times the vessel''s length overall, so 4 x 8 m = 32 m (Module 06).'),
  ('bm3:M06-012', 'BM-III', 6, 'B4.5', 'Why does adequate scope help an anchor hold?', '["It makes the pull on the anchor more vertical so it digs deeper","It makes the pull on the anchor more horizontal so it digs in","It adds weight to the anchor","It keeps the chain piled on top of the anchor"]'::jsonb, 1, 'Answer B. Adequate scope makes the pull more horizontal so the anchor digs in and holds; too little scope lifts the shank and the anchor drags (Module 06).'),
  ('bm3:M06-013', 'BM-III', 6, 'B4.8', 'Why is a polyamide (nylon) towline preferred for towing astern?', '["It floats so it cannot foul the propeller","It is cheaper than other ropes","It does not chafe at fairleads","It stretches and absorbs shock as the vessels surge"]'::jsonb, 3, 'Answer D. A polyamide (nylon) towline stretches and absorbs shock as the two vessels surge, instead of snatching (Module 06, towing).'),
  ('bm3:M06-014', 'BM-III', 6, 'B4.8', 'While towing, a beam pull from the tow threatens to roll the towing vessel over. What is this hazard called, and what control should you have ready?', '["Snap-back; keep clear of the line''s path","Chafe; protect the line at fairleads","Girting; keep the pull astern and have a means to slip the tow instantly","Squat; reduce draft by removing weight"]'::jsonb, 2, 'Answer C. Girting is a beam pull that can capsize the towing vessel; keep the pull astern and have a means to slip the tow instantly (Module 06, towing hazards).'),
  ('bm3:M06-015', 'BM-III', 6, 'A1.6', 'You must turn your boat right round in a space little longer than the boat itself. What is the correct technique?', '["Hold full ahead with the rudder hard over until she comes round","Go full astern with the rudder amidships","Alternate short bursts ahead (rudder hard over) with bursts astern, letting transverse thrust walk the stern and spin the boat in nearly its own length ✓","Drift with the wind and let the bow blow round"]'::jsonb, 0, 'Answer C. A1.6 turning short round: alternate ahead (rudder hard over) and astern bursts; the propeller''s transverse thrust walks the stern so the boat spins in almost its own length. SCV Code 2021 · Caribbean Netherlands Page 21 / 40'),
  ('bm3:M07-001', 'BM-III', 7, 'B11.2', 'What is the defining feature of planned (preventive) maintenance?', '["It is work carried out on a schedule before anything goes wrong","It is the repair made after a component has already failed","It is work carried out only when an inspector requires it","It is work that can only be done by a qualified marine engineer"]'::jsonb, 0, 'Answer A. Planned (preventive) maintenance is scheduled work done before failure, unlike corrective maintenance which repairs after a failure.'),
  ('bm3:M07-002', 'BM-III', 7, 'B11.2', 'Your engine has no running-hours clock fitted. How do you know when each service is due?', '["Service it only when the exhaust changes colour","Keep a logbook of the hours run so you can track service intervals","Service it on a fixed calendar date regardless of use","Wait for the manufacturer to contact you"]'::jsonb, 1, 'Answer B. With no running-hours clock you keep a logbook of hours run so you know when each scheduled service is due.'),
  ('bm3:M07-003', 'BM-III', 7, 'B11.2', 'How is a 2-stroke outboard engine lubricated?', '["From the crankcase / sump","By keel-cooling pipes outside the hull","By mixed (manual) lubrication — oil mixed into the fuel","By a sealed maintenance-free reservoir"]'::jsonb, 2, 'Answer C. The 2-stroke outboard uses mixed (manual) lubrication with oil mixed into the fuel; a 4-stroke is lubricated from the crankcase/sump.'),
  ('bm3:M07-004', 'BM-III', 7, 'B11.2', 'Where does a 4-stroke outboard engine take its lubrication from?', '["Oil mixed into the fuel","The crankcase / sump","The raw-water cooling circuit","The fuel water separator"]'::jsonb, 1, 'Answer B. A 4-stroke outboard is lubricated from the crankcase/sump, whereas a 2-stroke uses mixed (manual) lubrication.'),
  ('bm3:M07-005', 'BM-III', 7, 'B11.2', 'Which cooling arrangement draws seawater in through a hull fitting and requires a strainer to be checked and cleaned?', '["Keel cooling","Air cooling","Hybrid cooling","Raw-water (seawater) cooling"]'::jsonb, 3, 'Answer D. Raw-water cooling draws seawater past a raw-water strainer that traps weed and debris and must be checked and cleaned. SCV Code 2021 · Caribbean Netherlands Page 22 / 40'),
  ('bm3:M07-006', 'BM-III', 7, 'B11.2', 'Your vessel uses keel cooling. Why is there no raw-water strainer to clean on this system?', '["Because the engine coolant circulates through pipes in contact with the sea, so no seawater is drawn into the engine ✓","Because keel cooling uses air rather than any liquid","Because the strainer is fitted inside the gearbox instead","Because keel cooling relies on the exhaust gases for cooling"]'::jsonb, 0, 'Answer A. Keel cooling circulates engine coolant through pipes in contact with the cold seawater outside the hull, so no seawater is drawn in and there is no raw-water strainer.'),
  ('bm3:M07-007', 'BM-III', 7, 'B11.2', 'What is the traditional seal where the propeller shaft passes out through the stern tube, and how should it behave?', '["A waterjet impeller that should never move","A Morse cable that should be kept slack","A stuffing box (gland) that should drip only very slightly","A keel cooler that should be fully watertight at all times"]'::jsonb, 2, 'Answer C. The traditional shaft seal is a greased stuffing box (gland) tightened by a grease press; it should drip only very slightly.'),
  ('bm3:M07-008', 'BM-III', 7, null, 'Which engine check gives an early warning of trouble through a change you can see?', '["The colour of the exhaust gas","The tightness of the battery clamps","The expiry date on the fire extinguisher","The acidity read by the hydrometer"]'::jsonb, 0, 'Answer A. A change in exhaust-gas colour is an early warning of engine trouble and is part of the running checks.'),
  ('bm3:M07-009', 'BM-III', 7, 'B11.1', 'What is checked with the dipstick during the daily engine checks?', '["The V-belt tension","The oil level","The exhaust-gas colour","The raw-water strainer"]'::jsonb, 1, 'Answer B. The dipstick is used to check the engine oil level as part of the daily checks.'),
  ('bm3:M07-010', 'BM-III', 7, 'B11.4', 'On the drive of a waterjet-propelled vessel, which component is checked in place of the propeller?', '["The stuffing box","The Morse cable","The impeller","The dipstick"]'::jsonb, 2, 'Answer C. On a waterjet you check the impeller, which pumps water through the nozzle, instead of an exposed propeller. SCV Code 2021 · Caribbean Netherlands Page 23 / 40'),
  ('bm3:M07-011', 'BM-III', 7, 'B11.3', 'Before sailing, how should you satisfy yourself that the emergency shut-off valves and battery isolator will work in a fire?', '["Assume they work because they are new","Wait until a fire occurs and then test them","Know where each one is and prove to yourself they work before you sail","Leave them to the annual inspector to confirm"]'::jsonb, 2, 'Answer C. You must be able to stop the engine and isolate the fuel in an emergency, so know where every shut-off valve and the isolator are and prove they work before you sail.'),
  ('bm3:M07-012', 'BM-III', 7, null, 'Which item on the safety check should have its expiry date checked frequently?', '["The fire extinguisher","The V-belt","The propeller shaft","The water separator"]'::jsonb, 0, 'Answer A. The fire extinguisher''s expiry date must be checked frequently as part of the safety checks.'),
  ('bm3:M07-013', 'BM-III', 7, 'B11.5', 'When something goes wrong with the engine, what should you use to find the likely cause and remedy?', '["Guess based on the engine sound","The troubleshooting section of the engine manual","The Garbage Record Book","The vessel''s certificate of registry"]'::jsonb, 1, 'Answer B. Use the troubleshooting (trouble-recovery) section of the engine manual, which lists symptoms, likely causes and remedies for that exact engine.'),
  ('bm3:M07-014', 'BM-III', 7, 'B11.5', 'You are preparing for a day''s commercial work and want to be able to carry out simple emergency repairs at sea. What three things must be aboard and checked before you leave the berth?', '["Spare fuel, spare crew and a spare propeller","The engine manual, the manufacturer''s recommended spares and the correct tools","A SOPEP, an oil boom and a Garbage Record Book","A hydrometer, Vaseline and a spare V-belt only"]'::jsonb, 1, 'Answer B. Emergency repairs depend on the engine manual for troubleshooting, the manufacturer''s recommended spares, and the correct tools — all checked before departure.'),
  ('bm3:M07-015', 'BM-III', 7, 'B11.1', 'In what unit is battery capacity measured?', '["Volts (V)","Watts (W)","Ampere-hours (Ah)","Parts per million (ppm)"]'::jsonb, 2, 'Answer C. Battery capacity is measured in ampere-hours (Ah). SCV Code 2021 · Caribbean Netherlands Page 24 / 40'),
  ('bm3:M07-016', 'BM-III', 7, null, 'What is the nominal voltage of a single lead-acid cell, and what is its electrolyte?', '["2 V, with a sulphuric-acid electrolyte","12 V, with a fresh-water electrolyte","6 V, with a sodium-hydroxide electrolyte","1 V, with a lithium-based electrolyte"]'::jsonb, 0, 'Answer A. Each lead-acid cell is 2 V and the electrolyte is a sulphuric-acid solution.'),
  ('bm3:M07-017', 'BM-III', 7, 'B11.1', 'Why must a charging lead-acid battery box be placed high, ventilated, and kept away from naked flames?', '["Because the battery becomes very heavy when charging","Because charging gives off an explosive gas","Because the electrolyte freezes if mounted low","Because the clamps loosen at high temperature"]'::jsonb, 1, 'Answer B. A charging lead-acid battery gives off explosive gas, so the box is placed high, ventilated, with no naked flames, smoking or sparks.'),
  ('bm3:M07-018', 'BM-III', 7, 'B11.2', 'A lead-acid battery on your vessel was left flat for a long period and has lost much of its capacity permanently. What most likely happened?', '["The fluid rose too far above the plates","It self-discharged at 1% per day until full again","The plates sulphated because it was discharged too deeply","The cell voltage rose above 2 V"]'::jsonb, 2, 'Answer C. If a lead-acid battery is discharged too deeply the plates sulphate, permanently reducing capacity.'),
  ('bm3:M08-001', 'BM-III', 8, 'B8.1 / VIII/8', 'When organising passenger embarkation across the ship-to-shore gap, which provision is required at the access point?', '["Steps for all passengers including wheelchair users","An open quayside with no shore personnel","Safety nets, rails and lifebuoys with a safety line","Loose chains and ropes coiled near the brow"]'::jsonb, 2, 'Answer C. The reader requires safety nets, rails and lifebuoys with a safety line fitted at the access point to provide safe means of access. SCV Code 2021 · Caribbean Netherlands Page 25 / 40'),
  ('bm3:M08-002', 'BM-III', 8, null, 'Why must the deck be kept clear of chains, ropes and loose gear during embarkation?', '["To improve the vessel''s appearance for tourists","To increase the deck cargo capacity","Because the SCV Code forbids any deck equipment","Because they are trip hazards for people boarding"]'::jsonb, 3, 'Answer D. The reader states chains, ropes and loose gear must be cleared because they are trip hazards during the accident-prone embarkation phase.'),
  ('bm3:M08-003', 'BM-III', 8, 'B8.3 / VIII/7', 'Which SCV Code regulation requires an accurate record or correct written count of all persons embarking and disembarking?', '["Regulation VIII/7","Regulation VIII/8","Regulation VIII/10","Regulation VIII/15"]'::jsonb, 0, 'Answer A. Regulation VIII/7 (Record of passengers) requires an accurate record or correct written count of all persons aboard.'),
  ('bm3:M08-004', 'BM-III', 8, 'B8.3 / VIII/7', 'Before a coastal day-trip departs, a deckhand asks why the named passenger count must be deposited ashore before leaving. What is the correct reason to give?', '["It satisfies the vessel''s insurance paperwork only","It is needed to calculate the fare per head","It tells rescuers in a search and rescue how many persons to look for","It records who has paid for the trip"]'::jsonb, 2, 'Answer C. VIII/7 matters because in a search and rescue the count tells rescuers how many persons to look for.'),
  ('bm3:M08-005', 'BM-III', 8, 'B8.1 / VIII/8', 'Which of the following must the VIII/8 passenger safety announcement cover before getting under way?', '["The vessel''s fuel consumption figures","The names of all crew members on duty","The scheduled return time to the berth","The method of putting on and adjusting lifejackets, including a demonstration"]'::jsonb, 3, 'Answer D. Regulation VIII/8 requires the announcement to cover the proper method of putting on and adjusting lifejackets, including a demonstration.'),
  ('bm3:M08-006', 'BM-III', 8, null, 'Under VIII/8.2, what alternative to a full public announcement may the operator use?', '["Skip the briefing entirely on short coastal trips","Display a single sign at the gangway only","Give each passenger, or place near each seat, a card or pamphlet plus an abbreviated announcement","Rely on passengers asking the crew if they have questions"]'::jsonb, 2, 'Answer C. VIII/8.2 allows a card or pamphlet for each passenger or seat, together with an abbreviated announcement. SCV Code 2021 · Caribbean Netherlands Page 26 / 40'),
  ('bm3:M08-007', 'BM-III', 8, 'B8.1 / VIII/8.4', 'On a voyage of more than 12 hours, what additional action must passengers be requested to take during the safety orientation?', '["Sign a liability waiver and stow their luggage","Remain below decks for the duration of the orientation","Nominate a passenger leader for each section","Put on a lifejacket and go to the appropriate embarkation station"]'::jsonb, 3, 'Answer D. VIII/8.4 requires that on a voyage over 12 hours passengers put on a lifejacket and go to the appropriate embarkation station during the orientation.'),
  ('bm3:M08-008', 'BM-III', 8, 'B8.1 / VIII/8.5', 'Your vessel is about to transit a hazardous bar in worsening weather. Under VIII/8.5, what must the master require of passengers?', '["That they move to the bow for better visibility","That they stand to brace against the motion","That they wear lifejackets","That they remain on the open deck"]'::jsonb, 2, 'Answer C. VIII/8.5 requires passengers to wear lifejackets in hazardous conditions including transiting hazardous bars and inlets and severe weather.'),
  ('bm3:M08-009', 'BM-III', 8, 'B8.5 / VIII/8.5', 'Which of the following is a condition listed in the reader where passengers must wear lifejackets?', '["Calm water and clear daylight","Routine berthing alongside in harbour","Flooding, fire or other events that may call for evacuation","Passengers eating a meal on a sheltered deck"]'::jsonb, 2, 'Answer C. VIII/8.5 lists flooding, fire or other events which may call for evacuation among the hazardous conditions requiring lifejackets.'),
  ('bm3:M08-010', 'BM-III', 8, 'B8.2', 'On a small open Grade III boat, passengers begin crowding to one side to look at a seal. To protect stability and trim, what should you do?', '["Allow it, as passengers always know best where to sit","Speed up so the wash steadies the boat","Move all the crew to the opposite side to balance it permanently","Direct passengers to remain seated and evenly distributed"]'::jsonb, 3, 'Answer D. The reader requires passengers to remain seated and evenly distributed so the vessel stays in trim and stable.'),
  ('bm3:M08-011', 'BM-III', 8, 'B1.1', 'A passenger falls overboard from your open boat in daylight. What is the correct FIRST action?', '["Broadcast a distress message on VHF Channel 16","Keep visual contact with the person in the water","Sound the bilges and tanks","Prepare to launch the liferaft"]'::jsonb, 1, 'Answer B. The man-overboard action list begins with keeping visual contact with the person, then releasing the MOB buoy and sounding the alarm. SCV Code 2021 · Caribbean Netherlands Page 27 / 40'),
  ('bm3:M08-012', 'BM-III', 8, 'B1.4', 'Immediately after a collision, after sounding the general alarm, which action follows in the reader''s collision list?', '["Abandon ship at once","Beach the vessel without assessment","Manoeuvre the ship to minimise the effects of the collision","Shut down all electrical power"]'::jsonb, 2, 'Answer C. The collision list: sound the general alarm, then manoeuvre to minimise the effects, switch to VHF 16, muster passengers, sound bilges and tanks, broadcast.'),
  ('bm3:M08-013', 'BM-III', 8, null, 'In the stranding or grounding action list, which step is specific to that emergency?', '["Release the MOB buoy","Don lifejackets and abandon ship","Engage the emergency steering","Minimise the vessel''s draught"]'::jsonb, 3, 'Answer D. The grounding list includes minimising the vessel''s draught, alongside sounding the alarm, switching to VHF 16, mustering and sounding around the ship.'),
  ('bm3:M08-014', 'BM-III', 8, 'B1.7 / VIII/10', 'A fire is discovered aboard your passenger vessel. According to the reader''s fire action list, what is the correct FIRST action?', '["Determine the fire-attack plan","Sound the fire alarm","Position the ship for wind and smoke","Broadcast a distress call"]'::jsonb, 1, 'Answer B. The fire list begins with sounding the fire alarm, then informing the skipper and mustering with a head count.'),
  ('bm3:M08-015', 'BM-III', 8, 'B1.6', 'Water is entering the hull. After sounding the general alarm and sounding the bilges and tanks, what is the next step in the flooding list?', '["Identify where the water is coming in","Abandon ship immediately","Release the MOB buoy","Minimise the vessel''s draught"]'::jsonb, 0, 'Answer A. The flooding list continues with identifying where the water is coming in, then checking the bilge pump and determining the attack plan.'),
  ('bm3:M08-016', 'BM-III', 8, 'B1.4', 'In the abandon-ship action list, what comes immediately after broadcasting?', '["Marshal the liferafts together","Sound the bilges and tanks","Don lifejackets","Minimise the vessel''s draught"]'::jsonb, 2, 'Answer C. Abandon ship: broadcast, don lifejackets, prepare to launch, muster at embarkation stations, embark and launch, then marshal the rafts together. SCV Code 2021 · Caribbean Netherlands Page 28 / 40'),
  ('bm3:M08-017', 'BM-III', 8, 'B1.5', 'You may have to beach your vessel. Which of the following is one of the considerations the reader says you must weigh before committing?', '["The colour of the lifejackets aboard","The number of crew certificates held","The cost of repairs after beaching","The amount of surf, since high spray indicates rough surf"]'::jsonb, 3, 'Answer D. Beaching considerations include the seabed nature, amount of surf (high spray means rough surf), shelving, type of coastline and proximity of hazards.'),
  ('bm3:M08-018', 'BM-III', 8, null, 'Under Regulation VIII/15, how must escape hatches and emergency exits be marked?', '["\"EMERGENCY EXIT, KEEP CLEAR\"","\"KEEP CLOSED\" on both sides","With the vessel''s identity number only","\"NO ENTRY\" in red lettering"]'::jsonb, 0, 'Answer A. VIII/15 requires escape hatches and emergency exits to be marked "EMERGENCY EXIT, KEEP CLEAR"; watertight doors are marked "KEEP CLOSED".'),
  ('bm3:M08-019', 'BM-III', 8, null, 'In relation to lifejackets, what must the master be able to do for passengers?', '["Store the lifejackets out of reach to keep the deck clear","Issue lifejackets only once an emergency has begun","Assume passengers have used a lifejacket before","Demonstrate to passengers how to correctly put on and use the personal life-saving appliances"]'::jsonb, 3, 'Answer D. B8.5 (Reg VIII/8): the master must be able to demonstrate to passengers the correct donning and use of personal life-saving appliances as part of the safety briefing.'),
  ('bm3:M09-001', 'BM-III', 9, 'B13.1', 'Which disaster set in motion the chain of events leading to MARPOL?', '["The grounding and oil spill of the supertanker Torrey Canyon","The sinking of the Titanic","The Exxon Valdez running aground in Alaska","The capsize of the Herald of Free Enterprise"]'::jsonb, 0, 'Answer A. The Torrey Canyon ran aground in 1967 and spilled its oil cargo, essentially triggering the events leading to MARPOL.'),
  ('bm3:M09-002', 'BM-III', 9, 'B13.1', 'In which years was the MARPOL Convention adopted and brought into force?', '["Adopted 1967, in force 1970","Adopted 1973, in force 1983","Adopted 1983, in force 1990","Adopted 1990, in force 2000"]'::jsonb, 1, 'Answer B. MARPOL was adopted in 1973 and entered into force in 1983. SCV Code 2021 · Caribbean Netherlands Page 29 / 40'),
  ('bm3:M09-003', 'BM-III', 9, 'B13.1', 'Which type of pollution does MARPOL Annex I cover?', '["Garbage","Sewage","Oil","Air pollution"]'::jsonb, 2, 'Answer C. Annex I covers oil pollution from all ships, with Part B adding oil-tanker cargo rules.'),
  ('bm3:M09-004', 'BM-III', 9, 'B13.1', 'MARPOL Annex II covers the pollution caused by which substances?', '["Sewage from holding tanks","Packaged dangerous goods","Garbage and plastics","Noxious liquid substances carried by chemical tankers"]'::jsonb, 3, 'Answer D. Annex II covers noxious liquid substances carried by chemical tankers.'),
  ('bm3:M09-005', 'BM-III', 9, 'B13.1', 'Which MARPOL Annex deals with packaged (packed) dangerous goods?', '["Annex III","Annex IV","Annex V","Annex VI"]'::jsonb, 0, 'Answer A. Annex III covers packaged (packed) dangerous goods.'),
  ('bm3:M09-006', 'BM-III', 9, null, 'MARPOL Annex IV and Annex V cover which two kinds of pollution respectively?', '["Oil and air pollution","Sewage and garbage","Chemicals and packaged dangerous goods","Ballast water and anti-fouling"]'::jsonb, 1, 'Answer B. Annex IV covers sewage and Annex V covers garbage.'),
  ('bm3:M09-007', 'BM-III', 9, 'B13.1', 'Which kind of pollution is covered by MARPOL Annex VI?', '["Oil","Sewage","Garbage","Air pollution"]'::jsonb, 3, 'Answer D. Annex VI covers air pollution from ships.'),
  ('bm3:M09-008', 'BM-III', 9, 'B13.1', 'What is the purpose of the SOPEP (Shipboard Oil Pollution Emergency Plan)?', '["To set out what to do if there is any discharge of oil","To record how garbage was disposed of ashore","To list the safe stowage of packaged dangerous goods","To schedule the engine''s planned maintenance"]'::jsonb, 0, 'Answer A. The SOPEP sets out the immediate response and ship tasks to follow for any discharge of oil. SCV Code 2021 · Caribbean Netherlands Page 30 / 40'),
  ('bm3:M09-009', 'BM-III', 9, 'B13.1', 'You notice oil discharging from your vessel. According to the SOPEP immediate response, what should you do first?', '["Deploy the oil boom and begin ballasting","Report it / raise the alarm and stop the source","Continue the voyage and report it on arrival","Pump the oily water into the bilge for later disposal"]'::jsonb, 1, 'Answer B. The first SOPEP response to any oil discharge is to report it/raise the alarm and stop the source before it becomes a major incident.'),
  ('bm3:M09-010', 'BM-III', 9, 'B13.2', 'What is the rule on pumping oily water from the bilge overboard?', '["It is allowed at night when no other vessels are near","It is allowed once the oil has settled to the bottom","You must never pump oily water overboard","It is allowed provided it is more than 12 miles offshore"]'::jsonb, 2, 'Answer C. The bilge is not a place for oily water and you must never pump oily water overboard.'),
  ('bm3:M09-011', 'BM-III', 9, 'B13.2', 'You are about to change the engine''s lubricating oil at the berth. What precaution best prevents pollution?', '["Let any spills run into the bilge to be pumped out later","Tip the old oil over the side while moving slowly","Contain the old oil, catch every drip and keep it away from anything draining to the sea","Dilute the old oil with seawater before disposal"]'::jsonb, 2, 'Answer C. When changing lubricating oil you must contain the old oil, catch every drip and keep it well away from anything that drains to the sea.'),
  ('bm3:M09-012', 'BM-III', 9, 'B13.3', 'What does MARPOL say about discharging plastics — such as synthetic ropes, plastic sheeting and garbage bags — into the sea?', '["It is permitted beyond 25 miles from land","The discharge of all plastics into the sea is prohibited","It is permitted if the plastic is biodegradable","It is permitted in small quantities"]'::jsonb, 1, 'Answer B. The discharge of all plastics into the sea is prohibited, with no exceptions, including synthetic ropes, plastic sheeting and garbage bags.'),
  ('bm3:M09-013', 'BM-III', 9, 'B13.3', 'You have landed garbage at a port reception facility and want to keep proper evidence that the waste was managed correctly. Which record do you complete?', '["The Oil Record Book","The sewage record","The SOPEP log","The Garbage Record Book"]'::jsonb, 3, 'Answer D. Garbage handling is logged in the Garbage Record Book, which records what was produced and how it was disposed of. SCV Code 2021 · Caribbean Netherlands Page 31 / 40'),
  ('bm3:M09-014', 'BM-III', 9, 'B13.1', 'When landing oily water, oil residue or lubricating oil at a port reception facility, which record book is kept?', '["The Oil Record Book","The Garbage Record Book","The sewage record","The Garbage Management Plan"]'::jsonb, 0, 'Answer A. Oily water, oil residue and lubricating oil landed ashore are recorded in the Oil Record Book.'),
  ('bm3:M10-001', 'BM-III', 10, 'B1.8', 'Which of the following is a basic fire-prevention housekeeping measure aboard a small craft?', '["Storing oily rags in a warm, enclosed locker","Placing combustible material close to heat sources to dry it","Keeping spaces clean and free of oily rags and rubbish","Sealing battery compartments to prevent any ventilation"]'::jsonb, 2, 'Answer C. Good housekeeping means keeping spaces clean and free of oily rags and rubbish, and separating combustibles from heat sources.'),
  ('bm3:M10-002', 'BM-III', 10, 'B1.8', 'What are the three sides of the fire triangle?', '["Smoke, flame and ash","Water, foam and powder","Fuel, friction and pressure","Oxygen, heat and combustible material or vapours"]'::jsonb, 3, 'Answer D. The fire triangle is oxygen, heat (temperature) and combustible material or vapours; all three must be present at once.'),
  ('bm3:M10-003', 'BM-III', 10, 'B1.8', 'Which fourth element, added to the three sides of the triangle, forms the fire tetrahedron?', '["The self-sustaining chain reaction","An additional oxygen supply","The smoke produced","The auto-ignition temperature"]'::jsonb, 0, 'Answer A. Once burning, a self-sustaining chain reaction is added as the fourth element, turning the triangle into the tetrahedron.'),
  ('bm3:M10-004', 'BM-III', 10, 'B1.8', 'To stop combustion by removing oxygen, to roughly what level should the oxygen content be reduced from the normal 21%?', '["About 15%","About 10%","Down to 2–3%, ideally 0%","About 8%"]'::jsonb, 2, 'Answer C. The reader states bringing oxygen down to 2–3%, ideally 0%, stops combustion. SCV Code 2021 · Caribbean Netherlands Page 32 / 40'),
  ('bm3:M10-005', 'BM-III', 10, 'B1.8', 'You close a small compartment door on a contained fire and seal the openings. Which side of the fire triangle are you removing?', '["Heat, by cooling the fire","Fuel, by closing the supply","Oxygen, by smothering the fire","The chain reaction, chemically"]'::jsonb, 2, 'Answer C. Closing the compartment to smother the fire removes the oxygen side of the triangle.'),
  ('bm3:M10-006', 'BM-III', 10, 'B1.8', 'Approximately what is the flash point of diesel?', '["About 21 °C","About 52 °C","About 210 °C","About 100 °C"]'::jsonb, 1, 'Answer B. Diesel has a flash point of about 52 °C — the temperature at which it gives off enough vapour to flash with an ignition source.'),
  ('bm3:M10-007', 'BM-III', 10, 'B1.8', 'Why do gases ignite more easily than liquids or solids?', '["They are always hotter to begin with","They contain more oxygen internally","They have a higher auto-ignition temperature","Finely divided fuels, mists and gases react with surrounding air using far less energy"]'::jsonb, 3, 'Answer D. Finely divided fuels, mists and gases react with the surrounding air using far less energy, so gases ignite more easily.'),
  ('bm3:M10-008', 'BM-III', 10, 'B1.7', 'Which fire class covers liquids such as petrol, oil, paint and grease?', '["Class A","Class B","Class C","Class D"]'::jsonb, 1, 'Answer B. Class B covers liquids (petrol, oil, paint, fat, grease); Class A is solids, C gases, D metals, F cooking oil.'),
  ('bm3:M10-009', 'BM-III', 10, 'B1.7', 'A fire in a deep-fat fryer involving cooking oil falls into which fire class?', '["Class A","Class B","Class D","Class F"]'::jsonb, 3, 'Answer D. Class F covers cooking oil and deep-fat fryers.'),
  ('bm3:M10-010', 'BM-III', 10, 'B1.7', 'Burning aluminium or magnesium is an example of which fire class?', '["Class D (metals)","Class A (solids)","Class C (gases)","Class B (liquids)"]'::jsonb, 0, 'Answer A. Class D covers metal fires such as aluminium and magnesium. SCV Code 2021 · Caribbean Netherlands Page 33 / 40'),
  ('bm3:M10-011', 'BM-III', 10, 'B1.7', 'A crew member moves to throw a bucket of water on a burning pan of fat. Why is this dangerous?', '["Water is too cold and will crack the pan","Water has no extinguishing effect on any fire","Water spreads liquid fires and is unsuitable for a Class B fat fire","Water would put it out too quickly and waste effort"]'::jsonb, 2, 'Answer C. Water spreads liquid fires and must not be used on a Class B liquid fire such as burning fat.'),
  ('bm3:M10-012', 'BM-III', 10, null, 'Which is a recognised disadvantage of using water as an extinguishing agent?', '["It is scarce and expensive at sea","It conducts electricity","It provides no personal protection","It chemically reacts to produce toxic gas"]'::jsonb, 1, 'Answer B. Water conducts electricity, can spread liquid fires and causes water damage; it suits only Class A fires.'),
  ('bm3:M10-013', 'BM-III', 10, 'B1.7', 'A spilt-fuel fire is burning on the deck of your boat. Which agent and mechanism is most appropriate?', '["Water, by cooling the surface","A fire blanket dropped from a distance","Foam, by covering the surface and cutting off oxygen","Adding more oxygen to dilute the fuel"]'::jsonb, 2, 'Answer C. Foam suits Class B liquid fires; it extinguishes by covering the surface and cutting off oxygen, with secondary cooling.'),
  ('bm3:M10-014', 'BM-III', 10, 'B1.7', 'Which statement about dry powder is correct?', '["It gives a very fast knockdown but has no cooling effect","It conducts electricity and must not touch wiring","It is only suitable for Class A fires","It works best when combined with foam"]'::jsonb, 0, 'Answer A. Powder gives a very fast response on Class A, B and C, does not conduct electricity, but has no cooling effect and must not be combined with foam.'),
  ('bm3:M10-015', 'BM-III', 10, 'B1.7', 'Which agent must never be combined with dry powder?', '["Water","CO₂","A fire blanket","Foam"]'::jsonb, 3, 'Answer D. The reader warns powder must not be used together with foam. SCV Code 2021 · Caribbean Netherlands Page 34 / 40'),
  ('bm3:M10-016', 'BM-III', 10, 'B1.7', 'A fire breaks out in an enclosed engine compartment. Which agent works best there, and how does it extinguish the fire?', '["Water, by cooling the metal","CO₂, by displacing the oxygen in the enclosed space","Foam, by deep-seated penetration","Powder, by cooling the fire below combustion temperature"]'::jsonb, 1, 'Answer B. CO₂ works by displacing oxygen and is best in enclosed spaces such as machinery compartments.'),
  ('bm3:M10-017', 'BM-III', 10, 'B1.7', 'Which figures correctly describe CO₂ as an extinguishing agent?', '["About 1.5× heavier than air, with 10% concentration lethal to humans","About 1.5× lighter than air, with 21% concentration lethal","Equal density to air, with no suffocation risk","About 3× heavier than air, with 2% concentration lethal"]'::jsonb, 0, 'Answer A. CO₂ is about 1.5× heavier than air so it sinks into low spaces, and a 10% concentration is lethal to humans.'),
  ('bm3:M10-018', 'BM-III', 10, 'B1.7', 'You are about to attack a fire aboard. According to the tactical rules, which principle should guide your very first move?', '["Surround the fire completely before doing anything else","Prevent secondary water damage above all","Tackle the greatest danger first while protecting personal safety","Ventilate the space fully to clear the smoke"]'::jsonb, 2, 'Answer C. The tactical rules begin with tackling the greatest danger first and protecting personal safety, then preventing spread, surrounding the fire and preventing secondary damage.'),
  ('bm3:M11-001', 'BM-III', 11, 'B1.9 / VI', 'Which of the following is shown on a vessel''s safety plan?', '["Muster stations, life-saving appliances, emergency exits and fire-fighting equipment","The crew watch rota and meal times","The intended passage plan and waypoints","The engine maintenance schedule"]'::jsonb, 0, 'Answer A. The safety plan marks fire-fighting equipment, emergency exits, safety equipment, LSA, muster stations and emergency signals.'),
  ('bm3:M11-002', 'BM-III', 11, null, 'Where on a vessel are lifebuoys located and what markings must they carry?', '["On the foredeck only, marked with the owner''s name","Stowed below deck in a locker, marked with their expiry date","On both sides of the open decks, marked with the ship''s name and port of registry","At the helm only, marked with the maximum number of persons"]'::jsonb, 2, 'Answer C. Lifebuoys are located on both sides of the ship on the open decks and marked with the ship''s name and home port (port of registry). SCV Code 2021 · Caribbean Netherlands Page 35 / 40'),
  ('bm3:M11-003', 'BM-III', 11, 'B1.9 / VI/6', 'A self-righting lifejacket should turn an unconscious person face-up within how long, and hold the chin roughly how far above the water?', '["Within 10 seconds, chin about 6 cm above the water","Within 5 seconds, chin about 12 cm above the water","Within 15 seconds, chin about 20 cm above the water","Within 3 seconds, chin about 30 cm above the water"]'::jsonb, 1, 'Answer B. A good lifejacket self-rights within 5 seconds, holding the chin about 12 cm above the water.'),
  ('bm3:M11-004', 'BM-III', 11, 'B1.9 / VI/6', 'From what height should a wearer be able to jump safely into the water in a properly designed lifejacket?', '["1.5 m","3.0 m","6.0 m","4.5 m"]'::jsonb, 3, 'Answer D. A lifejacket should allow the wearer to jump safely from a height of 4.5 m into the water.'),
  ('bm3:M11-005', 'BM-III', 11, 'B1.9 / VI/6', 'Approximately what weight-capacity range should a range of lifejackets cover for the persons on board?', '["About 20 kg to 90 kg","About 30 kg to 120 kg","About 43 kg to 140 kg","About 50 kg to 160 kg"]'::jsonb, 2, 'Answer C. Lifejackets cater from a lower level of about 43 kg up to about 140 kg, with infant, child and adult types.'),
  ('bm3:M11-006', 'BM-III', 11, 'B1.9 / VI/6', 'A deckhand is wearing a work vest while working on the open deck in fine weather. Is the work vest an acceptable substitute for a lifejacket?', '["Yes, a work vest provides the same protection as a lifejacket","No, a work vest is a buoyancy aid and is not a substitute for a full lifejacket","Yes, provided the deckhand can swim","Yes, because it is daylight and the sea is calm"]'::jsonb, 1, 'Answer B. A work vest is a buoyancy aid worn while working on deck; it is not a full lifejacket and is not a substitute for one.'),
  ('bm3:M11-007', 'BM-III', 11, 'B1.9 / VI/6', 'How many lifejackets must be provided on board?', '["One lifejacket for every two persons on board","Only enough for the crew, not the passengers","One lifejacket per survival craft","One lifejacket for every person on board"]'::jsonb, 3, 'Answer D. A lifejacket must be provided for every person on board, with spares kept in different locations. SCV Code 2021 · Caribbean Netherlands Page 36 / 40'),
  ('bm3:M11-008', 'BM-III', 11, 'B7 / VI/4', 'Which of the following is an aid to location used to help rescuers find you?', '["A signalling mirror (heliograph)","A sea anchor","A bilge pump","An emergency tiller"]'::jsonb, 0, 'Answer A. Aids to location include pyrotechnics, a signalling mirror, a whistle, a radar reflector and retro-reflective material.'),
  ('bm3:M11-009', 'BM-III', 11, 'B7', 'On a handheld VHF radio, which channel is used for distress and safety calls?', '["Channel 6","Channel 67","Channel 16","Channel 72"]'::jsonb, 2, 'Answer C. For distress and safety use, handheld VHF radios use Channel 16.'),
  ('bm3:M11-010', 'BM-III', 11, 'B7', 'Why is an EPIRB fitted with a Hydrostatic Release Unit (HRU)?', '["So it can be charged from the vessel''s batteries","So it can be used as a handheld torch","So it transmits only when switched on by hand","So it floats free and transmits automatically if the vessel sinks"]'::jsonb, 3, 'Answer D. An EPIRB fitted with an HRU floats free and transmits automatically if the vessel sinks.'),
  ('bm3:M11-011', 'BM-III', 11, 'B7', 'What does a SART (Search and Rescue Transponder) do?', '["Broadcasts a voice distress message on Channel 16","Shows the vessel''s position as a line of dots on a rescuer''s radar screen","Releases an oil slick to mark the position","Sounds a continuous audible alarm only"]'::jsonb, 1, 'Answer B. A SART shows the vessel''s position as a line of dots on a rescuer''s radar screen.'),
  ('bm3:M11-012', 'BM-III', 11, null, 'A passenger falls overboard from your open boat. What is your very first action?', '["Immediately turn the vessel hard to port","Go below to fetch the first-aid kit","Keep visual contact, point at the casualty, and throw the MOB buoy","Broadcast a MAYDAY before doing anything else"]'::jsonb, 2, 'Answer C. The first MOB actions are to keep visual contact and point at the casualty and release the MOB buoy towards them. SCV Code 2021 · Caribbean Netherlands Page 37 / 40'),
  ('bm3:M11-013', 'BM-III', 11, 'B1.2 / B1.3', 'Your engine has failed and will not restart while you drift towards a lee shore. Which response is most appropriate?', '["Keep cranking the starter continuously until the battery is flat","Anchor if the depth allows, show the correct shapes/lights and call for assistance on VHF","Abandon ship immediately into the water","Ignore it and wait for the engine to cool down"]'::jsonb, 1, 'Answer B. On loss of engines, anchor if depth allows, show the correct not-under-command shapes/lights and call for assistance on VHF while watching your drift.'),
  ('bm3:M11-014', 'BM-III', 11, 'B1.5', 'Your vessel is taking on water and in danger of sinking close inshore. You decide to beach her. Which shore should you choose?', '["A steep rocky shore with heavy surf","The nearest harbour wall, approached at full speed","An exposed reef where the vessel will be visible from far off","A gently shelving, sheltered, sandy or shingle shore clear of rocks and surf, approached slowly bow-on ✓"]'::jsonb, 0, 'Answer D. For beaching, choose a gently shelving, sheltered, sandy or shingle shore clear of rocks and surf, and approach slowly bow-on.')
on conflict (id) do update set
  course_code = excluded.course_code,
  module_seq  = excluded.module_seq,
  ref         = excluded.ref,
  stem        = excluded.stem,
  opts        = excluded.opts,
  correct     = excluded.correct,
  expl        = excluded.expl;

-- ---- Module-content (reader/deck-paden + gecureerde quizlijst) ----
-- Storage-paden in bucket 'course-content'. Volgnummer = modules.sequence.

update modules m set
  reader_path = 'bm3/readers/M01.pdf',
  deck_path   = 'bm3/decks/M01.pdf',
  quiz_ids    = '["bm3:M01-001","bm3:M01-002","bm3:M01-003","bm3:M01-004","bm3:M01-005","bm3:M01-006","bm3:M01-007","bm3:M01-008"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-III' and m.sequence = 1;
update modules m set
  reader_path = 'bm3/readers/M02.pdf',
  deck_path   = 'bm3/decks/M02.pdf',
  quiz_ids    = '["bm3:M02-001","bm3:M02-002","bm3:M02-003","bm3:M02-004","bm3:M02-005","bm3:M02-006","bm3:M02-007","bm3:M02-008","bm3:M02-009","bm3:M02-010","bm3:M02-011","bm3:M02-012","bm3:M02-013","bm3:M02-014","bm3:M02-015","bm3:M02-016","bm3:M02-017","bm3:M02-018","bm3:M02-019"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-III' and m.sequence = 2;
update modules m set
  reader_path = 'bm3/readers/M03.pdf',
  deck_path   = 'bm3/decks/M03.pdf',
  quiz_ids    = '["bm3:M03-001","bm3:M03-002","bm3:M03-003","bm3:M03-004","bm3:M03-005","bm3:M03-006","bm3:M03-007","bm3:M03-008","bm3:M03-009","bm3:M03-010","bm3:M03-011","bm3:M03-012","bm3:M03-013","bm3:M03-014","bm3:M03-015","bm3:M03-016","bm3:M03-017","bm3:M03-018"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-III' and m.sequence = 3;
update modules m set
  reader_path = 'bm3/readers/M04.pdf',
  deck_path   = 'bm3/decks/M04.pdf',
  quiz_ids    = '["bm3:M04-001","bm3:M04-002","bm3:M04-003","bm3:M04-004","bm3:M04-005","bm3:M04-006","bm3:M04-007","bm3:M04-008","bm3:M04-009","bm3:M04-010","bm3:M04-011","bm3:M04-012","bm3:M04-013","bm3:M04-014","bm3:M04-015","bm3:M04-016","bm3:M04-017","bm3:M04-018","bm3:M04-019","bm3:M04-020","bm3:M04-021","bm3:M04-022","bm3:M04-023","bm3:M04-024","bm3:M04-025","bm3:M04-026"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-III' and m.sequence = 4;
update modules m set
  reader_path = 'bm3/readers/M05.pdf',
  deck_path   = 'bm3/decks/M05.pdf',
  quiz_ids    = '["bm3:M05-001","bm3:M05-002","bm3:M05-003","bm3:M05-004","bm3:M05-005","bm3:M05-006","bm3:M05-007","bm3:M05-008","bm3:M05-009","bm3:M05-010","bm3:M05-011","bm3:M05-012","bm3:M05-013","bm3:M05-014"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-III' and m.sequence = 5;
update modules m set
  reader_path = 'bm3/readers/M06.pdf',
  deck_path   = 'bm3/decks/M06.pdf',
  quiz_ids    = '["bm3:M06-001","bm3:M06-002","bm3:M06-003","bm3:M06-004","bm3:M06-005","bm3:M06-006","bm3:M06-007","bm3:M06-008","bm3:M06-009","bm3:M06-010","bm3:M06-011","bm3:M06-012","bm3:M06-013","bm3:M06-014","bm3:M06-015"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-III' and m.sequence = 6;
update modules m set
  reader_path = 'bm3/readers/M07.pdf',
  deck_path   = 'bm3/decks/M07.pdf',
  quiz_ids    = '["bm3:M07-001","bm3:M07-002","bm3:M07-003","bm3:M07-004","bm3:M07-005","bm3:M07-006","bm3:M07-007","bm3:M07-008","bm3:M07-009","bm3:M07-010","bm3:M07-011","bm3:M07-012","bm3:M07-013","bm3:M07-014","bm3:M07-015","bm3:M07-016","bm3:M07-017","bm3:M07-018"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-III' and m.sequence = 7;
update modules m set
  reader_path = 'bm3/readers/M08.pdf',
  deck_path   = 'bm3/decks/M08.pdf',
  quiz_ids    = '["bm3:M08-001","bm3:M08-002","bm3:M08-003","bm3:M08-004","bm3:M08-005","bm3:M08-006","bm3:M08-007","bm3:M08-008","bm3:M08-009","bm3:M08-010","bm3:M08-011","bm3:M08-012","bm3:M08-013","bm3:M08-014","bm3:M08-015","bm3:M08-016","bm3:M08-017","bm3:M08-018","bm3:M08-019"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-III' and m.sequence = 8;
update modules m set
  reader_path = 'bm3/readers/M09.pdf',
  deck_path   = 'bm3/decks/M09.pdf',
  quiz_ids    = '["bm3:M09-001","bm3:M09-002","bm3:M09-003","bm3:M09-004","bm3:M09-005","bm3:M09-006","bm3:M09-007","bm3:M09-008","bm3:M09-009","bm3:M09-010","bm3:M09-011","bm3:M09-012","bm3:M09-013","bm3:M09-014"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-III' and m.sequence = 9;
update modules m set
  reader_path = 'bm3/readers/M10.pdf',
  deck_path   = 'bm3/decks/M10.pdf',
  quiz_ids    = '["bm3:M10-001","bm3:M10-002","bm3:M10-003","bm3:M10-004","bm3:M10-005","bm3:M10-006","bm3:M10-007","bm3:M10-008","bm3:M10-009","bm3:M10-010","bm3:M10-011","bm3:M10-012","bm3:M10-013","bm3:M10-014","bm3:M10-015","bm3:M10-016","bm3:M10-017","bm3:M10-018"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-III' and m.sequence = 10;
update modules m set
  reader_path = 'bm3/readers/M11.pdf',
  deck_path   = 'bm3/decks/M11.pdf',
  quiz_ids    = '["bm3:M11-001","bm3:M11-002","bm3:M11-003","bm3:M11-004","bm3:M11-005","bm3:M11-006","bm3:M11-007","bm3:M11-008","bm3:M11-009","bm3:M11-010","bm3:M11-011","bm3:M11-012","bm3:M11-013","bm3:M11-014"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-III' and m.sequence = 11;
update modules m set
  reader_path = 'bm3/readers/M12.pdf',
  deck_path   = 'bm3/decks/M12.pdf',
  quiz_ids    = '["bm3:M01-008","bm3:M06-002","bm3:M06-013","bm3:M10-003","bm3:M10-011","bm3:M10-013","bm3:M11-012"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-III' and m.sequence = 12;

-- Klaar.


-- ############################################################
-- E-LEARNING — Seed BM I + BM II (zelfde opzet als BM III)
-- Toegevoegd zodat INSTALL.sql alle drie de cursussen seedt.
-- ############################################################

-- ============================================================
-- Plaza Boat College — Seed e-learning BM I
-- AUTOGEGENEREERD door scripts/gen-seed.mjs — niet handmatig bewerken.
-- Bron: data.js  ·  181 vragen
-- Idempotent: on conflict (id) do update. Voer uit NA migrations/0002_elearning.sql.
-- ============================================================

-- ---- Vragenbank (BM I) ----
insert into questions (id, course_code, module_seq, ref, stem, opts, correct, expl) values
  ('bm1:B12-001', 'BM-I', 2, 'B12.1', 'Merchant Shipping Notices and equivalent official notices are carried so the master can:', '["Decorate the wheelhouse","Stay current with safety information, requirements and warnings applicable to the vessel","Sell them ashore","Use them as scrap paper"]'::jsonb, 1, 'Answer B. Official notices convey mandatory requirements, guidance and safety information; the master keeps and applies those relevant to the vessel.'),
  ('bm1:B12-002', 'BM-I', 2, 'B12.2', 'The applicable regulations (e.g. the SCV Code) should be carried on board so that:', '["They look official","The master can reference the rules the vessel must comply with","They satisfy passengers","They replace the chart"]'::jsonb, 1, 'Answer B. Carrying the relevant regulations lets the master check and demonstrate compliance with the requirements that apply to the vessel.'),
  ('bm1:B12-003', 'BM-I', 2, 'B12.3', 'Charts and tide tables carried on board must be:', '["Any edition, however old","Of the correct area and corrected up to date (or a current edition) for the intended passage","Photocopies only","Optional if a plotter is fitted"]'::jsonb, 1, 'Answer B. Navigation charts and tide tables must cover the area and be up to date/corrected; electronic aids supplement but do not excuse carrying correct navigational publications.'),
  ('bm1:B16-001', 'BM-I', 2, 'B16.1', 'The deck log should be prepared and kept so that it:', '["Is written up from memory at season end","Provides a contemporaneous, ink record of times, positions, courses, weather and events, ready for inspection","Contains only fuel costs","Is filled in by passengers"]'::jsonb, 1, 'Answer B. The deck log is prepared in advance and completed contemporaneously in ink; it records the navigation and operation of the vessel and must be available for inspection.'),
  ('bm1:B16-002', 'BM-I', 2, 'B16.2', 'Standard procedure on leaving port includes:', '["Departing without checks","Pre-departure checks, confirming numbers on board, obtaining clearance where required and logging the time of departure","Telling no one","Leaving the gangway rigged"]'::jsonb, 1, 'Answer B. On departure the master completes pre-departure and safety checks, confirms persons on board, obtains any required port clearance and records the time of sailing.'),
  ('bm1:B16-003', 'BM-I', 2, 'B16.2', 'On entering a port the master should:', '["Maintain full speed to the berth","Observe local rules and speed limits, monitor the working VHF channel, follow buoyage/traffic schemes and contact port control if required","Ignore other traffic","Anchor in the fairway"]'::jsonb, 1, 'Answer B. Entering port, comply with local regulations and speed limits, keep a listening watch on the port channel, follow the buoyage and contact port control as required.'),
  ('bm1:B16-004', 'BM-I', 2, 'B16.3', 'A crew list is maintained so that:', '["It is never needed","Those on board are known to the master and authorities, aiding accounting in an emergency and meeting reporting requirements","It records passengers'' meals","It lists only the master"]'::jsonb, 1, 'Answer B. The crew list records who is on board for safe manning, emergency headcount and the reporting requirements of the authorities.'),
  ('bm1:B16-005', 'BM-I', 2, 'B16.4', 'A passenger list / accurate headcount is important because:', '["It is optional","It ensures the certified number is not exceeded and enables a full account of everyone in an emergency or evacuation","It is only for ticketing","It tells the chef numbers"]'::jsonb, 1, 'Answer B. An accurate passenger count keeps within the certified limit and is essential to account for all persons during and after an emergency (VIII/7).'),
  ('bm1:B16-006', 'BM-I', 2, 'B16.5', 'Carrying valid vessel insurance matters because:', '["It is decorative","It provides cover for liabilities (including third-party/passenger) and is often a legal/operational requirement","It replaces the Safety Certificate","It is only for racing"]'::jsonb, 1, 'Answer B. Adequate insurance (including third-party and passenger liability) protects against the financial consequences of a casualty and is commonly required to operate commercially.'),
  ('bm1:B16-007', 'BM-I', 2, 'B16.6', 'A Safety Management System (SMS) provides:', '["A wage scale","Documented procedures for safe operation, maintenance, emergencies and reporting, with defined responsibilities","A sales brochure","The tide tables"]'::jsonb, 1, 'Answer B. An SMS sets out documented procedures and responsibilities for safe operation, planned maintenance, emergency response and incident reporting.'),
  ('bm1:B16-008', 'BM-I', 2, 'B16.6', 'Following an incident, the SMS typically requires the master to:', '["Forget about it","Record and report the incident so causes can be reviewed and recurrence prevented","Hide it from the operator","Blame the crew verbally only"]'::jsonb, 1, 'Answer B. The SMS requires incidents and near-misses to be recorded and reported so the operator can investigate, learn and improve procedures.'),
  ('bm1:B3-001', 'BM-I', 2, 'B3.1', 'On loss of life or serious injury to a person on board, the master must:', '["Continue the voyage and mention it on return","Preserve the scene as far as safety allows, render aid, and report to the authorities as soon as possible","Tell no one","Discharge the crew involved"]'::jsonb, 1, 'Answer B. The master renders aid, preserves evidence so far as safe, records the facts and reports the casualty to the competent authority without delay.'),
  ('bm1:B3-002', 'BM-I', 2, 'B3.2', 'The principal certificate that a small commercial vessel must carry is the:', '["VHF licence only","SCV Safety Certificate (Reg. I/15)","Insurance schedule only","Crew agreement only"]'::jsonb, 1, 'Answer B. The vessel must carry a valid SCV Safety Certificate issued under Regulation I/15, confirming it meets the Code for its area and service.'),
  ('bm1:B3-003', 'BM-I', 2, 'B3.3', 'A vessel may operate only within:', '["Whatever area the master prefers","The area and conditions stated on its Safety Certificate and the master''s licence — the narrower governs","Any area within 24 hours of port","Any area in daylight"]'::jsonb, 1, 'Answer B. Operation is limited to the area/conditions on the Safety Certificate and to the grade of the master''s licence; the narrower of the two governs.'),
  ('bm1:B3-004', 'BM-I', 2, 'B3.3', 'A Grade 1 master in command of a vessel certified only for sheltered day operation may:', '["Take her to sea overnight because the master is highly qualified","Only operate her within the sheltered, day limits of her certificate","Ignore the certificate limits","Upgrade the certificate himself"]'::jsonb, 1, 'Answer B. The certificate limits the vessel regardless of the master''s grade; she may only be operated within her certified area and conditions.'),
  ('bm1:B9-001', 'BM-I', 2, 'B9.1', 'Safe access to and from the vessel means providing:', '["A single rope to climb","A properly rigged, secured gangway/passerelle or safe step with handholds and adequate lighting","A jump from the quay","Access only at high water"]'::jsonb, 1, 'Answer B. The master must provide safe means of access — a secured gangway or safe step with handhold and lighting — to prevent falls boarding or leaving.'),
  ('bm1:B9-002', 'BM-I', 2, 'B9.2', 'Safe working practices on deck include:', '["Working alone in all conditions","Using PPE, non-slip footwear, keeping clear of bights of line, and briefing the crew on the task","Removing all guards","Working at full speed regardless"]'::jsonb, 1, 'Answer B. Safe working practices include suitable PPE and footwear, keeping clear of snap-back and bights, securing the task and briefing the crew on hazards.'),
  ('bm1:B9-003', 'BM-I', 2, 'B9.3', 'The SCV Safety Certificate (I/15) certifies that:', '["The crew are paid","The vessel complies with the Code for its area and category and may operate within stated limits","The vessel is insured","The master holds a licence"]'::jsonb, 1, 'Answer B. The Safety Certificate (I/15) records that the vessel meets the Code''s requirements for its category and area and states the limits within which she may operate.'),
  ('bm1:B9-004', 'BM-I', 2, 'B9.4', 'Basic security awareness on board includes:', '["Ignoring strangers","Controlling access to the vessel, securing valuables and being alert to suspicious behaviour or items","Leaving the vessel open","Posting the schedule publicly"]'::jsonb, 1, 'Answer B. Basic security means controlling who boards, securing the vessel and valuables, and reporting suspicious persons, packages or activity.'),
  ('bm1:B10-001', 'BM-I', 3, 'B10.1', 'Before departure the master should obtain the latest forecast from:', '["Memory of yesterday''s weather","Official meteorological services via radio, NAVTEX, VHF, TV or internet","The colour of the sky only","Other passengers"]'::jsonb, 1, 'Answer B. The master uses official met services (radio, NAVTEX, VHF broadcasts, internet) to get the latest forecast and warnings before and during a passage.'),
  ('bm1:B10-002', 'BM-I', 3, 'B10.3', 'A rapid fall in barometric pressure usually indicates:', '["Improving, settled weather","Approaching deteriorating weather, often with strengthening wind","No change","Fog only"]'::jsonb, 1, 'Answer B. A rapid pressure fall signals an approaching depression/front and usually strengthening wind and worsening conditions.'),
  ('bm1:B10-003', 'BM-I', 3, 'B10.3', 'Signs of approaching bad weather at sea include:', '["Clearing skies and steady glass","Lowering/thickening cloud, increasing swell, freshening and backing/veering wind and a falling barometer","Calm with no cloud","Rising barometer only"]'::jsonb, 1, 'Answer B. Thickening high cloud, increasing swell, a shifting and freshening wind and a falling barometer together warn of deteriorating weather.'),
  ('bm1:B10-004', 'BM-I', 3, 'B10.2', 'Local effects such as sea and land breezes and acceleration around headlands matter because they:', '["Never affect small craft","Can produce wind and sea conditions markedly different from the general forecast","Only affect large ships","Cancel the tide"]'::jsonb, 1, 'Answer B. Local topography (headlands, valleys, sea/land breezes) can strengthen or shift the wind and raise steep seas beyond what the area forecast suggests.'),
  ('bm1:B10-005', 'BM-I', 3, 'B10.1', 'A gale warning broadcast means:', '["Winds of force 5 are forecast","Winds of at least force 8 (or gusts) are forecast in the area — consider delaying or sheltering","Fog is forecast","The sea is flat"]'::jsonb, 1, 'Answer B. A gale warning indicates winds of force 8 or more (or severe gusts) are expected; the master should consider postponing or seeking shelter.'),
  ('bm1:B14-001', 'BM-I', 3, 'B14.1', 'Marine radar is primarily used to:', '["Listen to weather forecasts","Detect and range other vessels and the coastline, and help assess risk of collision","Measure depth","Receive GPS position"]'::jsonb, 1, 'Answer B. Radar shows the range and bearing of targets and the coast, aiding collision avoidance and navigation, especially in poor visibility.'),
  ('bm1:B14-002', 'BM-I', 3, 'B14.1', 'AIS (Automatic Identification System) provides:', '["Depth under the keel","Identity, position, course and speed of equipped vessels","The tidal stream","Engine temperature"]'::jsonb, 1, 'Answer B. AIS exchanges vessel identity, position, course, speed and other data between equipped ships and shore, aiding identification and collision avoidance.'),
  ('bm1:B14-003', 'BM-I', 3, 'B14.1', 'An echo sounder measures:', '["Distance to the shore","Depth of water under the transducer","Speed over ground","The variation"]'::jsonb, 1, 'Answer B. The echo sounder measures the depth of water beneath the transducer by timing a sound pulse to the seabed and back.'),
  ('bm1:B14-004', 'BM-I', 3, 'B14.1', 'A GPS/GNSS receiver provides primarily:', '["Depth","Position (latitude and longitude), and from successive fixes COG and SOG","Wind speed","Engine hours"]'::jsonb, 1, 'Answer B. Satellite navigation gives position; from changing positions it derives course and speed over the ground.'),
  ('bm1:B14-005', 'BM-I', 3, 'B14.1', 'A prudent Grade 1 master treats electronic aids as:', '["Infallible and a replacement for the chart and lookout","Valuable aids to be cross-checked against the chart, the lookout and other methods","Only for fine weather","Decorative"]'::jsonb, 1, 'Answer B. Electronic aids can fail or mislead (datum, signal loss, clutter); they must be cross-checked against the chart, visual fixes and a proper lookout.'),
  ('bm1:B14-006', 'BM-I', 3, 'B14.1', 'A limitation of radar the operator must remember is that:', '["It shows colours of buoys","Small craft, low targets and objects in clutter/rain may not show up reliably","It always detects everything","It measures depth"]'::jsonb, 1, 'Answer B. Radar can miss small or low targets and those hidden in sea/rain clutter; it must not replace a visual and audible lookout.'),
  ('bm1:B14-007', 'BM-I', 3, 'B14.1', 'GPS position should be cross-checked because:', '["It is never wrong","Wrong chart datum, signal loss or input error can put the displayed position adrift of the real one","It measures the tide","It only works in port"]'::jsonb, 1, 'Answer B. GPS can mislead through datum mismatch, signal interruption or operator error; confirm against the chart and visual fixes.'),
  ('bm1:B5-001', 'BM-I', 3, 'B5.3', 'A position fix from the intersection of two or more position lines is most reliable when the lines:', '["Cross at a very fine angle","Cross at a good angle (near 90 degrees) — three lines giving a small cocked hat","Are parallel","Are all from the same object"]'::jsonb, 1, 'Answer B. A good fix has position lines crossing near right angles; three lines giving a small cocked hat give confidence in the position.'),
  ('bm1:B5-002', 'BM-I', 3, 'B5.3', 'A ''running fix'' is used when:', '["Two objects are visible at once","Only one object is available — a bearing is taken, the run transferred, and a second bearing of the same object gives a fix","No objects are visible","The GPS has failed permanently"]'::jsonb, 1, 'Answer B. A running fix transfers an earlier position line forward by the vessel''s run (course and distance) to cross a later bearing of the same object.'),
  ('bm1:B5-003', 'BM-I', 3, 'B5.4', 'To find the course to steer to make good a desired track when a current is setting the vessel, you:', '["Steer the track and ignore the current","Construct a vector triangle: lay off the track, the tide/current vector, and resolve for the course to steer at your boat speed","Add the current to your speed","Steer downstream of the track"]'::jsonb, 1, 'Answer B. Draw the tidal/current vector from the start, set the boat-speed radius onto the required track line, and the resulting heading is the course to steer.'),
  ('bm1:B5-004', 'BM-I', 3, 'B5.4', 'Leeway is:', '["The slack in the steering","The vessel''s sideways drift to leeward caused by wind, applied as an angle off the heading","The difference between true and magnetic north","The tidal set"]'::jsonb, 1, 'Answer B. Leeway is the angle between the heading and the actual water track caused by wind pushing the vessel to leeward; it is applied to the course to steer.'),
  ('bm1:B5-005', 'BM-I', 3, 'B5.4', 'To allow for leeway when steering, you apply the leeway angle:', '["Downwind of the desired track","Up-wind of the track so the vessel is blown back onto track","It makes no difference","Only to the GPS course"]'::jsonb, 1, 'Answer B. You steer up-wind of the desired track by the leeway angle so that the wind sets the vessel back onto the intended track.'),
  ('bm1:B5-006', 'BM-I', 3, 'B5.5', 'Variation is the angle between:', '["True north and magnetic north at a place","The heading and the track","The lubber line and the card","Compass north and magnetic north"]'::jsonb, 0, 'Answer A. Variation is the angle between true and magnetic north for a given place and year, shown on the chart''s compass rose.'),
  ('bm1:B5-007', 'BM-I', 3, 'B5.5', 'Deviation is the compass error caused by:', '["The earth''s magnetic field only","The vessel''s own magnetism acting on the compass, varying with the ship''s heading","Tidal streams","The chart datum"]'::jsonb, 1, 'Answer B. Deviation is the error caused by the vessel''s own iron/electrics; it changes with the vessel''s heading and is read from the deviation card.'),
  ('bm1:B5-008', 'BM-I', 3, 'B5.5', 'To convert a compass course to a true course you apply, in order:', '["Variation then deviation","Deviation (for that heading) then variation","Leeway only","Nothing — they are the same"]'::jsonb, 1, 'Answer B. Compass to true: apply deviation (for that heading) to get magnetic, then variation to get true.'),
  ('bm1:B5-009', 'BM-I', 3, 'B5.5', 'With variation 5W and deviation 2E on the steered heading, the total compass error is:', '["7W","3W","3E","7E"]'::jsonb, 1, 'Answer B. Combine: 5W and 2E give a net 3W total error (east cancels part of the west error).'),
  ('bm1:B5-010', 'BM-I', 3, 'B5.2', 'A tidal diamond on a chart gives:', '["The depth of water","The direction and rate of tidal stream at that position for each hour relative to HW","The variation","The position of a wreck"]'::jsonb, 1, 'Answer B. A tidal diamond keys to a table giving the set (direction) and rate (speed) of the tidal stream for each hour before/after high water at the reference port.'),
  ('bm1:B5-011', 'BM-I', 3, 'B5.2', 'Tidal stream rates in the diamond tables are usually given for:', '["Springs and neaps","Daylight only","One fixed value all year","Full moon only"]'::jsonb, 0, 'Answer A. The diamond tables list spring and neap rates; you interpolate for the day''s range between them.'),
  ('bm1:B5-012', 'BM-I', 3, 'B5.6', 'The four stages of a passage (voyage) plan are:', '["Appraisal, Planning, Execution, Monitoring","Look, point, go","Speed, fuel, food","Anchor, moor, depart"]'::jsonb, 0, 'Answer A. Good passage planning follows Appraisal, Planning, Execution and Monitoring: gather information, plan the route, carry it out and continuously check progress.'),
  ('bm1:B5-013', 'BM-I', 3, 'B5.6', 'A safe passage plan should include:', '["Only the start and finish","Courses, distances, hazards, clearing bearings, tidal windows, contingency/abort points and fuel","Just the GPS waypoints","Only the weather forecast"]'::jsonb, 1, 'Answer B. A plan covers the route, courses and distances, dangers and clearing lines, tidal heights/streams, no-go areas, contingencies and fuel/endurance.'),
  ('bm1:B5-014', 'BM-I', 3, 'B5.1', 'On a chart, the anchor symbol indicates:', '["A wreck","A recommended anchorage","A lighthouse","A tide gauge"]'::jsonb, 1, 'Answer B. The anchor symbol marks an anchorage area; chart symbols are interpreted via the chart legend (INT 1 / Chart 5011).'),
  ('bm1:B5-015', 'BM-I', 3, 'B5.1', 'Charted depths (soundings) are normally given relative to:', '["Mean high water","Chart datum (approximately the lowest astronomical tide)","The deck of your vessel","Mean sea level only"]'::jsonb, 1, 'Answer B. Soundings are reduced to chart datum (close to LAT), so actual depth = charted depth + height of tide above datum.'),
  ('bm1:B5-016', 'BM-I', 3, 'B5.6', 'To find the depth of water at a given time, you:', '["Read the charted sounding directly","Add the height of tide for that time to the charted sounding","Subtract the variation","Use the deviation card"]'::jsonb, 1, 'Answer B. Depth at a given time = charted sounding + height of tide above chart datum at that time (from the tide tables/curve).'),
  ('bm1:B5-017', 'BM-I', 3, 'B5.6', 'A clearing bearing is used to:', '["Set the radar range","Keep the vessel clear of a known danger by ensuring a bearing of a fixed mark stays beyond a safe limit","Measure speed","Correct deviation"]'::jsonb, 1, 'Answer B. A clearing bearing of a fixed mark defines a line that, kept on the safe side, ensures the vessel stays clear of a charted danger.'),
  ('bm1:B5-018', 'BM-I', 3, 'B5.5', 'Parallel rules (or a plotter) are used on the chart to:', '["Measure distance only","Transfer a bearing/course to or from the compass rose without changing its direction","Measure depth","Find the variation table"]'::jsonb, 1, 'Answer B. Parallel rules walk a line across the chart keeping its direction, so a course or bearing can be read off the compass rose or laid from a position.'),
  ('bm1:B5-019', 'BM-I', 3, 'B5.5', 'Dividers on a chart are used to:', '["Draw the course line","Measure distance against the latitude scale","Apply leeway","Read the tide table"]'::jsonb, 1, 'Answer B. Dividers measure distance, read against the latitude scale at the side of the chart (1 minute of latitude = 1 nautical mile).'),
  ('bm1:B2-001', 'BM-I', 4, 'Rule 5', 'COLREG Rule 5 requires that:', '["A proper lookout is kept by sight and hearing and all available means at all times","A lookout is only needed at night","Radar replaces the human lookout","A lookout is optional in good visibility"]'::jsonb, 0, 'Answer A. Rule 5: every vessel shall at all times maintain a proper lookout by sight and hearing and by all available means appropriate to the circumstances.'),
  ('bm1:B2-002', 'BM-I', 4, 'Rule 6', 'Rule 6 (safe speed) requires speed to be set so a vessel can:', '["Always make best passage time","Stop within a distance appropriate to the prevailing circumstances and visibility","Outrun other vessels","Plane in all conditions"]'::jsonb, 1, 'Answer B. Safe speed allows proper and effective action to avoid collision and stopping within a distance appropriate to the circumstances and conditions.'),
  ('bm1:B2-003', 'BM-I', 4, 'Rule 7', 'Under Rule 7, risk of collision exists if the compass bearing of an approaching vessel:', '["Changes rapidly","Does not appreciably change","Is abeam","Is astern"]'::jsonb, 1, 'Answer B. A steady or little-changing compass bearing with decreasing range indicates risk of collision exists.'),
  ('bm1:B2-004', 'BM-I', 4, 'Rule 8', 'Rule 8 requires that action to avoid collision be:', '["Small and gradual so as not to alarm","Positive, made in ample time and large enough to be readily apparent","Left to the last moment","A series of tiny alterations"]'::jsonb, 1, 'Answer B. Action shall be positive, made in good time, and large enough to be readily apparent to another vessel observing visually or by radar.'),
  ('bm1:B2-005', 'BM-I', 4, 'Rule 9', 'In a narrow channel a vessel shall keep:', '["In the middle","To the outer limit on her starboard side","To the port side","Wherever the tide is weakest"]'::jsonb, 1, 'Answer B. Rule 9: keep as near to the outer limit of the channel on your starboard side as is safe and practicable.'),
  ('bm1:B2-006', 'BM-I', 4, 'Rule 12', 'When two sailing vessels have the wind on different sides, the one that gives way is:', '["The vessel with wind on the starboard side","The vessel with wind on the port side","The larger vessel","The faster vessel"]'::jsonb, 1, 'Answer B. Rule 12: when each has wind on a different side, the vessel with the wind on the port side keeps out of the way.'),
  ('bm1:B2-007', 'BM-I', 4, 'Rule 13', 'An overtaking vessel:', '["Has right of way over the vessel ahead","Must keep out of the way of the vessel being overtaken","May cut across as it pleases","Is the stand-on vessel"]'::jsonb, 1, 'Answer B. Rule 13: any vessel overtaking shall keep out of the way of the vessel being overtaken, regardless of later changes.'),
  ('bm1:B2-008', 'BM-I', 4, 'Rule 14', 'Two power-driven vessels meeting head-on shall each:', '["Alter course to port","Alter course to starboard so each passes port-to-port","Stop","Hold course and speed"]'::jsonb, 1, 'Answer B. Rule 14: in a head-on situation each alters course to starboard to pass port to port.'),
  ('bm1:B2-009', 'BM-I', 4, 'Rule 15', 'In a crossing situation between two power-driven vessels, the vessel that gives way is the one that:', '["Has the other on her own port side","Has the other on her own starboard side","Is to windward","Is the faster"]'::jsonb, 1, 'Answer B. Rule 15: the vessel which has the other on her own starboard side keeps out of the way and avoids crossing ahead.'),
  ('bm1:B2-010', 'BM-I', 4, 'Rule 16', 'The give-way vessel is required to:', '["Hold course and speed","Take early and substantial action to keep well clear","Sound five short blasts","Call the other vessel on VHF first"]'::jsonb, 1, 'Answer B. Rule 16: the give-way vessel shall take early and substantial action to keep well clear.'),
  ('bm1:B2-011', 'BM-I', 4, 'Rule 17', 'The stand-on vessel must:', '["Always hold course and speed no matter what","Keep her course and speed, but may and finally must act if the give-way vessel does not","Immediately give way","Stop her engines"]'::jsonb, 1, 'Answer B. Rule 17: the stand-on vessel keeps course and speed, may take action when collision appears, and must act when collision cannot be avoided by the give-way vessel alone.'),
  ('bm1:B2-012', 'BM-I', 4, 'Rule 18', 'In general the ''pecking order'' means a power-driven vessel keeps out of the way of:', '["A vessel restricted in her ability to manoeuvre, not under command, fishing, and sailing","Only sailing vessels","Only larger ships","Nothing — power always has right of way"]'::jsonb, 0, 'Answer A. Rule 18 hierarchy: a power-driven vessel gives way to NUC, RAM, vessels engaged in fishing and sailing vessels.'),
  ('bm1:B2-013', 'BM-I', 4, 'Rule 19', 'In or near restricted visibility, on hearing a fog signal apparently forward of the beam, a vessel shall:', '["Maintain speed","Reduce to the minimum at which she can be kept on course, or stop if necessary","Alter boldly to port","Sound the overtaking signal"]'::jsonb, 1, 'Answer B. Rule 19: reduce speed to the minimum to keep steerage, and if necessary take all way off, navigating with extreme caution.'),
  ('bm1:B2-014', 'BM-I', 4, 'Rule 23', 'A power-driven vessel under way of less than 50 m shows, as a minimum:', '["One masthead light, sidelights and a sternlight","Two masthead lights and a red all-round","Three all-round red lights","Sidelights only"]'::jsonb, 0, 'Answer A. Rule 23: a power-driven vessel under 50 m shows a masthead light, sidelights and a sternlight (a second masthead light is optional).'),
  ('bm1:B2-015', 'BM-I', 4, 'Rule 24', 'A vessel towing astern, where the tow exceeds 200 m, shows on the masthead:', '["One white light","Two white lights in a vertical line","Three white lights in a vertical line","A red over white"]'::jsonb, 2, 'Answer C. Rule 24: when the length of tow exceeds 200 m the towing vessel shows three masthead lights in a vertical line (otherwise two).'),
  ('bm1:B2-016', 'BM-I', 4, 'Rule 25', 'A sailing vessel under way shows:', '["Sidelights and a sternlight","A masthead light and sidelights","Two all-round red lights","A green over white"]'::jsonb, 0, 'Answer A. Rule 25: a sailing vessel under way shows sidelights and a sternlight (no masthead steaming light).'),
  ('bm1:B2-017', 'BM-I', 4, 'Rule 26', 'A vessel engaged in trawling shows:', '["Red over white","Green over white","Two red lights vertically","Red over red"]'::jsonb, 1, 'Answer B. Rule 26: a vessel trawling shows green over white all-round lights (''green over white, trawling at night'').'),
  ('bm1:B2-018', 'BM-I', 4, 'Rule 27', 'A vessel not under command (NUC) shows at night:', '["Two all-round red lights in a vertical line","Two all-round green lights","Red over white","Three white lights"]'::jsonb, 0, 'Answer A. Rule 27: a vessel not under command shows two all-round red lights in a vertical line.'),
  ('bm1:B2-019', 'BM-I', 4, 'Rule 27', 'A vessel restricted in her ability to manoeuvre (RAM) shows:', '["Red-white-red in a vertical line","Red over red","Green over white","Three green lights"]'::jsonb, 0, 'Answer A. Rule 27: a RAM vessel shows three all-round lights in a vertical line — red, white, red (''red, white, red — restricted'').'),
  ('bm1:B2-020', 'BM-I', 4, 'Rule 30', 'A vessel at anchor of less than 50 m shows:', '["One all-round white light where best seen","Two all-round red lights","Sidelights","A masthead light"]'::jsonb, 0, 'Answer A. Rule 30: a vessel under 50 m at anchor shows one all-round white light where it can best be seen.'),
  ('bm1:B2-021', 'BM-I', 4, 'Rule 34', 'One short blast on the whistle means:', '["I am altering my course to starboard","I am altering my course to port","I am operating astern propulsion","I do not understand your intentions"]'::jsonb, 0, 'Answer A. Rule 34: one short blast = ''I am altering my course to starboard.'''),
  ('bm1:B2-022', 'BM-I', 4, 'Rule 34', 'Two short blasts mean:', '["I am altering to starboard","I am altering to port","Astern propulsion","Overtaking on your starboard side"]'::jsonb, 1, 'Answer B. Two short blasts = ''I am altering my course to port.'''),
  ('bm1:B2-023', 'BM-I', 4, 'Rule 34', 'Three short blasts mean:', '["I am operating astern propulsion","I am altering to port","I am altering to starboard","I am in distress"]'::jsonb, 0, 'Answer A. Three short blasts = ''I am operating astern propulsion'' (engines going astern).'),
  ('bm1:B2-024', 'BM-I', 4, 'Rule 34', 'Five or more short rapid blasts mean:', '["I am altering course","I am at anchor","I am in doubt whether you are taking sufficient action","I am overtaking"]'::jsonb, 2, 'Answer C. Five (or more) short rapid blasts is the doubt/wake-up signal: I am in doubt whether you are taking sufficient action to avoid collision.'),
  ('bm1:B2-025', 'BM-I', 4, 'Rule 35', 'A power-driven vessel making way in fog sounds, at intervals of not more than 2 minutes:', '["One prolonged blast","Two prolonged blasts","One prolonged plus three short","Five short"]'::jsonb, 0, 'Answer A. Rule 35: a power-driven vessel making way through the water sounds one prolonged blast every 2 minutes.'),
  ('bm1:B2-026', 'BM-I', 4, 'Rule 35', 'A power-driven vessel under way but stopped (not making way) in fog sounds:', '["One prolonged blast","Two prolonged blasts in succession every 2 minutes","Three short blasts","A bell"]'::jsonb, 1, 'Answer B. Rule 35: a vessel under way but stopped sounds two prolonged blasts in succession (about 2 s apart) every 2 minutes.'),
  ('bm1:B2-027', 'BM-I', 4, 'Rule 35', 'A vessel at anchor in fog (under 100 m) sounds:', '["A bell rung rapidly for about 5 seconds at intervals of not more than 1 minute","One prolonged blast","Two prolonged blasts","Three short blasts"]'::jsonb, 0, 'Answer A. Rule 35: a vessel at anchor rings the bell rapidly for about 5 seconds at intervals of not more than one minute.'),
  ('bm1:B2-028', 'BM-I', 4, 'B2.3', 'A proper lookout includes:', '["Watching the chart plotter only","Using sight, hearing, radar and all available means to assess collision risk and the situation","Listening to VHF only","Relying on the autopilot"]'::jsonb, 1, 'Answer B. A proper lookout (Rule 5) uses sight, hearing and all available means, including radar, to make a full appraisal of the situation and risk of collision.'),
  ('bm1:B2-029', 'BM-I', 4, 'B2.4', 'The deck log on a Grade 1 vessel is primarily a record of:', '["The crew''s wages only","Navigational and operational events — courses, positions, weather, incidents and key decisions","Fuel receipts only","Passenger meals"]'::jsonb, 1, 'Answer B. The deck log records the vessel''s navigation and operation — times, positions, courses, weather, drills and any incidents — and is legal evidence of how she was run.'),
  ('bm1:B2-030', 'BM-I', 4, 'B2.4', 'An entry should be made in the deck log:', '["Only at the end of the season","Contemporaneously, in ink, and not erased — corrections are struck through and initialled","In pencil so it can be changed","Only if an accident occurs"]'::jsonb, 1, 'Answer B. Log entries are made at the time, in ink; errors are ruled through and initialled, never erased, so the log remains reliable evidence.'),
  ('bm1:B4-001', 'BM-I', 5, 'B4.3', 'A vessel making slow headway is set sideways by a strong beam wind because:', '["The wind has no effect at slow speed","Reduced steerage and high windage let the wind push her bodily to leeward","The propeller pulls her to windward","The rudder over-corrects"]'::jsonb, 1, 'Answer B. At slow speed steerage is poor and windage dominates, so a beam wind sets the vessel bodily to leeward; allow for it when manoeuvring.'),
  ('bm1:B4-002', 'BM-I', 5, 'B4.2', '''Interaction'' between two vessels passing close at speed can cause:', '["No effect","The vessels to be drawn together or the smaller to sheer, especially in shallow water","The vessels to speed up","The compass to deviate"]'::jsonb, 1, 'Answer B. Pressure fields around hulls interact when passing close, drawing vessels together or causing a sheer; reduce speed and increase passing distance, especially in shallow water.'),
  ('bm1:B4-003', 'BM-I', 5, 'B4.4', 'Anchor cable should be stowed and the anchor secured so that:', '["It can run freely at any time","It cannot run out accidentally at sea and is ready to let go when needed","It is permanently lashed and unusable","It is left hanging over the bow"]'::jsonb, 1, 'Answer B. The anchor is secured against accidental release at sea (devil''s claw/lashing) but kept ready to let go quickly when required.'),
  ('bm1:B4-004', 'BM-I', 5, 'B4.5', 'A good anchorage offers:', '["Maximum tidal stream and exposure","Shelter, good holding ground, sufficient swinging room and adequate depth at all states of tide","Rocky bottom and deep water only","A position in the fairway"]'::jsonb, 1, 'Answer B. Choose shelter from wind/sea, good holding ground, enough depth at low water and swinging room clear of other vessels and dangers.'),
  ('bm1:B4-005', 'BM-I', 5, 'B4.6', 'Navigating at reduced speed past moored craft and shorelines matters because:', '["It saves fuel only","Your bow and stern wave (wash) can damage other craft, banks and people","Speed limits never apply at sea","Wash improves your handling"]'::jsonb, 1, 'Answer B. The master must reduce speed where wash from the bow/stern wave could cause damage or danger to others; it is both good seamanship and a legal duty.'),
  ('bm1:B4-006', 'BM-I', 5, 'B4.7', 'Compared with a single screw, a twin-screw vessel can:', '["Never turn in her own length","Turn in her own length using one engine ahead and the other astern","Only steer with the rudder","Not go astern"]'::jsonb, 1, 'Answer B. Twin screws give a turning couple — one ahead, one astern — letting the vessel turn in her own length without using the rudder.'),
  ('bm1:B4-007', 'BM-I', 5, 'B4.8', 'A key hazard when towing another vessel is:', '["The tow has no effect on handling","Girting and the loss of manoeuvrability; the towline can part under load","Towing makes you faster","The towline never chafes"]'::jsonb, 1, 'Answer B. Towing reduces manoeuvrability, risks girting (being pulled beam-on) and a parting line under load; rig a quick-release and tow at moderate, steady speed.'),
  ('bm1:B4-008', 'BM-I', 5, 'B4.1', 'In nautical terms, ''freeboard'' is the:', '["Width of the deck","Vertical distance from the waterline to the deck edge","Length of the keel","Height of the mast"]'::jsonb, 1, 'Answer B. Freeboard is the vertical distance from the waterline to the watertight deck edge — the vessel''s reserve buoyancy.'),
  ('bm1:A-001', 'BM-I', 6, 'A1.7', 'Transverse thrust (paddle-wheel effect) on a single right-handed fixed propeller is most pronounced when the engine is:', '["Idling ahead in deep water","Running ahead at cruising speed","Stopped with the rudder amidships","First put astern from rest, before the boat gathers sternway"]'::jsonb, 3, 'Answer D. Transverse thrust is strongest going astern from rest, before water flow over the rudder builds; a right-handed prop walks the stern to port.'),
  ('bm1:A-002', 'BM-I', 6, 'A1.7', 'A right-handed single screw (clockwise viewed from astern) is put astern from rest. The stern tends to walk to:', '["Whichever way the wind blows","Port","Starboard","Dead straight"]'::jsonb, 1, 'Answer B. A right-handed propeller going astern walks the stern to port and swings the bow to starboard.'),
  ('bm1:A-003', 'BM-I', 6, 'A1.6', 'To turn a single-screw vessel short round in its own length in confined water, the most effective method is to:', '["Use alternating short bursts ahead with hard-over rudder, and astern, exploiting prop wash and transverse thrust","Use full ahead with hard-over rudder only","Drift and let the wind turn her","Tow the bow round with the dinghy"]'::jsonb, 0, 'Answer A. Turning short round uses short bursts ahead against hard-over rudder to kick the stern, alternated with astern, using prop wash and transverse thrust.'),
  ('bm1:A-004', 'BM-I', 6, 'A1.1', 'When coming alongside a berth, the safest general approach is to:', '["Approach beam-on and let the fenders absorb the contact","Approach fast so she answers the helm and stop with a burst astern","Approach downwind and downtide for an easy stop","Approach slowly at a shallow angle, stemming the stronger of wind or tide to keep steerage at low speed"]'::jsonb, 3, 'Answer D. Approach slowly against the stronger of wind or tide so the boat is held back and steerage is retained; never approach faster than you are willing to hit the berth.'),
  ('bm1:A-005', 'BM-I', 6, 'A1.2', 'When weighing (recovering) the anchor, the helmsman should:', '["Drive ahead hard to break it out while the crew heaves","Motor gently up towards the anchor as the cable comes in so the crew never takes the boat''s weight","Go full astern to drag it out","Leave the engine in neutral throughout"]'::jsonb, 1, 'Answer B. The boat is motored gently up to the anchor to reduce strain; the windlass and crew should never take the full weight of the vessel.'),
  ('bm1:A-006', 'BM-I', 6, 'A1.3', 'To come alongside another vessel that is under way and making way, you should:', '["Take an opposite course, bow to bow","Match her course and speed and close gently, normally on her lee side","Match her course but at twice her speed","Match her speed only, ignoring her heading"]'::jsonb, 1, 'Answer B. Come alongside a moving vessel by matching course and speed and closing gently, normally on the lee (sheltered) side.'),
  ('bm1:A-007', 'BM-I', 6, 'A1.4', 'To make fast to a mooring buoy single-handed in a tideway, you should approach:', '["Beam-on at speed","Downtide so you arrive quickly","Heading into the stronger of wind or tide so it acts as a brake","From directly downwind only, ignoring tide"]'::jsonb, 2, 'Answer C. Approach a buoy stemming the stronger of wind or tide; it acts as a brake and lets you stop with the buoy at the bow.'),
  ('bm1:A-008', 'BM-I', 6, 'A1.5', 'When manoeuvring at low speed in a confined marina, the master should bear in mind that:', '["A boat with little way on answers the helm slowly and is more affected by wind and tide","Rudder is fully effective at all speeds","Wind has no effect below cruising speed","Transverse thrust disappears at low speed"]'::jsonb, 0, 'Answer A. At low speed the rudder is less effective and the vessel is more easily set by wind and tide; plan the approach and use short bursts of power for steerage.'),
  ('bm1:A-009', 'BM-I', 6, 'A1.8', 'Steering an accurate compass course means:', '["Following the GPS course-over-ground exactly with no compass","Pointing the bow at the destination and locking the wheel","Steering by the wake only","Holding the lubber line on the ordered compass figure and cross-checking with a transit or mark"]'::jsonb, 3, 'Answer D. Keep the compass card steady on the ordered course at the lubber line, cross-checking with a transit or fixed mark to detect set.'),
  ('bm1:A-010', 'BM-I', 6, 'A1.9', 'On VHF, the spoken word that precedes a DISTRESS call is:', '["SEELONCE","PAN-PAN","SECURITE","MAYDAY (spoken three times)"]'::jsonb, 3, 'Answer D. A distress call is preceded by MAYDAY spoken three times, used only when a vessel or person is in grave and imminent danger.'),
  ('bm1:A-011', 'BM-I', 6, 'A1.9', 'The VHF urgency signal, for an urgent message about safety but not grave and imminent danger, is:', '["SECURITE","PAN-PAN (spoken three times)","MAYDAY","MAYDAY RELAY"]'::jsonb, 1, 'Answer B. PAN-PAN (three times) is the urgency signal — a very urgent message concerning the safety of a vessel or person, short of grave danger.'),
  ('bm1:A-012', 'BM-I', 6, 'A1.9', 'The VHF safety signal SECURITE introduces:', '["A navigational or meteorological warning","A routine radio check","A distress message","A request to change channel"]'::jsonb, 0, 'Answer A. SECURITE (three times) introduces an important navigational or meteorological warning.'),
  ('bm1:A-013', 'BM-I', 6, 'A1.9', 'The international VHF distress, safety and calling channel is:', '["Channel 6","Channel 16","Channel 80","Channel 72"]'::jsonb, 1, 'Answer B. Channel 16 (156.8 MHz) is the international distress, safety and calling channel and must be monitored.'),
  ('bm1:A-014', 'BM-I', 6, 'A1.9', 'A DSC distress alert on VHF is normally transmitted on:', '["Channel 70","Channel 13","Channel 16","Channel 6"]'::jsonb, 0, 'Answer A. Digital Selective Calling distress alerts are sent on VHF Channel 70; voice distress traffic then follows on Channel 16.'),
  ('bm1:A-015', 'BM-I', 6, '1.2.3', 'Every person in charge of a vessel operating in EXPOSED waters must hold:', '["No radio qualification","A VHF short range certificate only","The GMDSS General Operator''s Certificate","A coastal skipper certificate only"]'::jsonb, 2, 'Answer C. SCV Code Annex 11-1.2.3 requires the GMDSS General Operator''s Certificate for the person in charge of a vessel operating in exposed waters.'),
  ('bm1:A-016', 'BM-I', 6, 'A1.9', 'A spoken MAYDAY message should include, in order:', '["Only the vessel''s name","MAYDAY and vessel name, position, nature of distress, assistance required, persons on board","The nature of distress only","The channel you wish to use"]'::jsonb, 1, 'Answer B. A MAYDAY gives: MAYDAY x3 and vessel name/identity, position, nature of distress, assistance required, number of persons on board and any other information.'),
  ('bm1:B11-001', 'BM-I', 7, 'B11.1', 'A daily pre-start engine check should include:', '["Only the fuel gauge","Oil and coolant levels, fuel, belts, water in the raw-water filter, and the battery state","Nothing if it ran yesterday","Only the paintwork"]'::jsonb, 1, 'Answer B. Daily checks cover lubricating-oil and coolant levels, fuel and water/sediment, belts, raw-water strainer and the batteries before starting.'),
  ('bm1:B11-002', 'BM-I', 7, 'B11.4', 'A running check while under way should include watching:', '["Only the speed","Oil pressure, coolant temperature, charging, exhaust colour and any unusual noise or vibration","The radio volume","The clock"]'::jsonb, 1, 'Answer B. Running checks monitor oil pressure, temperature, charging, exhaust note/colour and any abnormal noise or vibration so faults are caught early.'),
  ('bm1:B11-003', 'BM-I', 7, 'B11.3', 'An engine high-temperature alarm or shut-off device exists to:', '["Save fuel","Warn of, or prevent, damage from overheating before the engine is wrecked","Increase power","Charge the batteries"]'::jsonb, 1, 'Answer B. Safety and shut-off devices warn of, or stop the engine on, conditions such as overheating or low oil pressure to prevent serious damage.'),
  ('bm1:B11-004', 'BM-I', 7, 'B11.1', 'If the engine raw-water (cooling) telltale stops flowing, the likely first cause to check is:', '["A flat battery","A blocked raw-water intake/strainer or a failed impeller","The VHF aerial","The compass"]'::jsonb, 1, 'Answer B. Loss of cooling-water flow points to a blocked inlet/strainer or a failed raw-water pump impeller; stop the engine before it overheats.'),
  ('bm1:B11-005', 'BM-I', 7, 'B11.5', 'If the engine loses power and the exhaust shows black smoke, a reasonable diagnosis is:', '["Too much cooling water","Over-fuelling / restricted air (dirty air filter) or overload","The compass is wrong","Low battery only"]'::jsonb, 1, 'Answer B. Black smoke indicates incomplete combustion from over-fuelling, a restricted air supply (clogged filter) or overload; check air supply and loading.'),
  ('bm1:B11-006', 'BM-I', 7, 'B11.2', 'Routine servicing of the engine and auxiliaries should be carried out:', '["Only when it breaks down","According to the maker''s schedule (oil/filter changes, impellers, anodes) with records kept","Never, to save money","Only by the surveyor"]'::jsonb, 1, 'Answer B. Planned maintenance to the manufacturer''s schedule — oil and filter changes, impellers, anodes, belts — with records, keeps machinery reliable.'),
  ('bm1:B11-007', 'BM-I', 7, 'B11.1', 'Batteries should be checked for:', '["Colour only","Secure mounting, clean tight terminals, electrolyte level (if applicable) and state of charge","Weight only","Nothing"]'::jsonb, 1, 'Answer B. Battery checks cover secure stowage, clean/tight terminals, electrolyte level where serviceable and the state of charge.'),
  ('bm1:B1-001', 'BM-I', 8, 'B1.1', 'When recovering a man overboard under power, the engine should be:', '["Kept running ahead until the last second","Stopped (or clutch out) before the casualty is brought alongside, to remove propeller risk","Run astern throughout the approach","Left at cruising revs to maintain steerage"]'::jsonb, 1, 'Answer B. The propeller must be stopped before the casualty comes alongside; an exposed turning propeller can kill or injure a person in the water.'),
  ('bm1:B1-002', 'BM-I', 8, 'B1.1', 'The first action on seeing a person fall overboard is to:', '["Go below to fetch the first-aid kit","Shout ''man overboard'', throw a lifebuoy and post a pointer to keep the casualty in sight","Increase speed to circle quickly","Make a MAYDAY before anything else"]'::jsonb, 1, 'Answer B. Raise the alarm, throw buoyancy to the casualty, and detail a crew member to point at and never lose sight of the person; then manoeuvre back.'),
  ('bm1:B1-003', 'BM-I', 8, 'B1.2', 'On total loss of main engine in open water, the first priorities are to:', '["Abandon ship immediately","Assess drift/danger of grounding, anchor if practicable, and warn other traffic; attempt restart only when safe","Send a MAYDAY at once regardless of danger","Go below and start dismantling the engine"]'::jsonb, 1, 'Answer B. Loss of engines is not in itself a MAYDAY; assess the danger of drifting onto a hazard, anchor or signal as appropriate, and call for help according to the level of danger.'),
  ('bm1:B1-004', 'BM-I', 8, 'B1.3', 'On loss of steering, the master should first:', '["Stop the vessel if safe, warn the crew, and rig the emergency tiller or use engines to steer","Continue at full speed and hope it returns","Abandon ship","Disconnect the batteries"]'::jsonb, 0, 'Answer A. Reduce way, warn the crew, rig emergency steering (emergency tiller) and, on a twin-screw vessel, steer on the engines until repaired.'),
  ('bm1:B1-005', 'BM-I', 8, 'B1.4', 'Immediately after a collision the master should:', '["Reverse away from the other vessel at once","Account for all persons, assess damage and flooding, and stand by to render assistance","Leave the scene to avoid liability","Restart the engines and continue passage"]'::jsonb, 1, 'Answer B. Check for injuries and missing persons, assess your own and the other vessel''s damage/flooding, render assistance and exchange particulars; do not part company if it endangers life.'),
  ('bm1:B1-006', 'BM-I', 8, 'B1.5', 'After running aground, before attempting to refloat, the master should:', '["Immediately go full astern at maximum power","Check for injuries, sound the bilges for ingress, and assess the state of tide before deciding whether to refloat","Drop all anchors","Empty all fuel overboard"]'::jsonb, 1, 'Answer B. First check for casualties and hull damage/ingress and consider the tide; coming off may make flooding worse, so assess before acting.'),
  ('bm1:B1-007', 'BM-I', 8, 'B1.6', 'On a serious accident to a passenger, the master''s first duty is to:', '["Continue the trip as planned","Make the casualty safe, give first aid, and summon medical help/evacuation as required","Note it in the log later and carry on","Ask other passengers to handle it"]'::jsonb, 1, 'Answer B. Render first aid, prevent further harm, and call for medical assistance or arrange evacuation; the incident is then logged and reported.'),
  ('bm1:B1-008', 'BM-I', 8, 'B1.7', 'A fire involving flammable liquids (petrol, oil) is class:', '["Class A","Class B","Class C","Class D"]'::jsonb, 1, 'Answer B. Class B fires are flammable liquids; foam, dry powder or CO2 are suitable — never a water jet.'),
  ('bm1:B1-009', 'BM-I', 8, 'B1.7', 'The correct extinguisher for a live electrical fire is:', '["Water","Foam","CO2 or dry powder","Wet chemical"]'::jsonb, 2, 'Answer C. On live electrical equipment use a non-conductive medium — CO2 or dry powder — never water or foam.'),
  ('bm1:B1-010', 'BM-I', 8, 'B1.8', 'The ''fire triangle'' shows that to burn, a fire needs:', '["Heat, fuel and oxygen","Heat, smoke and water","Fuel, foam and oxygen","Spark, fuel and metal"]'::jsonb, 0, 'Answer A. Fire needs heat, fuel and oxygen; removing any one (cooling, starving or smothering) extinguishes it.'),
  ('bm1:B1-011', 'BM-I', 8, 'B1.9', 'Before launching a liferaft you must:', '["Inflate it on deck first","Make the painter fast to a strong point on the vessel, then throw the raft to leeward","Cut the painter immediately","Board it before inflation"]'::jsonb, 1, 'Answer B. Secure the painter to the ship, launch the raft to leeward, then sharply pull the painter to inflate before boarding.'),
  ('bm1:B1-012', 'BM-I', 8, 'B1.10', 'When searching for a casualty in reduced visibility, an effective method is to:', '["Steam in a straight line and hope","Use a systematic search pattern (e.g. expanding square) at slow safe speed with all lookouts posted","Switch off the radar to save power","Anchor and wait until visibility clears"]'::jsonb, 1, 'Answer B. A systematic pattern such as an expanding square, at safe slow speed with all available lookouts, gives the best chance of finding a casualty.'),
  ('bm1:B1-013', 'BM-I', 8, 'B1.11', 'If beaching is unavoidable to save life, the master should choose:', '["A steep rocky shore close to deep water","A gently shelving sheltered beach, head to sea, clear of rocks","Any shore downwind regardless of bottom","A harbour wall at speed"]'::jsonb, 1, 'Answer B. Choose a gently shelving, sheltered beach clear of rocks, approaching head to sea so the vessel does not broach.'),
  ('bm1:B1-014', 'BM-I', 8, 'B1.4', 'After a collision involving injury or potential pollution, the master must, as soon as practicable:', '["Say nothing to anyone","Report the casualty to the Coastguard/authorities and record the facts","Repair the damage before reporting","Wait until returning to home port"]'::jsonb, 1, 'Answer B. Serious casualties (injury, loss of life, pollution) must be reported to the authorities and the facts recorded in the log.'),
  ('bm1:B8-001', 'BM-I', 8, 'B8.1', 'A pre-departure passenger safety briefing (VIII/8) should cover:', '["The lunch menu","Location and use of lifejackets, emergency exits, and what to do in an emergency","Only the destination","The vessel''s fuel consumption"]'::jsonb, 1, 'Answer B. Regulation VIII/8 requires a safety announcement covering lifejackets, exits/muster and emergency procedures before departure.'),
  ('bm1:B8-002', 'BM-I', 8, 'B8.2', 'Passengers should be disposed about the vessel so as to:', '["Crowd one side for the view","Maintain the vessel''s stability and trim, avoiding overcrowding to one side","Sit anywhere with no regard to balance","All stand at the bow"]'::jsonb, 1, 'Answer B. The master arranges and, if needed, redistributes passengers to keep the vessel upright and properly trimmed; crowding to one side causes a dangerous list.'),
  ('bm1:B8-003', 'BM-I', 8, 'B8.3', 'The number of persons carried must:', '["Be whatever fits","Never exceed the maximum stated on the Safety Certificate, and be recorded/reported as required (VIII/7)","Be estimated by eye","Depend only on the weather"]'::jsonb, 1, 'Answer B. Passenger numbers must not exceed the certified maximum and must be counted, recorded and reported per VIII/7 — vital for headcount in an emergency.'),
  ('bm1:B8-004', 'BM-I', 8, 'B8.4', 'An orderly evacuation (VIII/10) depends most on:', '["Speed alone","A briefed crew, clear instructions, marked exits and a controlled, calm process suited to the vessel and area","Letting passengers self-organise","Switching off the lights"]'::jsonb, 1, 'Answer B. Orderly evacuation needs prepared crew, clear emergency instructions, accessible exits and a controlled process appropriate to the vessel''s size and operating area.'),
  ('bm1:B8-005', 'BM-I', 8, 'B8.5', 'Demonstrating a lifejacket to passengers should include:', '["Only telling them where it is","How to don and secure it, and how to operate the light/whistle","A long technical lecture","Nothing — they will work it out"]'::jsonb, 1, 'Answer B. The crew must be able to show passengers how to put on and secure a lifejacket and operate its light and whistle.'),
  ('bm1:B13-001', 'BM-I', 9, 'B13.3', 'Under MARPOL, the discharge into the sea of plastics, synthetic ropes and garbage bags is:', '["Permitted beyond 12 miles","Prohibited everywhere","Permitted at night","Permitted in port only"]'::jsonb, 1, 'Answer B. The disposal of all plastics into the sea is prohibited anywhere; they must be retained on board and landed ashore.'),
  ('bm1:B13-002', 'BM-I', 9, 'B13.2', 'When pumping bilges or changing lubricating oil, the master must ensure that:', '["Any oil goes straight over the side","No oil or oily water is discharged into the sea; oil/oily waste is retained and landed ashore","It is done at sea only","It is done quickly without care"]'::jsonb, 1, 'Answer B. Bilge water and waste oil must not be discharged; an oily-water separator or retention and landing ashore prevents oil pollution.'),
  ('bm1:B13-003', 'BM-I', 9, 'B13.1', 'A general appreciation of the pollution regulations requires the master to prevent the discharge of:', '["Only oil","Oil, garbage, sewage and other harmful substances, within the rules for the area","Nothing — the sea dilutes everything","Only plastics"]'::jsonb, 1, 'Answer B. MARPOL covers oil, noxious liquids, sewage, garbage and air pollution; the master must prevent unlawful discharge of all of these.'),
  ('bm1:B13-004', 'BM-I', 9, 'B13.2', 'To prevent fuel/oil spills during bunkering, the master should:', '["Fill quickly and walk away","Stop scuppers/use a drip tray, monitor the transfer, avoid overfilling and have spill kit ready","Overfill to be sure it is full","Bunker while under way at speed"]'::jsonb, 1, 'Answer B. Block deck scuppers, use drip trays, watch the level to avoid overflow and keep an oil-spill kit ready to contain any spill.'),
  ('bm1:B13-005', 'BM-I', 9, 'B13.3', 'Annoyed by floating litter, a crew member wishes to throw a torn plastic fender over the side. The master should:', '["Allow it — it is only one item","Refuse — disposal of plastics at sea is prohibited; retain it for disposal ashore","Allow it if more than 3 miles out","Allow it at night"]'::jsonb, 1, 'Answer B. All plastics, including damaged gear, must be retained on board and disposed of ashore; throwing any plastic overboard is prohibited.'),
  ('bm1:B6-001', 'BM-I', 11, 'B6.1', 'The person in charge of the vessel is responsible for ensuring that:', '["LSA and FFA are only checked at survey time","The life-saving and fire-fighting appliances are properly maintained and ready for use","The crew buy their own equipment","Equipment is landed ashore when not in use"]'::jsonb, 1, 'Answer B. Annex 11-B6.1: the master must be satisfied that the statutory life-saving and fire-fighting appliances are properly maintained and serviceable.'),
  ('bm1:B6-002', 'BM-I', 11, 'B6.2', 'A throw-over (non-davit) inflatable liferaft is launched by:', '["Lifting it over the side by hand fully inflated","Securing the painter, releasing it from its cradle and throwing it overboard to leeward, then jerking the painter to inflate","Cutting all lashings and leaving it","Inflating it on deck and walking it over"]'::jsonb, 1, 'Answer B. Secure the painter to the ship, release and throw the canister to leeward, then sharply pull the painter to fire the inflation bottle before boarding.'),
  ('bm1:B6-003', 'BM-I', 11, 'B6.3', 'Inflatable liferafts must be serviced:', '["Never, once installed","At an approved service station at the intervals required by the manufacturer/Administration (typically annually)","Only by the crew at sea","Every five years only"]'::jsonb, 1, 'Answer B. Liferafts (and inflatable boats) must be serviced at an approved station at the required intervals so the inflation system and equipment remain reliable.'),
  ('bm1:B6-004', 'BM-I', 11, 'B6.4', 'A hydrostatic release unit (HRU) is fitted to a liferaft so that:', '["It deflates the raft automatically","If the vessel sinks, water pressure releases the raft, which floats free and inflates","It locks the raft permanently in its cradle","It heats the raft"]'::jsonb, 1, 'Answer B. The HRU releases the lashing at a set depth (about 4 m) if the vessel founders, so the raft floats free, the painter comes taut and the raft inflates.'),
  ('bm1:B6-005', 'BM-I', 11, 'B6.4', 'A hydrostatic release unit must be checked because:', '["It never expires","It has an expiry date and must be replaced when it lapses","It is purely decorative","It works without water"]'::jsonb, 1, 'Answer B. HRUs carry an expiry date and must be renewed; an out-of-date unit may fail to release the raft when the vessel sinks.'),
  ('bm1:B6-006', 'BM-I', 11, 'B6.5', 'Buoyant apparatus and lifebuoys should be:', '["Painted over for appearance","Maintained, kept accessible, with lights/lines serviceable and ready for instant use","Stowed below in a locker","Used as fenders"]'::jsonb, 1, 'Answer B. Buoyant apparatus and lifebuoys are kept accessible and ready, with attached lights and lines serviceable, and inspected as part of routine maintenance.'),
  ('bm1:B6-007', 'BM-I', 11, 'B6.1', 'A fire extinguisher should be checked to confirm that:', '["It is the right colour only","It is in date, the gauge (if fitted) reads in the green/charged band, the seal is intact and it is correctly stowed","It is heavy","It has been used recently"]'::jsonb, 1, 'Answer B. Routine checks confirm the extinguisher is in date and charged (gauge in green where fitted), seal intact, accessible and of the correct type for the risk.'),
  ('bm1:B7-001', 'BM-I', 11, 'B7.1', 'Which of the following is a recognised distress signal under COLREG Annex IV?', '["A single white flare","A continuous sounding of the fog horn / a gun fired at intervals","Switching off all lights","Hoisting a yellow flag"]'::jsonb, 1, 'Answer B. Annex IV distress signals include continuous sounding of a fog apparatus, a gun fired at intervals of about a minute, red flares, the SOS signal and MAYDAY by radio.'),
  ('bm1:B7-002', 'BM-I', 11, 'B7.1', 'A red parachute or red hand flare indicates:', '["A request to pass to port","Distress — a vessel or person needs assistance","All clear","A diving operation"]'::jsonb, 1, 'Answer B. Red flares (parachute and hand) are distress signals under Annex IV; orange smoke is the daytime equivalent.'),
  ('bm1:B7-003', 'BM-I', 11, 'B7.1', 'The signal of raising and lowering outstretched arms slowly and repeatedly means:', '["Greeting another vessel","Distress — I need assistance","Man overboard recovered","Reduce speed"]'::jsonb, 1, 'Answer B. Slowly and repeatedly raising and lowering outstretched arms is a recognised distress signal under Annex IV.'),
  ('bm1:B7-004', 'BM-I', 11, 'B7.2', 'On receiving a distress alert, the Coast Guard / MRCC will:', '["Ignore it unless it is repeated","Acknowledge, coordinate the search and rescue response and task assets","Charge the vessel a fee first","Wait for daylight"]'::jsonb, 1, 'Answer B. The Coast Guard / Maritime Rescue Coordination Centre acknowledges the distress, gathers information and coordinates the SAR response.'),
  ('bm1:B7-005', 'BM-I', 11, 'B7.3', 'To aid your location by rescuers you should:', '["Switch everything off and wait quietly","Use all available means — EPIRB, SART, flares, VHF/DSC, lights and any visual/sound signals","Throw the flares away","Steer away from rescuers to avoid collision"]'::jsonb, 1, 'Answer B. Use every aid to location: EPIRB/PLB, radar SART, DSC/VHF, flares and smoke, lights and reflective material, to help searchers find you quickly.'),
  ('bm1:B7-006', 'BM-I', 11, 'B7.4', 'Before abandoning ship the master should, if time allows:', '["Nothing — just jump","Send/confirm a distress message and position, don lifejackets, take the grab bag/EPIRB and board the raft dry if possible","Open the seacocks first","Leave the EPIRB behind"]'::jsonb, 1, 'Answer B. Make/confirm the distress message with position, get lifejackets on, take the EPIRB and grab bag, and try to step up into the raft rather than into the water.'),
  ('bm1:B18-001', 'BM-I', 12, 'B18.1', 'The first-aid kit on board must be:', '["Whatever the crew bring","Of the required contents, in date, accessible and known to the crew","Kept locked away from everyone","Used only by a doctor"]'::jsonb, 1, 'Answer B. The kit must hold the required, in-date contents, be readily accessible and the crew must know its location and how to use the items.'),
  ('bm1:B18-002', 'BM-I', 12, 'B18.1', 'The instructions/guidance in the first-aid kit are provided so that:', '["They can be discarded","Whoever uses the kit can apply the correct treatment for common injuries","They look professional","They replace calling for help"]'::jsonb, 1, 'Answer B. The kit''s instructions guide correct use for common injuries; serious cases still require radio medical advice and evacuation.'),
  ('bm1:B18-003', 'BM-I', 12, 'B18.1', 'After using items from the first-aid kit, the master should:', '["Leave it empty","Restock the used items and check expiry dates so the kit is ready for the next emergency","Throw the kit away","Hide the shortage"]'::jsonb, 1, 'Answer B. Used items are replaced and expiry dates checked so the kit remains complete and serviceable for the next incident.'),
  ('bm1:B15-001', 'BM-I', 13, 'B15.1', 'The Caribbean Netherlands lies in IALA Region B. Entering harbour from seaward, you leave:', '["Red to port, green to starboard","Red to starboard, green to port (''red-right-returning'')","Red and green on either side","All marks to starboard"]'::jsonb, 1, 'Answer B. In Region B, entering from seaward, red lateral marks are kept to starboard and green to port — ''red-right-returning.'''),
  ('bm1:B15-002', 'BM-I', 13, 'B15.1', 'A north cardinal mark tells you that:', '["Safe water is to the south","Safe water lies to the north of the mark — pass to the north","It marks safe water all round","It is a special mark"]'::jsonb, 1, 'Answer B. A north cardinal mark indicates the safe water is to its north; you pass to the north of it. Its topmarks are two cones pointing up.'),
  ('bm1:B15-003', 'BM-I', 13, 'B15.1', 'An isolated danger mark is:', '["Yellow with an X topmark","Black with one or more red horizontal bands and two black spheres as a topmark","Red and white vertical stripes","Green with a cone topmark"]'::jsonb, 1, 'Answer B. An isolated danger mark is black with red band(s) and a topmark of two black balls; it marks a danger with navigable water all round.'),
  ('bm1:B15-004', 'BM-I', 13, 'B15.1', 'A safe-water (fairway/landfall) mark is:', '["Black and yellow","Red and white vertical stripes, often with a single red spherical topmark","All green","All yellow"]'::jsonb, 1, 'Answer B. A safe-water mark has red and white vertical stripes with a red sphere topmark, indicating navigable water all round (mid-channel or landfall).'),
  ('bm1:B15-005', 'BM-I', 13, 'B15.1', 'A yellow buoy with an X (St Andrew''s cross) topmark is a:', '["Port lateral mark","Special mark indicating an area or feature (e.g. a restricted/marine-park zone)","Cardinal mark","Isolated danger mark"]'::jsonb, 1, 'Answer B. A special mark is yellow with an X topmark and a yellow light; it marks a special area or feature, not primarily a navigational danger.'),
  ('bm1:B15-006', 'BM-I', 13, 'B15.1', 'In the Bonaire National Marine Park, the master must:', '["Anchor anywhere on the reef","Use the designated moorings and observe no-anchor and protected zones","Ignore the zones offshore","Anchor only at night"]'::jsonb, 1, 'Answer B. Local restrictions require use of designated moorings and respect for no-anchor and protected zones to avoid damaging the reef; the master knows and obeys them.'),
  ('bm1:B15-007', 'BM-I', 13, 'B15.1', 'Cardinal marks are coloured and lit so that:', '["All look identical","Their black/yellow colours and quick/very-quick white light codes show which quarter is safe","They never show a light","They are red and green"]'::jsonb, 1, 'Answer B. Cardinal marks use black and yellow bands and distinctive quick/very-quick white flash groups keyed to N, E, S or W to show the safe side.'),
  ('bm1:B17-001', 'BM-I', 13, 'B17.1', 'Ship''s plans carried on board (where provided) help the master to:', '["Decorate the saloon","Understand the structure, tanks, watertight boundaries and systems for safe operation and damage control","Sell the vessel","Replace the chart"]'::jsonb, 1, 'Answer B. General arrangement and related plans show structure, tanks, watertight divisions and systems, supporting loading, maintenance and damage-control decisions.'),
  ('bm1:B17-002', 'BM-I', 13, 'B17.2', 'Watertight subdivision protects the vessel by:', '["Making her faster","Confining flooding to one compartment so the vessel can survive a breach","Reducing fuel use","Improving the view"]'::jsonb, 1, 'Answer B. Bulkheads divide the hull so that flooding from a breach is contained in one compartment, preserving buoyancy and stability.'),
  ('bm1:B17-003', 'BM-I', 13, 'B17.2', 'Watertight doors and hatches at sea should be:', '["Left open for ventilation","Kept closed (or as the stability information requires) so subdivision is maintained","Removed","Wedged open"]'::jsonb, 1, 'Answer B. Watertight closures are kept shut at sea so that, if the hull is breached, the subdivision actually contains the flooding.'),
  ('bm1:B17-004', 'BM-I', 13, 'B17.3', 'The bilge pumping arrangement is provided to:', '["Supply drinking water","Remove water that enters the hull and help control minor flooding","Cool the engine","Trim the vessel by the bow"]'::jsonb, 1, 'Answer B. Bilge pumps remove accumulated or ingressed water; keeping the system and strainers clear is essential for controlling flooding.'),
  ('bm1:B17-005', 'BM-I', 13, 'B17.4', 'A vessel has positive transverse (initial) stability when:', '["The centre of gravity G is above the metacentre M","The metacentre M is above the centre of gravity G, giving a positive GM and a righting lever when heeled","G and M coincide","She has no freeboard"]'::jsonb, 1, 'Answer B. With M above G (positive GM) a heeled vessel develops a righting lever GZ that returns her upright; if G rises above M she is unstable.'),
  ('bm1:B17-006', 'BM-I', 13, 'B17.4', 'Metacentric height (GM) is:', '["The height of the mast","The vertical distance between the centre of gravity G and the metacentre M, a measure of initial stiffness","The freeboard","The draught"]'::jsonb, 1, 'Answer B. GM is the distance from G to M; a larger positive GM gives a stiffer (more quickly righting) vessel, a small GM a tender one.'),
  ('bm1:B17-007', 'BM-I', 13, 'B17.4', 'The righting lever GZ is:', '["The length of the keel","The horizontal distance between the lines of buoyancy and gravity at a given heel, giving the righting moment","Always zero","The same as GM at all angles"]'::jsonb, 1, 'Answer B. GZ is the horizontal separation of the weight (through G) and buoyancy (through B) forces when heeled; righting moment = displacement x GZ.'),
  ('bm1:B17-008', 'BM-I', 13, 'B17.5', 'Raising weights high in the vessel (e.g. on deck or aloft) will:', '["Lower G and increase stability","Raise G, reduce GM and make the vessel more tender","Have no effect","Increase freeboard"]'::jsonb, 1, 'Answer B. Adding weight high raises the centre of gravity G, reducing GM and making the vessel roll more slowly and heel more easily — more tender.'),
  ('bm1:B17-009', 'BM-I', 13, 'B17.6', 'Wind heeling force on a vessel increases with:', '["Lower freeboard only","The projected (side) area exposed to the wind and the square of the wind speed","Engine power","The number of anchors"]'::jsonb, 1, 'Answer B. Wind pressure acts on the projected side area; the heeling force rises with that area and roughly with the square of wind speed.'),
  ('bm1:B17-010', 'BM-I', 13, 'B17.7', 'Asymmetric loading (more weight to one side) causes:', '["A bodily sinkage only","A list (steady heel) to the loaded side, reducing stability on that side","Increased speed","No change in trim"]'::jsonb, 1, 'Answer B. Loading more to one side shifts G off the centreline, producing a list; it reduces the effective range of stability and freeboard on that side.'),
  ('bm1:B17-011', 'BM-I', 13, 'B17.8', 'Mooring lines led overtight where there is a large tidal range can:', '["Improve stability","Heel or even capsize the vessel, or part the lines, as the water level changes","Save fuel","Have no effect"]'::jsonb, 1, 'Answer B. Overtight moorings cannot accommodate the rise and fall of tide; as the level changes they can heel/pull down the vessel or part suddenly.'),
  ('bm1:B17-012', 'BM-I', 13, 'B17.9', 'The angle of equilibrium (steady heel under a heeling force) is where:', '["The vessel capsizes","The righting moment exactly balances the heeling moment","GM is zero","The engine stops"]'::jsonb, 1, 'Answer B. A vessel settles at the heel angle where its righting moment equals the applied heeling moment; a tender vessel settles at a larger angle.'),
  ('bm1:B17-013', 'BM-I', 13, 'B17.10', 'Dynamic stability (the area under the GZ curve) represents the vessel''s:', '["Top speed","Ability to absorb the energy of a gust or wave without capsizing","Fuel capacity","Freeboard"]'::jsonb, 1, 'Answer B. Dynamic stability is the energy the vessel can absorb before capsizing — the area under the righting-lever (GZ) curve; rolling and gusts test it.'),
  ('bm1:B17-014', 'BM-I', 13, 'B17.11', 'Free-surface effect (liquid free to move in a partly filled tank or flooded space) acts to:', '["Lower G and increase stability","Effectively raise G and reduce GM, worsening any heel","Increase freeboard","Have no effect at sea"]'::jsonb, 1, 'Answer B. A free liquid surface shifts to the low side as the vessel heels, effectively raising G and reducing GM; subdividing tanks and keeping them pressed up or empty limits it.'),
  ('bm1:B17-015', 'BM-I', 13, 'B17.11', 'Free-surface effect is best controlled by:', '["Filling tanks half full","Keeping tanks either pressed full or empty, fitting baffles/subdivision, and pumping out flooded spaces promptly","Leaving bilges flooded","Adding more free liquid"]'::jsonb, 1, 'Answer B. Pressed-up or empty tanks have no free surface; baffles/subdivision reduce the effect, and flooded spaces should be pumped out quickly.'),
  ('bm1:B17-016', 'BM-I', 13, 'B17.12', 'Operating a deck crane/davit safely requires that:', '["The load may exceed the SWL briefly","The Safe Working Load is never exceeded, and the heeling effect of a suspended load is allowed for","The crane is used at any angle","Stability is ignored"]'::jsonb, 1, 'Answer B. Never exceed the crane''s Safe Working Load; a suspended load acts high up and to one side, heeling the vessel — allow for it in stability terms.'),
  ('bm1:B17-017', 'BM-I', 13, 'B17.13', 'Adequate freeboard is important because it provides:', '["A place to sit","Reserve buoyancy and a margin against shipping water on deck","Faster speed","Lower fuel use"]'::jsonb, 1, 'Answer B. Freeboard is reserve buoyancy and the margin before the deck edge immerses; overloading reduces it and the safety it provides.'),
  ('bm1:B17-018', 'BM-I', 13, 'B17.13', 'Correct fore-and-aft trim is important because:', '["It only affects appearance","Bad trim degrades handling, sea-keeping and freeboard and can bury the bow in a head sea","It increases the certified number of passengers","It changes the variation"]'::jsonb, 1, 'Answer B. Trim is the difference between forward and after draughts; poor trim from bad loading worsens handling, sea-keeping and freeboard.'),
  ('bm1:B17-019', 'BM-I', 13, 'B17.14', 'The vessel''s stability and hydrostatic data should be used by the master to:', '["Guess the loading","Load and operate within the approved limits — persons, weights and conditions — rather than by eye","Decorate the wheelhouse","Set the radar range"]'::jsonb, 1, 'Answer B. The approved stability information (from the inclining test and calculations) tells the master how to load and operate safely; he works within it, not by guesswork.'),
  ('bm1:B17-020', 'BM-I', 13, 'B17.15', 'In a following or quartering sea, a danger to stability is that the vessel may:', '["Become more stable","Be pooped or broach, and lose stability as a wave crest passes amidships","Speed up safely","Stop rolling"]'::jsonb, 1, 'Answer B. In following/quartering seas the vessel can broach or be pooped, and a crest amidships reduces waterplane and stability; reduce speed and adjust heading.'),
  ('bm1:B17-021', 'BM-I', 13, 'B17.16', 'The maximum number of persons and load stated on the certificate must:', '["Be treated as a target to beat","Never be exceeded, as it is the basis of the vessel''s stability and safety","Be ignored in calm weather","Apply only at night"]'::jsonb, 1, 'Answer B. The certified persons and load underpin the vessel''s stability; exceeding them reduces freeboard and stability and is unlawful and dangerous.'),
  ('bm1:B17-022', 'BM-I', 13, 'B17.17', 'Before entering an enclosed or confined space (e.g. a tank or void), the master must:', '["Enter quickly to save time","Treat it as potentially lethal — test/ventilate the atmosphere, use a permit, post a watch and have rescue arrangements ready","Light a match to check for gas","Send the smallest crew member alone"]'::jsonb, 1, 'Answer B. Enclosed spaces may be oxygen-deficient or toxic; test and ventilate, use a permit-to-work, post an attendant and prepare rescue before any entry.'),
  ('bm1:B17-023', 'BM-I', 13, 'B17.18', 'When carrying small quantities of dangerous goods, the master should:', '["Stow them anywhere convenient","Know the hazards, stow and segregate them correctly, secure them and keep ignition sources clear","Carry them in the accommodation","Ignore the labels"]'::jsonb, 1, 'Answer B. Dangerous goods must be identified, correctly stowed, segregated and secured away from ignition/heat, with the master aware of the hazards and emergency action.')
on conflict (id) do update set
  course_code = excluded.course_code,
  module_seq  = excluded.module_seq,
  ref         = excluded.ref,
  stem        = excluded.stem,
  opts        = excluded.opts,
  correct     = excluded.correct,
  expl        = excluded.expl;

-- ---- Module-content (reader/deck-paden + gecureerde quizlijst) ----
-- Storage-paden in bucket 'course-content'. Volgnummer = modules.sequence.

update modules m set
  reader_path = 'bm1/readers/M01.pdf',
  deck_path   = 'bm1/decks/M01.pdf',
  quiz_ids    = '["bm1:A-015","bm1:B2-029","bm1:B3-003","bm1:B3-004","bm1:B6-001","bm1:B14-005"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-I' and m.sequence = 1;
update modules m set
  reader_path = 'bm1/readers/M02.pdf',
  deck_path   = 'bm1/decks/M02.pdf',
  quiz_ids    = '["bm1:B12-001","bm1:B12-002","bm1:B12-003","bm1:B16-001","bm1:B16-002","bm1:B16-003","bm1:B16-004","bm1:B16-005","bm1:B16-006","bm1:B16-007","bm1:B16-008","bm1:B3-001","bm1:B3-002","bm1:B3-003","bm1:B3-004","bm1:B9-001","bm1:B9-002","bm1:B9-003","bm1:B9-004"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-I' and m.sequence = 2;
update modules m set
  reader_path = 'bm1/readers/M03.pdf',
  deck_path   = 'bm1/decks/M03.pdf',
  quiz_ids    = '["bm1:B10-001","bm1:B10-002","bm1:B10-003","bm1:B10-004","bm1:B10-005","bm1:B14-001","bm1:B14-002","bm1:B14-003","bm1:B14-004","bm1:B14-005","bm1:B14-006","bm1:B14-007","bm1:B5-001","bm1:B5-002","bm1:B5-003","bm1:B5-004","bm1:B5-005","bm1:B5-006","bm1:B5-007","bm1:B5-008","bm1:B5-009","bm1:B5-010","bm1:B5-011","bm1:B5-012","bm1:B5-013","bm1:B5-014","bm1:B5-015","bm1:B5-016","bm1:B5-017","bm1:B5-018","bm1:B5-019"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-I' and m.sequence = 3;
update modules m set
  reader_path = 'bm1/readers/M04.pdf',
  deck_path   = 'bm1/decks/M04.pdf',
  quiz_ids    = '["bm1:B2-001","bm1:B2-002","bm1:B2-003","bm1:B2-004","bm1:B2-005","bm1:B2-006","bm1:B2-007","bm1:B2-008","bm1:B2-009","bm1:B2-010","bm1:B2-011","bm1:B2-012","bm1:B2-013","bm1:B2-014","bm1:B2-015","bm1:B2-016","bm1:B2-017","bm1:B2-018","bm1:B2-019","bm1:B2-020","bm1:B2-021","bm1:B2-022","bm1:B2-023","bm1:B2-024","bm1:B2-025","bm1:B2-026","bm1:B2-027","bm1:B2-028","bm1:B2-029","bm1:B2-030"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-I' and m.sequence = 4;
update modules m set
  reader_path = 'bm1/readers/M05.pdf',
  deck_path   = 'bm1/decks/M05.pdf',
  quiz_ids    = '["bm1:B4-001","bm1:B4-002","bm1:B4-003","bm1:B4-004","bm1:B4-005","bm1:B4-006","bm1:B4-007","bm1:B4-008"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-I' and m.sequence = 5;
update modules m set
  reader_path = 'bm1/readers/M06.pdf',
  deck_path   = 'bm1/decks/M06.pdf',
  quiz_ids    = '["bm1:A-001","bm1:A-002","bm1:A-003","bm1:A-004","bm1:A-005","bm1:A-006","bm1:A-007","bm1:A-008","bm1:A-009","bm1:A-010","bm1:A-011","bm1:A-012","bm1:A-013","bm1:A-014","bm1:A-015","bm1:A-016"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-I' and m.sequence = 6;
update modules m set
  reader_path = 'bm1/readers/M07.pdf',
  deck_path   = 'bm1/decks/M07.pdf',
  quiz_ids    = '["bm1:B11-001","bm1:B11-002","bm1:B11-003","bm1:B11-004","bm1:B11-005","bm1:B11-006","bm1:B11-007"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-I' and m.sequence = 7;
update modules m set
  reader_path = 'bm1/readers/M08.pdf',
  deck_path   = 'bm1/decks/M08.pdf',
  quiz_ids    = '["bm1:B1-001","bm1:B1-002","bm1:B1-003","bm1:B1-004","bm1:B1-005","bm1:B1-006","bm1:B1-007","bm1:B1-008","bm1:B1-009","bm1:B1-010","bm1:B1-011","bm1:B1-012","bm1:B1-013","bm1:B1-014","bm1:B8-001","bm1:B8-002","bm1:B8-003","bm1:B8-004","bm1:B8-005"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-I' and m.sequence = 8;
update modules m set
  reader_path = 'bm1/readers/M09.pdf',
  deck_path   = 'bm1/decks/M09.pdf',
  quiz_ids    = '["bm1:B13-001","bm1:B13-002","bm1:B13-003","bm1:B13-004","bm1:B13-005"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-I' and m.sequence = 9;
update modules m set
  reader_path = 'bm1/readers/M10.pdf',
  deck_path   = 'bm1/decks/M10.pdf',
  quiz_ids    = '["bm1:B1-008","bm1:B1-009","bm1:B1-010","bm1:B6-001","bm1:B6-002","bm1:B6-007","bm1:B7-001","bm1:B11-005"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-I' and m.sequence = 10;
update modules m set
  reader_path = 'bm1/readers/M11.pdf',
  deck_path   = 'bm1/decks/M11.pdf',
  quiz_ids    = '["bm1:B6-001","bm1:B6-002","bm1:B6-003","bm1:B6-004","bm1:B6-005","bm1:B6-006","bm1:B6-007","bm1:B7-001","bm1:B7-002","bm1:B7-003","bm1:B7-004","bm1:B7-005","bm1:B7-006"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-I' and m.sequence = 11;
update modules m set
  reader_path = 'bm1/readers/M12.pdf',
  deck_path   = 'bm1/decks/M12.pdf',
  quiz_ids    = '["bm1:B18-001","bm1:B18-002","bm1:B18-003","bm1:B1-001","bm1:B1-002","bm1:B1-006","bm1:B1-007","bm1:B1-010"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-I' and m.sequence = 12;
update modules m set
  reader_path = 'bm1/readers/M13.pdf',
  deck_path   = 'bm1/decks/M13.pdf',
  quiz_ids    = '["bm1:B15-001","bm1:B15-002","bm1:B15-003","bm1:B15-004","bm1:B15-005","bm1:B15-006","bm1:B15-007","bm1:B17-001","bm1:B17-002","bm1:B17-003","bm1:B17-004","bm1:B17-005","bm1:B17-006","bm1:B17-007","bm1:B17-008","bm1:B17-009","bm1:B17-010","bm1:B17-011","bm1:B17-012","bm1:B17-013","bm1:B17-014","bm1:B17-015","bm1:B17-016","bm1:B17-017","bm1:B17-018","bm1:B17-019","bm1:B17-020","bm1:B17-021","bm1:B17-022","bm1:B17-023"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-I' and m.sequence = 13;

-- Klaar.

-- ============================================================
-- Plaza Boat College — Seed e-learning BM II
-- AUTOGEGENEREERD door scripts/gen-seed.mjs — niet handmatig bewerken.
-- Bron: data.js  ·  156 vragen
-- Idempotent: on conflict (id) do update. Voer uit NA migrations/0002_elearning.sql.
-- ============================================================

-- ---- Vragenbank (BM II) ----
insert into questions (id, course_code, module_seq, ref, stem, opts, correct, expl) values
  ('bm2:B3-001', 'BM-II', 2, 'B3.1', 'In the event of a death on board, the boatmaster must:', '["Tell only the owner","Bury the body at sea at once","Continue normally and report on return next month","Preserve the scene as far as possible, notify the authorities/Coast Guard, and make a full record in the log"]'::jsonb, 3, 'Answer D. A death must be reported to the authorities without delay, the scene preserved where possible, and full entries made in the deck log.'),
  ('bm2:B3-002', 'BM-II', 2, 'B3.1', 'After a serious injury to a passenger, beyond immediate first aid the boatmaster must:', '["Say nothing to avoid liability","Wait until the next inspection","Record the facts, report the casualty to the relevant authority, and cooperate with any investigation","Delete the log entry"]'::jsonb, 2, 'Answer C. Injuries to seafarers/passengers must be recorded and reported to the competent authority; honest records support investigation and safety improvement.'),
  ('bm2:B3-003', 'BM-II', 2, 'B3.2', 'Which document certifies that a Small Commercial Vessel meets the SCV Code construction and equipment standards?', '["The VHF licence","The deck log","The crew list","The SCV Safety Certificate"]'::jsonb, 3, 'Answer D. The SCV Safety Certificate (Reg. I/15) shows the vessel complies with the Code''s construction, stability and equipment requirements.'),
  ('bm2:B3-004', 'BM-II', 2, 'B3.3', 'A Grade 2 boatmaster''s operational limits are primarily set by:', '["The owner''s instructions alone","The grade and area restrictions on the licence and the vessel''s certificate (waters, size, passenger numbers)","Personal preference","The weather only"]'::jsonb, 1, 'Answer B. Operation is bounded by the licence grade/area endorsements (Table X/5.2) and the vessel''s certificate limits — waters, size and passenger numbers.'),
  ('bm2:B3-005', 'BM-II', 2, 'X/5.2', 'Under Table X/5.2, a Grade 2 licence is the minimum grade for which of these?', '["A 12–24 m passenger vessel in coastal waters","A vessel under 24 m in protected waters and under 24 m (non-passenger) in coastal waters","All vessels in exposed waters","An open boat in protected waters by day"]'::jsonb, 1, 'Answer B. Grade 2 is minimum for <24 m in protected waters, <12 m passenger and <24 m non-passenger in coastal waters; 12–24 m passenger/coastal and exposed need Grade 1.'),
  ('bm2:B3-006', 'BM-II', 2, 'X/6.2', 'Which of the following is NOT one of the requirements to obtain a Boatmaster Licence Grade 2?', '["Have at least 4 months approved seagoing service","Have completed approved practical instruction","Be 20 years of age or over","Hold a valid medical certificate"]'::jsonb, 0, 'Answer A. Grade 2 requires 2 months approved seagoing service (X/6.2.4); 4 months is the Grade 1 requirement.'),
  ('bm2:B3-007', 'BM-II', 2, 'X/13', 'A Boatmaster Licence (holder under 63) is subject to re-validation:', '["Every year","Every five years","Only once for life","Every three years, with proof of at least 45 days'' service and a valid medical"]'::jsonb, 3, 'Answer D. X/13.1: re-validation every three years for under-63s, needing at least 45 days'' service in the period and a current medical certificate.'),
  ('bm2:B3-008', 'BM-II', 2, 'X/8.1', 'The Grade 2 boatmaster examination under SCV Code X/8.1 consists of:', '["A written paper only","A practical test only","An oral examination plus a practical test on a vessel of the size for which the licence is needed","Three separate written papers"]'::jsonb, 2, 'Answer C. X/8.1: the Grade 2 exam is in two parts — an oral examination and a practical handling test on a vessel of the appropriate size.'),
  ('bm2:B3-009', 'BM-II', 2, 'X/8.3', 'A candidate who passes only one part of the Grade 2 examination may:', '["Only re-sit both parts together","Keep it for life","Never re-sit","Retain that pass for one year when re-sitting the other part, subject to holding a valid medical certificate"]'::jsonb, 3, 'Answer D. X/8.3: a pass in one part is retained for one year on re-sitting the other part, subject to a valid medical fitness certificate.'),
  ('bm2:B9-001', 'BM-II', 2, 'B9.1', 'Providing ''safe access'' to the vessel means ensuring that:', '["The boat is locked","Passengers and crew can get on and off safely — secure gangway/steps, adequate lighting, and assistance where needed","Boarding is done at speed","Only crew may board"]'::jsonb, 1, 'Answer B. Safe access requires a secure, well-lit means of boarding/landing and appropriate assistance, so no one is injured embarking or disembarking.'),
  ('bm2:B9-002', 'BM-II', 2, 'B9.2', '''Safe working practices'' on board include:', '["Working alone in all tasks","Briefing crew, using appropriate PPE, keeping decks clear, and managing tasks like mooring and anchoring safely","Ignoring risk to save time","Removing all guards"]'::jsonb, 1, 'Answer B. Safe working means risk awareness, PPE, clear decks, and safe handling of lines, anchors and machinery to protect crew and passengers.'),
  ('bm2:B9-003', 'BM-II', 2, 'I/15', 'The SCV Safety Certificate (Reg. I/15) must be:', '["Renewed only after an accident","Displayed to passengers as a ticket","Kept ashore by the owner","Valid, carried on board and available for inspection, and its conditions/limits complied with"]'::jsonb, 3, 'Answer D. The Safety Certificate must be in force, carried on board, available for inspection, and the vessel operated within its conditions and limits.'),
  ('bm2:B9-004', 'BM-II', 2, 'B9.4', 'A basic security measure for a small commercial passenger vessel is to:', '["Control access, be alert to suspicious behaviour or unattended items, and account for persons on board","Ignore unknown packages","Leave the vessel open and unattended","Carry weapons"]'::jsonb, 0, 'Answer A. Basic security means access control, vigilance for suspicious persons/items, and accounting for everyone on board.'),
  ('bm2:B9-005', 'BM-II', 2, 'B9.2', 'Who carries the ultimate responsibility for the safety of the vessel, crew and passengers?', '["The boatmaster (person in charge) on board","The owner ashore","The most senior passenger","The Coast Guard"]'::jsonb, 0, 'Answer A. The boatmaster has ultimate responsibility on board for the safety of the vessel and all persons aboard.'),
  ('bm2:B9-006', 'BM-II', 2, 'B9.3', 'If a Safety Certificate condition is breached (e.g. equipment missing or out of date), the boatmaster should:', '["Not operate outside the certificate''s terms — rectify the deficiency before carrying passengers","Sail anyway and fix it later","Ask passengers to sign a waiver","Carry fewer passengers and ignore it"]'::jsonb, 0, 'Answer A. The vessel must be operated within the Safety Certificate; a breach must be rectified before operating, not waived away.'),
  ('bm2:B10-001', 'BM-II', 3, 'B10.1', 'A boatmaster planning a coastal passage should obtain a forecast from:', '["Last week''s newspaper","Personal optimism","Word of mouth only","Official meteorological services via radio, internet or marine forecasts, and check it before departure"]'::jsonb, 3, 'Answer D. Use official met-service forecasts (radio/internet/marine broadcasts) and check the latest before sailing and again under way.'),
  ('bm2:B10-002', 'BM-II', 3, 'B10.3', 'A rapidly falling barometer usually warns of:', '["Fog only","No change","Settled fine weather","Approaching strong winds and deteriorating weather"]'::jsonb, 3, 'Answer D. A rapid fall in barometric pressure indicates an approaching depression/front and strengthening winds — take precautions.'),
  ('bm2:B10-003', 'BM-II', 3, 'B10.3', 'High, wispy cirrus cloud thickening and lowering to a milky sky with a halo around the sun often indicates:', '["A passing shower only","Improving weather","Imminent calm","An approaching warm front and worsening weather within a day or so"]'::jsonb, 3, 'Answer D. Thickening, lowering high cloud and a halo are classic signs of an approaching warm front and deteriorating weather.'),
  ('bm2:B10-004', 'BM-II', 3, 'B10.2', 'In the Caribbean trade-wind belt, local ''acceleration zones'' off the ends of high islands mean a boatmaster should expect:', '["Calm in the lee always","Lighter wind near headlands","No local effect","Locally stronger wind and steeper seas where the trades funnel around or off the island"]'::jsonb, 3, 'Answer D. Wind funnels and accelerates around high islands, producing stronger gusts and steeper seas in the acceleration zones — a key Caribbean local effect.'),
  ('bm2:B10-005', 'BM-II', 3, 'B10.2', 'The greatest seasonal weather hazard for small craft in the Caribbean Netherlands is:', '["Snow","Pack ice","Permanent fog","The tropical storm/hurricane season (broadly June–November)"]'::jsonb, 3, 'Answer D. The Atlantic hurricane season (about June–November) is the major seasonal hazard; monitor warnings and avoid being caught out.'),
  ('bm2:B10-006', 'BM-II', 3, 'B10.3', 'Sudden gusty squalls with a dark line of cloud and a wind-shift approaching are best handled by:', '["Reducing speed, securing the vessel and passengers, and being ready for the wind increase and shift","Increasing speed to outrun them","Heading straight into the steepest seas at full power","Ignoring them"]'::jsonb, 0, 'Answer A. Approaching squalls call for reduced speed, securing the boat/people and readiness for the gust and wind-shift; don''t try to outrun them.'),
  ('bm2:B14-001', 'BM-II', 3, 'B14.1', 'Radar is principally used by a small-craft boatmaster to:', '["Receive weather faxes","Detect other vessels, landmasses and (some) hazards and measure their range and bearing, especially in poor visibility","Steer the autopilot","Measure water temperature"]'::jsonb, 1, 'Answer B. Radar detects targets and measures range/bearing — invaluable for collision avoidance and position-fixing in poor visibility.'),
  ('bm2:B14-002', 'BM-II', 3, 'B14.1', 'A key limitation of radar the boatmaster must remember is that it:', '["Replaces a lookout","Works perfectly in all conditions","Shows colours of vessels","May not detect small craft, low objects or those with poor radar reflection, and needs correct interpretation"]'::jsonb, 3, 'Answer D. Radar can miss small/low/poor-reflecting targets and clutter can hide them; it supplements but never replaces a visual/aural lookout.'),
  ('bm2:B14-003', 'BM-II', 3, 'B14.1', 'AIS (Automatic Identification System) provides the boatmaster with:', '["Identity, position, course, speed and other data broadcast by AIS-fitted vessels","The depth of water","A radar picture of non-AIS targets","A weather forecast"]'::jsonb, 0, 'Answer A. AIS exchanges identity, position, course and speed of equipped vessels — but not all craft carry it, so it is not a complete picture.'),
  ('bm2:B14-004', 'BM-II', 3, 'B14.1', 'An echo sounder measures the:', '["Distance to the nearest vessel","Depth of water below the transducer","Speed over ground","Wind speed"]'::jsonb, 1, 'Answer B. An echo sounder measures water depth beneath the transducer; the operator must know whether it reads from the keel, waterline or transducer.'),
  ('bm2:B14-005', 'BM-II', 3, 'B14.1', 'Satellite navigation (GPS/GNSS) gives the boatmaster a continuous:', '["Radar picture","Position (latitude/longitude), and derived course and speed over the ground","Engine temperature","Depth reading"]'::jsonb, 1, 'Answer B. GNSS provides continuous position and, from successive fixes, course and speed over the ground; cross-check against other means.'),
  ('bm2:B14-006', 'BM-II', 3, 'B14.1', 'A prudent boatmaster treats electronic aids by:', '["Switching off the lookout","Ignoring them in clear weather","Cross-checking electronic position/data against visual observation, the chart and the echo sounder","Trusting the GPS plotter absolutely"]'::jsonb, 2, 'Answer C. Electronic aids can fail or mislead; always cross-check against eyes, chart, soundings and other instruments, and keep a lookout.'),
  ('bm2:B5-001', 'BM-II', 3, 'B5.1', 'On a chart, a number such as ''12'' printed in open water normally indicates the:', '["Tidal range","Magnetic variation","Distance to shore","Charted depth (soundings) reduced to chart datum"]'::jsonb, 3, 'Answer D. Soundings are charted depths reduced to chart datum (normally LAT); the figure shows the depth in the chart''s stated units.'),
  ('bm2:B5-002', 'BM-II', 3, 'B5.1', 'An asterisk or small symbol with the abbreviation ''Wk'' on a chart marks a:', '["Working area","Anchorage","Weather station","Wreck"]'::jsonb, 3, 'Answer D. ''Wk'' marks a wreck; the symbol style and any depth figure show whether it is dangerous and how it is marked.'),
  ('bm2:B5-003', 'BM-II', 3, 'B5.1', 'Chart datum, to which charted depths are reduced, is normally chosen as:', '["Mean sea level","High water springs","The deck level of the survey ship","A low-water level (e.g. Lowest Astronomical Tide) so the real depth is rarely less than charted"]'::jsonb, 3, 'Answer D. Charts use a low-water datum (commonly LAT) so the actual depth is almost always at least the charted sounding — a safety margin.'),
  ('bm2:B5-004', 'BM-II', 3, 'B5.1', 'On a chart the abbreviation ''S'' against the seabed nature means:', '["Shell","Stone","Shoal","Sand"]'::jsonb, 3, 'Answer D. Seabed quality abbreviations: S = sand, M = mud, Co = coral, R = rock — important for choosing holding ground.'),
  ('bm2:B5-005', 'BM-II', 3, 'B5.2', 'A Tidal Diamond on a chart (a magenta diamond with a letter) gives the:', '["Position of a buoy","Magnetic variation","Charted depth","Tidal stream set (direction) and rate (speed) at that position for each hour relative to HW"]'::jsonb, 3, 'Answer D. Tidal diamonds key to a table giving the tidal-stream direction and rate for each hour before/after high water at a reference port.'),
  ('bm2:B5-006', 'BM-II', 3, 'B5.2', 'To use a tidal diamond you must know the:', '["State of tide (time relative to HW at the reference port) and whether it is springs or neaps","Compass deviation only","Engine RPM","Vessel''s fuel state"]'::jsonb, 0, 'Answer A. The diamond table is entered with the hour relative to HW and adjusted for springs/neaps to read the stream''s set and rate.'),
  ('bm2:B5-007', 'BM-II', 3, 'B5.1', 'On a chart, the abbreviation ''Fl'' beside a light symbol means the light is:', '["Fixed (steady)","Flashing","Faint","Floodlit"]'::jsonb, 1, 'Answer B. ''Fl'' denotes a flashing light (the light period shorter than the dark); ''F'' would be a fixed (steady) light.'),
  ('bm2:B5-008', 'BM-II', 3, 'B5.2', 'If a tidal-stream rate from a tidal diamond is given for springs and neaps, the rate on a day between springs and neaps is found by:', '["Using the spring rate always","Using the neap rate always","Interpolating between the spring and neap rates","Doubling the neap rate"]'::jsonb, 2, 'Answer C. The actual rate is interpolated between the tabulated spring and neap figures according to where the day falls in the cycle.'),
  ('bm2:B2-001', 'BM-II', 4, 'Rule 5', 'COLREG Rule 5 requires every vessel to:', '["Use radar at all times","Post a lookout only in fog","Keep a lookout only at night","Keep a proper lookout by sight and hearing and by all available means"]'::jsonb, 3, 'Answer D. Rule 5: a proper lookout shall be maintained at all times by sight and hearing and by all available appropriate means.'),
  ('bm2:B2-002', 'BM-II', 4, 'Rule 6', 'Under Rule 6, ''safe speed'' is a speed at which a vessel can:', '["Maintain schedule","Take proper and effective action to avoid collision and stop within a distance appropriate to the circumstances","Plane fully","Reach maximum economy"]'::jsonb, 1, 'Answer B. Safe speed allows proper avoiding action and stopping within an appropriate distance, judged from visibility, traffic, manoeuvrability etc.'),
  ('bm2:B2-003', 'BM-II', 4, 'Rule 7', 'Rule 7 states that risk of collision shall be deemed to exist if:', '["The other vessel is large","You are the stand-on vessel","The compass bearing of an approaching vessel does not appreciably change","The vessels are more than 3 miles apart"]'::jsonb, 2, 'Answer C. If the compass bearing of an approaching vessel does not appreciably change, risk of collision shall be deemed to exist.'),
  ('bm2:B2-004', 'BM-II', 4, 'Rule 8', 'Action to avoid collision under Rule 8 should be:', '["Left to the last moment","Positive, made in ample time, large enough to be readily apparent to another vessel","A series of tiny course changes","Small and gradual so as not to alarm"]'::jsonb, 1, 'Answer B. Avoiding action must be positive, made in ample time and large enough to be readily apparent visually or by radar.'),
  ('bm2:B2-005', 'BM-II', 4, 'Rule 9', 'In a narrow channel, a vessel shall keep:', '["As near to the outer limit on her starboard side as is safe and practicable","Wherever the deepest water is","To the centre","To the port side"]'::jsonb, 0, 'Answer A. Rule 9: keep as near to the outer limit of the channel on your starboard side as is safe and practicable.'),
  ('bm2:B2-006', 'BM-II', 4, 'Rule 9', 'A vessel of less than 20 m in length or a sailing vessel in a narrow channel shall:', '["Anchor in the fairway","Always sound five blasts","Not impede the passage of a vessel that can safely navigate only within the channel","Have right of way over a power-driven vessel"]'::jsonb, 2, 'Answer C. Rule 9(b): a vessel under 20 m or a sailing vessel shall not impede a vessel which can safely navigate only within the channel.'),
  ('bm2:B2-007', 'BM-II', 4, 'Rule 10', 'When crossing a traffic separation scheme that cannot be avoided, a vessel shall cross:', '["On a heading as nearly as practicable at right angles to the general direction of traffic flow","Against the flow to save time","Diagonally with the flow","Along the separation zone"]'::jsonb, 0, 'Answer A. Rule 10: cross a TSS on a heading as nearly as practicable at right angles to the general traffic direction.'),
  ('bm2:B2-008', 'BM-II', 4, 'Rule 12', 'Two sailing vessels approaching with the wind on different sides: which keeps clear?', '["The vessel with the wind on the port side keeps out of the way","The smaller vessel","The faster vessel","The one with wind on the starboard side"]'::jsonb, 0, 'Answer A. Rule 12: when each has the wind on a different side, the vessel with the wind on the port side keeps out of the way.'),
  ('bm2:B2-009', 'BM-II', 4, 'Rule 13', 'An overtaking vessel (Rule 13) is one coming up on another from more than how many degrees abaft the beam?', '["90 degrees","22.5 degrees","45 degrees","10 degrees"]'::jsonb, 1, 'Answer B. An overtaking vessel approaches from more than 22.5 degrees abaft the beam (where at night it would see only the sternlight).'),
  ('bm2:B2-010', 'BM-II', 4, 'Rule 13', 'The duty of an overtaking vessel is to:', '["Sound one prolonged blast","Maintain course and speed","Keep out of the way of the vessel being overtaken until finally past and clear","Pass close down the other''s port side"]'::jsonb, 2, 'Answer C. The overtaking vessel must keep clear of the overtaken vessel until past and clear; this duty is not cancelled by any later change of bearing.'),
  ('bm2:B2-011', 'BM-II', 4, 'Rule 14', 'Two power-driven vessels meeting head-on should each:', '["Stop engines","Alter course to starboard so each passes on the port side of the other","Hold course and speed","Alter course to port"]'::jsonb, 1, 'Answer B. Rule 14: in a head-on meeting each power-driven vessel alters course to starboard to pass port-to-port.'),
  ('bm2:B2-012', 'BM-II', 4, 'Rule 15', 'In a crossing situation between two power-driven vessels, the vessel which has the other on her own starboard side shall:', '["Stand on","Keep out of the way and avoid crossing ahead of the other","Alter to port across the bow","Increase speed"]'::jsonb, 1, 'Answer B. Rule 15: the vessel that has the other on its starboard side gives way and shall, if possible, avoid crossing ahead of the other.'),
  ('bm2:B2-013', 'BM-II', 4, 'Rule 16', 'The give-way vessel (Rule 16) shall:', '["Wait for the stand-on vessel to act","Sound the danger signal","Take early and substantial action to keep well clear","Maintain course and speed"]'::jsonb, 2, 'Answer C. Rule 16: the give-way vessel must take early and substantial action to keep well clear.'),
  ('bm2:B2-014', 'BM-II', 4, 'Rule 17', 'Under Rule 17 the stand-on vessel shall initially:', '["Cross ahead of the give-way vessel","Alter to port immediately","Keep her course and speed","Stop her engines"]'::jsonb, 2, 'Answer C. The stand-on vessel keeps course and speed initially, but may and must act if the give-way vessel is not taking appropriate action.'),
  ('bm2:B2-015', 'BM-II', 4, 'Rule 18', 'In the general pecking order of Rule 18, a power-driven vessel under way shall keep out of the way of all of the following EXCEPT:', '["Another ordinary power-driven vessel under way","A vessel not under command","A vessel restricted in her ability to manoeuvre","A vessel engaged in fishing"]'::jsonb, 0, 'Answer A. A power-driven vessel gives way to NUC, RAM, fishing and (so far as practicable) sailing vessels; it has no such duty to another ordinary power-driven vessel except under the steering rules.'),
  ('bm2:B2-016', 'BM-II', 4, 'Rule 19', 'In restricted visibility, a vessel hearing apparently forward of the beam the fog signal of another vessel shall, so far as the situation admits:', '["Maintain full speed","Sound five short blasts","Alter boldly to port","Reduce to minimum speed at which she can be kept on course, or take all way off if necessary"]'::jsonb, 3, 'Answer D. Rule 19(e): reduce speed to the minimum at which she can be kept on her course; take all way off if necessary, and navigate with caution.'),
  ('bm2:B2-017', 'BM-II', 4, 'Rule 19', 'Rule 19 (restricted visibility) applies to vessels:', '["Only at anchor","Not in sight of one another, navigating in or near an area of restricted visibility","Only when overtaking","In sight of one another"]'::jsonb, 1, 'Answer B. Rule 19 governs conduct of vessels not in sight of one another in or near restricted visibility; the steering/sailing rules of Section II do not apply.'),
  ('bm2:B2-018', 'BM-II', 4, 'Rule 19', 'A vessel which detects by radar alone another vessel and assesses a close-quarters situation is developing shall avoid, if the alteration of course is to be made:', '["An alteration of course towards a vessel abeam or abaft the beam","Sounding any signal","Any reduction of speed","An alteration of course to starboard for a vessel forward of the beam (other than for one being overtaken) — and avoid turning toward a vessel abeam/abaft"]'::jsonb, 3, 'Answer D. Rule 19(d): avoid an alteration to port for a vessel forward of the beam (other than one being overtaken) and avoid altering toward a vessel abeam or abaft the beam.'),
  ('bm2:B2-019', 'BM-II', 4, 'Rule 35', 'In or near restricted visibility, a power-driven vessel making way through the water shall sound:', '["One prolonged blast at intervals of not more than 2 minutes","Five short blasts continuously","One short blast every minute","Two prolonged blasts every minute"]'::jsonb, 0, 'Answer A. Rule 35: a power-driven vessel making way sounds one prolonged blast at intervals of not more than 2 minutes.'),
  ('bm2:B2-020', 'BM-II', 4, 'Rule 34', 'In sight of one another, a power-driven vessel altering course to starboard sounds:', '["One short blast","One prolonged blast","Two short blasts","Three short blasts"]'::jsonb, 0, 'Answer A. Rule 34: one short blast = ''I am altering my course to starboard''; two = to port; three = operating astern propulsion.'),
  ('bm2:B2-021', 'BM-II', 4, 'Rule 34', 'Five or more short and rapid blasts is the signal meaning:', '["I doubt whether you are taking sufficient action to avoid collision (the danger/wake-up signal)","I am at anchor","I am altering to port","I am overtaking on your starboard side"]'::jsonb, 0, 'Answer A. At least five short rapid blasts is the danger signal, indicating doubt that the other vessel is taking sufficient avoiding action.'),
  ('bm2:B2-022', 'BM-II', 4, 'Rule 23', 'A power-driven vessel under way of less than 50 m in length must exhibit at night:', '["Sidelights only","An all-round red light","A masthead light, sidelights and a sternlight (a second masthead light optional under 50 m)","Two masthead lights, sidelights and a sternlight"]'::jsonb, 2, 'Answer C. A power-driven vessel under 50 m shows one masthead light forward, sidelights and a sternlight; a second masthead is optional under 50 m.'),
  ('bm2:B2-023', 'BM-II', 4, 'Rule 24', 'A vessel towing astern where the length of tow exceeds 200 m shows, in addition to other lights:', '["Nothing extra","A single red all-round light","Three masthead lights in a vertical line forward and a diamond shape by day","A black ball"]'::jsonb, 2, 'Answer C. When the tow exceeds 200 m the towing vessel shows three masthead lights in a vertical line and, by day, a diamond shape.'),
  ('bm2:B2-024', 'BM-II', 4, 'Rule 25', 'A sailing vessel under way (and not motoring) at night exhibits:', '["An all-round white light only","A masthead light and sidelights","Two red lights in a line","Sidelights and a sternlight"]'::jsonb, 3, 'Answer D. A sailing vessel shows sidelights and a sternlight; if she is also being propelled by machinery she must show a masthead light and is treated as power-driven.'),
  ('bm2:B2-025', 'BM-II', 4, 'Rule 30', 'A vessel at anchor of less than 50 m exhibits at night:', '["An all-round white light where it can best be seen","A red over green","A masthead light and sidelights","Two all-round red lights"]'::jsonb, 0, 'Answer A. A vessel under 50 m at anchor shows one all-round white light where best seen (and by day one black ball forward).'),
  ('bm2:B2-026', 'BM-II', 4, 'Rule 27', 'A vessel not under command (NUC) exhibits at night:', '["Two all-round red lights in a vertical line","Two all-round green lights","Red over white","Three all-round red lights vertically"]'::jsonb, 0, 'Answer A. A NUC vessel shows two all-round red lights in a vertical line, and when making way also sidelights and a sternlight.'),
  ('bm2:B2-027', 'BM-II', 4, 'Rule 26', 'A vessel engaged in fishing (other than trawling) by night exhibits:', '["Two red lights","Green over white all-round","Two green lights","Red over white all-round lights in a vertical line"]'::jsonb, 3, 'Answer D. A vessel fishing (not trawling) shows an all-round red over an all-round white light; a trawler shows green over white.'),
  ('bm2:B2-028', 'BM-II', 4, 'Rule 32', 'Under the COLREG sound-signal definitions, a ''prolonged blast'' lasts:', '["From four to six seconds","About 1 second","Ten seconds","Exactly 2 seconds"]'::jsonb, 0, 'Answer A. A prolonged blast is of four to six seconds'' duration; a short blast is about one second.'),
  ('bm2:B2-029', 'BM-II', 4, 'Rule 3', 'Under Rule 3, a vessel ''restricted in her ability to manoeuvre'' is one which:', '["Is at anchor","Has a deep draught","From the nature of her work is restricted in her ability to keep out of the way of another vessel","Is simply slow"]'::jsonb, 2, 'Answer C. A RAM vessel is restricted by the nature of her work (e.g. laying cable, dredging) from manoeuvring as required by the Rules.'),
  ('bm2:B2-030', 'BM-II', 4, 'B2.3', 'Keeping a ''good lookout'' in busy daylight pilotage water specifically requires the boatmaster to:', '["Post a lookout only when overtaking","Watch the chart plotter only","Use sight and hearing, scan all round including astern, and not be distracted by other duties","Rely on AIS targets only"]'::jsonb, 2, 'Answer C. A good lookout is continuous, all-round, by eye and ear, undistracted — radar/AIS supplement but never replace it.'),
  ('bm2:B2-031', 'BM-II', 4, 'B2.4', 'The principal purpose of keeping a Deck Log on a Grade 2 vessel is to:', '["Record the crew''s wages","Provide a chronological, factual record of the voyage, navigation, weather, incidents and key decisions","List the passengers'' meals","Replace the SMS"]'::jsonb, 1, 'Answer B. The deck log is the official, contemporaneous record of the voyage — navigation, weather, position, incidents — and is vital evidence after any incident.'),
  ('bm2:B2-032', 'BM-II', 4, 'B2.4', 'Which of the following should normally be entered in the deck log?', '["Nothing unless there is an incident","Only departure and arrival","Just the fuel cost","Times of departure/arrival, courses and speeds, weather, significant events, defects and any emergencies"]'::jsonb, 3, 'Answer D. The deck log records times, courses/speeds, weather, significant events, defects and emergencies — a complete narrative of the watch.'),
  ('bm2:B2-033', 'BM-II', 4, 'B2.2', 'Why does Grade 2 (unlike Grade 3) require a FULL knowledge of the Collision Regulations?', '["Only the practical test matters","A Grade 2 may operate larger/decked vessels and in coastal waters where the full range of situations, lights and signals must be applied","The rules differ at Grade 2","Grade 2 boatmasters never use them"]'::jsonb, 1, 'Answer B. Grade 2 covers larger vessels and coastal operation, so the full COLREG — all lights, shapes, signals and conduct rules — must be mastered, not just a practical working knowledge.'),
  ('bm2:B2-034', 'BM-II', 4, 'Rule 2', 'Rule 2 (Responsibility) means that compliance with the Rules:', '["Does not exonerate a vessel from the consequences of neglect, and a departure from the Rules may be necessary to avoid immediate danger","Applies only by day","Excuses any consequences","Is optional for small craft"]'::jsonb, 0, 'Answer A. Rule 2: nothing exonerates neglect of ordinary good seamanship, and a departure from the Rules is permitted where necessary to avoid immediate danger.'),
  ('bm2:B4-001', 'BM-II', 5, 'B4.1', 'On a vessel the term ''freeboard'' means the:', '["Distance from the keel to the waterline","Length of the anchor cable","Vertical distance from the waterline to the main deck edge","Width of the deck"]'::jsonb, 2, 'Answer C. Freeboard is the height of the deck (or deck edge) above the waterline — the reserve buoyancy above the sea.'),
  ('bm2:B4-002', 'BM-II', 5, 'B4.1', 'The ''scope'' of an anchor cable is:', '["The chain''s diameter","The ratio of the length of cable veered to the depth of water","The breaking strain","The weight of the anchor"]'::jsonb, 1, 'Answer B. Scope is the ratio of cable length paid out to water depth; adequate scope (e.g. 4:1 chain or more) keeps the pull horizontal so the anchor holds.'),
  ('bm2:B4-003', 'BM-II', 5, 'B4.2', '''Interaction'' between two vessels passing close at speed tends to:', '["Only slow them down","Push them apart strongly","Have no effect","Cause the vessels to be drawn together (and the smaller vessel to sheer), especially in shallow or narrow water"]'::jsonb, 3, 'Answer D. Pressure fields cause close-passing vessels to attract each other and the smaller craft to sheer; risk rises in shallow or confined water.'),
  ('bm2:B4-004', 'BM-II', 5, 'B4.3', 'When berthing with a strong onshore (setting you onto the berth) wind, you should:', '["Ignore the wind entirely","Approach fast and let the wind stop you","Approach at a shallow angle, control the rate of closing, and use lines/fenders early because the wind will set you on","Approach beam-on at speed"]'::jsonb, 2, 'Answer C. An onshore wind sets you onto the berth, so close slowly at a shallow angle and get lines on early; never let the wind slam you alongside.'),
  ('bm2:B4-005', 'BM-II', 5, 'B4.4', 'After weighing anchor, the anchor and cable should be:', '["Left hanging over the bow under way","Towed astern","Properly secured and stowed, with the cable stopper/devil''s claw on, to prevent it running out or causing damage","Coiled on deck loose"]'::jsonb, 2, 'Answer C. Anchors and cable must be securely stowed and the stopper applied so they cannot run out accidentally or shift at sea.'),
  ('bm2:B4-006', 'BM-II', 5, 'B4.5', 'Selecting a good anchorage depends mainly on:', '["Being as close to other boats as possible","Proximity to a restaurant","The deepest possible water","Good holding ground, adequate shelter from wind/sea, sufficient and suitable depth, swinging room, and clear of cables/fairways"]'::jsonb, 3, 'Answer D. A proper anchorage needs good holding ground, shelter, suitable depth, swinging room and clearance of hazards, cables and fairways.'),
  ('bm2:B4-007', 'BM-II', 5, 'B4.6', 'Navigating at reduced speed past moored boats and shorelines is important chiefly because:', '["It saves fuel only","It looks professional","Your bow and stern wave (wash) can cause damage and injury, for which you are responsible","It is faster overall"]'::jsonb, 2, 'Answer C. Excessive wash from your bow/stern wave can damage moored craft and the shore and injure people; the boatmaster is responsible for it.'),
  ('bm2:B4-008', 'BM-II', 5, 'B4.7', 'Compared with a single-screw boat, a twin-screw boat is generally:', '["More manoeuvrable at low speed because differential thrust gives a strong turning couple","Unable to turn in its own length","Less affected by transverse thrust on every prop","Harder to manoeuvre at low speed"]'::jsonb, 0, 'Answer A. Twin screws give excellent low-speed control: opposing thrust turns the boat in its own length and keeps steerage with little headway.'),
  ('bm2:B4-009', 'BM-II', 5, 'B4.8', 'Two basic hazards associated with towing another vessel are:', '["Saving fuel and time","Improved stability and speed","No hazards if the rope is strong","The tow yawing/girting the towing vessel, and the tow-line parting under shock loading (snap-back danger)"]'::jsonb, 3, 'Answer D. Towing risks include girting/capsize from a sheering tow, and a parting line snapping back lethally; rig a quick-release and keep clear of the bight.'),
  ('bm2:B4-010', 'BM-II', 5, 'B4.1', 'A ''bight'' of a rope or towline is:', '["A loop or curved part of the rope between its ends","The end of the rope","A type of knot","The cleat"]'::jsonb, 0, 'Answer A. A bight is a loop or curve in a rope between the ends; standing in a bight under load is dangerous if it comes taut.'),
  ('bm2:A-001', 'BM-II', 6, 'A1.7', 'Transverse thrust (paddle-wheel effect) on a single right-handed fixed propeller is most noticeable when the engine is:', '["Idling ahead in deep water","Running ahead at cruising speed","Stopped with the rudder amidships","First put astern from rest, before the boat gathers sternway"]'::jsonb, 3, 'Answer D. Transverse thrust is most pronounced going astern from rest, before water flow over the rudder builds; a right-handed prop walks the stern to port.'),
  ('bm2:A-002', 'BM-II', 6, 'A1.7', 'A right-handed (clockwise when viewed from astern) single screw is put astern from rest. The stern will tend to walk to:', '["Whichever way the wind blows only","Port","Starboard","Stay dead straight"]'::jsonb, 1, 'Answer B. A right-handed propeller going astern walks the stern to port (and the bow swings to starboard).'),
  ('bm2:A-003', 'BM-II', 6, 'A1.5', 'When manoeuvring a single-screw vessel in confined water, the most effective way to turn it short round in its own length is to:', '["Use alternating bursts of ahead (with rudder hard over) and astern, exploiting prop wash and transverse thrust","Use full ahead with hard-over rudder only","Drift and let wind do the turning","Tow the bow round with the dinghy"]'::jsonb, 0, 'Answer A. Turning short round uses short bursts ahead against hard-over rudder to kick the stern, alternated with astern, using prop wash and transverse thrust.'),
  ('bm2:A-004', 'BM-II', 6, 'A1.1', 'When coming alongside a berth, the safest general approach is to:', '["Approach beam-on and let the fenders absorb the contact","Approach fast so the boat answers the helm and stop with a burst astern at the last moment","Approach downwind and downtide for an easy stop","Approach slowly, at an angle, stemming any wind or tide so you keep steerage at low speed"]'::jsonb, 3, 'Answer D. Approach slowly against the stronger of wind or tide so the boat is held back and steerage is retained; never approach faster than you are willing to hit.'),
  ('bm2:A-005', 'BM-II', 6, 'A1.2', 'When weighing (recovering) the anchor, the helmsman should:', '["Drive ahead hard to break out the anchor while the crew heaves","Motor gently up towards the anchor as the cable is recovered so the crew never has to take the boat''s weight","Go full astern to drag it out","Leave the engine in neutral throughout"]'::jsonb, 1, 'Answer B. The boat is motored gently up to the anchor to reduce strain; the windlass/crew should never take the full weight of the boat.'),
  ('bm2:A-006', 'BM-II', 6, 'A1.3', 'When coming alongside another vessel that is under way and making way, you should match her:', '["Opposite course, bow to bow","Course and speed, approaching from astern on the lee side","Course but at twice her speed","Speed only, ignoring her heading"]'::jsonb, 1, 'Answer B. Come alongside a moving vessel by matching course and speed and closing gently, normally on the lee (sheltered) side.'),
  ('bm2:A-007', 'BM-II', 6, 'A1.4', 'To make fast to a mooring buoy single-handed in a tideway, you should approach:', '["Beam-on at speed","Downtide so you arrive quickly","Heading into the tide (or the stronger of wind/tide) so the buoy stops you","From directly downwind only, ignoring tide"]'::jsonb, 2, 'Answer C. Approach a buoy stemming the tide (or stronger of wind/tide); it acts as a brake and lets you stop alongside the buoy with control.'),
  ('bm2:A-008', 'BM-II', 6, 'A1.6', 'Twin-screw vessels can turn in their own length most readily by:', '["Putting both engines ahead","Putting one engine ahead and the other astern","Using rudder only with both ahead","Putting both engines astern"]'::jsonb, 1, 'Answer B. Going ahead on one engine and astern on the other produces a strong turning couple, letting a twin-screw turn in its own length.'),
  ('bm2:A-009', 'BM-II', 6, 'A1.8', 'Steering an accurate compass course means:', '["Following the GPS course-over-ground exactly with no compass","Pointing the bow at the destination and locking the wheel","Steering by the wake only","Steering the lubber line on the desired compass figure and checking against a transit/landmark"]'::jsonb, 3, 'Answer D. Keep the compass card steady on the ordered course at the lubber line, cross-checking with a transit or fixed mark to detect set.'),
  ('bm2:A-010', 'BM-II', 6, 'A1.9', 'On VHF, the correct spoken word that precedes a DISTRESS call is:', '["SEELONCE","PAN-PAN","SECURITE","MAYDAY (spoken three times)"]'::jsonb, 3, 'Answer D. A distress call is preceded by MAYDAY spoken three times — used only when a vessel or person is in grave and imminent danger.'),
  ('bm2:A-011', 'BM-II', 6, 'A1.9', 'The VHF urgency signal, used for an urgent message about the safety of a vessel or person but not in grave and imminent danger, is:', '["SECURITE","PAN-PAN (spoken three times)","MAYDAY","MAYDAY RELAY"]'::jsonb, 1, 'Answer B. PAN-PAN (three times) is the urgency signal — a very urgent message concerning the safety of a vessel/person, short of grave and imminent danger.'),
  ('bm2:A-012', 'BM-II', 6, 'A1.9', 'The VHF safety signal SECURITE is used to introduce:', '["A navigational or meteorological warning","A routine radio check","A distress message","A request to change channel"]'::jsonb, 0, 'Answer A. SECURITE (three times) introduces an important navigational or meteorological warning.'),
  ('bm2:A-013', 'BM-II', 6, 'A1.9', 'Which VHF channel is the international distress, safety and calling channel?', '["Channel 6","Channel 16","Channel 80","Channel 72"]'::jsonb, 1, 'Answer B. Channel 16 (156.8 MHz) is the international distress, safety and calling channel and must be monitored.'),
  ('bm2:A-014', 'BM-II', 6, 'A1.9', 'A DSC distress alert on VHF is normally transmitted on:', '["Channel 70","Channel 13","Channel 16 by voice only","Channel 6"]'::jsonb, 0, 'Answer A. DSC (Digital Selective Calling) distress alerts are sent on VHF Channel 70; the voice MAYDAY then follows on Channel 16.'),
  ('bm2:A-015', 'BM-II', 6, 'A1.9', 'The single most important reason a MAYDAY voice message must include the vessel''s position is that it:', '["Tells rescuers where to search and is required to fix the casualty","Confirms the working channel","Records the time of day","Identifies the radio licence"]'::jsonb, 0, 'Answer A. Position is the most safety-critical element of a MAYDAY: it tells SAR units where to go.'),
  ('bm2:A-016', 'BM-II', 6, 'A1.9', 'Deliberately making a false distress call on VHF is:', '["Permitted on Channel 16 only","Allowed if cancelled within an hour","A serious offence that wastes SAR resources and endangers others","Acceptable for a radio test"]'::jsonb, 2, 'Answer C. Misuse of distress channels and false alerts is a serious offence; it diverts SAR assets and endangers genuine casualties.'),
  ('bm2:A-017', 'BM-II', 6, 'A1.9', 'Before transmitting a routine call on a busy VHF working channel you should:', '["Whistle into the microphone","Transmit immediately on Channel 16","Listen first to ensure the channel is clear so you do not interfere with other traffic","Use the distress channel"]'::jsonb, 2, 'Answer C. Always listen before transmitting so you do not interfere; use the correct working channel and keep messages brief and clear.'),
  ('bm2:B17-001', 'BM-II', 6, 'B17.15', 'The particular danger of severe wind and heavy rolling in a following sea is that it can:', '["Increase freeboard","Lead to broaching or a reduction of stability on a wave crest, risking capsize","Stop the engine","Improve stability"]'::jsonb, 1, 'Answer B. In a following sea the vessel can be picked up, surf and broach, and lose stability on a crest — a recognised capsize risk in severe conditions.'),
  ('bm2:B17-002', 'BM-II', 6, 'B17.16', 'Not exceeding the vessel''s load capacity matters chiefly because overloading:', '["Reduces freeboard and stability and removes the reserve of safety, risking swamping or capsize","Helps in rough seas","Wears the paint","Slows the boat only"]'::jsonb, 0, 'Answer A. Overloading reduces freeboard and stability and erodes the safety margin, making swamping or capsize far more likely.'),
  ('bm2:B17-003', 'BM-II', 6, 'B17.17', 'Before anyone enters an enclosed space (e.g. a sealed locker, tank or void) the principal hazard to consider is:', '["Bright light","Cold water","Noise","A dangerous (oxygen-deficient or toxic/flammable) atmosphere"]'::jsonb, 3, 'Answer D. Enclosed spaces may have oxygen-deficient, toxic or flammable atmospheres; the atmosphere must be tested and made safe first.'),
  ('bm2:B17-004', 'BM-II', 6, 'B17.17', 'Safe entry into an enclosed space requires, as a minimum:', '["Just opening the hatch and climbing in","Atmosphere testing, ventilation, a permit/authorisation, a standby person outside and a means of rescue","Holding your breath","One quick look only"]'::jsonb, 1, 'Answer B. Enclosed-space entry needs testing, ventilation, authorisation, a standby/attendant outside and rescue arrangements — never enter unprepared.'),
  ('bm2:B17-005', 'BM-II', 6, 'B17.17', 'If a person collapses inside an enclosed space, an untrained rescuer who rushes in to help typically:', '["Saves the casualty easily","Improves the air","Becomes a second casualty from the same dangerous atmosphere","Is unaffected"]'::jsonb, 2, 'Answer C. Many enclosed-space deaths are would-be rescuers overcome by the same atmosphere; raise the alarm and use proper equipment, never rush in.'),
  ('bm2:B17-006', 'BM-II', 6, 'B17.15', '''Free surface effect'' from liquid moving in a partly filled tank or bilge:', '["Reduces stability because the shifting liquid moves the centre of gravity to the low side","Only matters at anchor","Has no effect","Increases stability"]'::jsonb, 0, 'Answer A. A free liquid surface lets the liquid surge to the low side, effectively raising G and reducing stability — keep tanks pressed up or empty and bilges dry.'),
  ('bm2:B11-001', 'BM-II', 7, 'B11.1', 'Daily pre-start checks on a diesel installation should include checking the:', '["Chart folio","Paint condition only","Oil level, coolant level, fuel level/water trap, belts, and battery condition","Radio volume"]'::jsonb, 2, 'Answer C. Daily checks: lubricating-oil and coolant levels, fuel and water-separator, drive belts and battery state — before starting.'),
  ('bm2:B11-002', 'BM-II', 7, 'B11.1', 'A correctly maintained battery for engine starting should have its terminals:', '["Painted over","Loose for easy removal","Disconnected at sea","Clean, tight and lightly protected against corrosion, with electrolyte at the correct level where applicable"]'::jsonb, 3, 'Answer D. Battery terminals must be clean and tight with corrosion protection; loose/corroded terminals cause starting failures and voltage drop.'),
  ('bm2:B11-003', 'BM-II', 7, 'B11.3', 'An engine high-temperature alarm or shut-off device exists to:', '["Save fuel","Indicate low fuel","Warn of (or prevent) overheating before serious engine damage occurs","Increase power"]'::jsonb, 2, 'Answer C. Safety/shut-off devices warn of or stop the engine on overheating or low oil pressure to prevent catastrophic damage.'),
  ('bm2:B11-004', 'BM-II', 7, 'B11.4', 'While the engine is running, a quick visual ''running check'' includes watching for:', '["The flag","The colour of the deck","The radio channel","Abnormal exhaust colour/smoke, cooling-water flow, oil pressure and temperature, and unusual noise or vibration"]'::jsonb, 3, 'Answer D. Running checks: exhaust colour, cooling-water telltale flow, oil pressure/temperature gauges and any unusual noise/vibration.'),
  ('bm2:B11-005', 'BM-II', 7, 'B11.5', 'Blue smoke from a diesel exhaust generally indicates:', '["Too much cooling water","Oil being burnt (e.g. worn rings or overfilled sump)","Normal running","Correct fuel mix"]'::jsonb, 1, 'Answer B. Blue exhaust smoke indicates lubricating oil being burnt; black = over-fuelling/overload, white = water or unburnt fuel.'),
  ('bm2:B11-006', 'BM-II', 7, 'B11.5', 'The engine suddenly overheats with no cooling-water flow from the exhaust. The first thing to check is the:', '["Steering","Fuel gauge","Battery voltage","Raw-water intake (seacock open?) and strainer/impeller for a blockage"]'::jsonb, 3, 'Answer D. Loss of raw-water flow points to a closed seacock, blocked strainer or failed impeller; check these first to avoid overheating damage.'),
  ('bm2:B11-007', 'BM-II', 7, 'B11.5', 'If a diesel engine will not start and turns over normally but no fuel reaches it, a likely cause is:', '["Flat battery","Wrong propeller","Air in the fuel system or a blocked fuel filter — bleed/replace as needed","Open seacock"]'::jsonb, 2, 'Answer C. If it cranks but won''t fire, suspect fuel: air in the system, blocked filter or empty tank — bleed the system and check filters.'),
  ('bm2:B11-008', 'BM-II', 7, 'B11.2', 'Routine maintenance intervals for engine oil and filters should be:', '["As specified by the manufacturer''s manual, by running hours or calendar, whichever comes first","Only after a breakdown","Whenever convenient","Never, if it runs"]'::jsonb, 0, 'Answer A. Follow the manufacturer''s schedule (running hours/calendar) for oil and filter changes to keep the machinery reliable.'),
  ('bm2:B11-009', 'BM-II', 7, 'B11.3', 'Before working on machinery (e.g. the propeller shaft or impeller), the engine must be:', '["Put in gear","Left idling","Stopped and the start isolated (key out/battery isolator off) so it cannot be started accidentally","Run at half speed"]'::jsonb, 2, 'Answer C. Isolate the engine (stop, remove key, switch off the battery isolator) before working on it so it cannot start and injure you.'),
  ('bm2:B1-001', 'BM-II', 8, 'B1.1', 'On sighting a person fall overboard, the first immediate actions are to:', '["Drop the anchor immediately","Shout ''man overboard'', throw a lifebuoy, post a pointer to keep the casualty in sight and press the MOB button","Turn 180 degrees at full speed","Stop the engine and call the owner"]'::jsonb, 1, 'Answer B. Raise the alarm, throw buoyancy at once, detail a dedicated lookout to point continuously, and mark the position (GPS MOB).'),
  ('bm2:B1-002', 'BM-II', 8, 'B1.1', 'The danger of a propeller to a person in the water during MOB recovery means you should:', '["Keep full power on until contact is made","Stop the engine (or take it out of gear) before the casualty comes alongside","Reverse hard alongside the casualty","Approach with the casualty on the windward bow under power throughout"]'::jsonb, 1, 'Answer B. The propeller must be stopped or in neutral before the casualty is alongside to avoid a fatal injury.'),
  ('bm2:B1-003', 'BM-II', 8, 'B1.10', 'Conducting a search in reduced visibility for a person overboard, the boatmaster should:', '["Stop all watch and rely on radar only","Switch off the engine and wait","Post extra lookouts, reduce speed, use a systematic search pattern and sound signals, and alert the Coast Guard","Increase speed to cover more area"]'::jsonb, 2, 'Answer C. Bad-weather/low-visibility SAR needs extra lookouts, safe slow speed, a methodical pattern, sound/light signals and early Coast Guard notification.'),
  ('bm2:B1-004', 'BM-II', 8, 'B1.10', 'An expanding square search pattern is most appropriate when:', '["The casualty''s position is known fairly accurately and a single vessel searches outward from it","Searching at night with no datum","Two vessels search in parallel tracks","The position is completely unknown over a huge area"]'::jsonb, 0, 'Answer A. The expanding square is used by a single unit from a reasonably known datum, searching in growing concentric legs.'),
  ('bm2:B1-005', 'BM-II', 8, 'B1.11', 'When choosing a place to beach a sinking vessel deliberately, you should prefer:', '["The nearest reef","A steep rocky lee shore","A gently shelving sheltered beach of sand or mud, clear of obstructions, ideally to windward of the shore","Anywhere with deep water close in"]'::jsonb, 2, 'Answer C. Beaching is safest on a gentle sand/mud shore, sheltered, free of rocks, where the vessel can be re-floated and people landed safely.'),
  ('bm2:B1-006', 'BM-II', 8, 'B1.2', 'If the main engine fails in a confined channel with a foul tide, the prudent first action is usually to:', '["Abandon ship at once","Let go the anchor to stop the vessel drifting into danger while you assess","Send a MAYDAY immediately","Restart repeatedly at full throttle"]'::jsonb, 1, 'Answer B. Anchoring stops uncontrolled drift and buys time to diagnose and to call for help if needed.'),
  ('bm2:B1-007', 'BM-II', 8, 'B1.3', 'On total loss of steering, an effective immediate method to maintain some directional control on a twin-screw vessel is to:', '["Go full astern","Climb the mast to rig a sail","Drop both anchors","Steer by adjusting the relative thrust of the two engines"]'::jsonb, 3, 'Answer D. With twin screws you can steer by differential engine power; on a single screw a drogue or jury rudder may be rigged.'),
  ('bm2:B1-008', 'BM-II', 8, 'B1.4', 'Immediately after a collision your first priorities are to:', '["Apportion blame in the log","Lower all anchors","Check for injuries, assess flooding/damage and stability, stand by the other vessel and be ready to render assistance","Steam away quickly"]'::jsonb, 2, 'Answer C. After a collision: people first (injuries), then assess damage/flooding and stability, render assistance and exchange details; do not leave the scene.'),
  ('bm2:B1-009', 'BM-II', 8, 'B1.5', 'After running aground on a falling tide the WORST general action is to:', '["Immediately drive full ahead to force her off, risking further damage and flooding","Check for hull damage and ingress","Sound around the vessel to find deep water","Reduce draught/heel and consider kedging off on the rising tide"]'::jsonb, 0, 'Answer A. Driving hard ahead can hole the hull and worsen flooding; assess damage first and refloat carefully, often on the rising tide.'),
  ('bm2:B1-010', 'BM-II', 8, 'B1.6', 'Faced with a serious medical emergency offshore beyond your training, the correct step is to:', '["Anchor and wait until morning","Make a PAN-PAN (or MAYDAY if life-threatening), request medical advice/evacuation and give first aid within your competence","Administer any drugs you can find","Continue the passage and hope it improves"]'::jsonb, 1, 'Answer B. Seek radio medical advice and assistance (PAN-PAN/MAYDAY as appropriate), and give first aid only within your competence.'),
  ('bm2:B1-011', 'BM-II', 8, 'B1.7', 'Which class of fire is burning electrical equipment, and what must you NOT use on it?', '["Electrical fire; do not use water or foam — isolate the supply and use CO2 or dry powder","Class B; do not use dry powder","Class F; do not use CO2","Class A; do not use foam"]'::jsonb, 0, 'Answer A. Live-electrical fires must not be fought with water/foam (conductive); isolate the supply and use CO2 or dry powder.'),
  ('bm2:B1-012', 'BM-II', 8, 'B1.7', 'A galley fat/cooking-oil fire (Class F) is best tackled with:', '["Sand thrown from windward","A jet of water","A wet chemical (Class F) or fire blanket; never water","A CO2 flood only"]'::jsonb, 2, 'Answer C. Class F fat fires need a wet-chemical extinguisher or a fire blanket to smother; water causes a violent flare-up.'),
  ('bm2:B1-013', 'BM-II', 8, 'B1.9', 'The boatmaster''s duty regarding life-saving appliances in an emergency is to:', '["Locate them when the emergency starts","Rely on passengers to find them","Keep them locked until told otherwise","Know where every LSA item is, how to deploy it, and ensure crew/passengers can use it"]'::jsonb, 3, 'Answer D. The person in charge must know the location and use of all LSA and be able to direct their deployment without delay.'),
  ('bm2:B1-014', 'BM-II', 8, 'B1.2', 'If an outboard''s kill-cord is pulled and the engine stops while under way, the immediate concern is that:', '["The fuel tank will explode","Nothing — the boat is now safe","The boat may continue in an uncontrolled circle if a crew is thrown out and the helm is unattended — refit the cord and regain control","The radio will fail"]'::jsonb, 2, 'Answer C. A kill cord stops the engine if the helmsman is displaced, preventing the classic ''circle of death''; refit it and regain control safely.'),
  ('bm2:B8-001', 'BM-II', 8, 'B8.1', 'Before getting under way the safety announcement to passengers (Reg. VIII/8) must cover at least:', '["The lunch menu","The vessel''s top speed","The crew''s home addresses","Location and use of lifejackets (with a demonstration), emergency exits, and what to do in an emergency"]'::jsonb, 3, 'Answer D. The pre-departure briefing covers lifejacket location/donning (demonstrated), exits/muster, and emergency actions.'),
  ('bm2:B8-002', 'BM-II', 8, 'B8.2', 'Disposition of passengers to maintain stability and trim means the boatmaster should:', '["Put everyone on the bow","Let everyone sit where they like","Keep all passengers standing","Distribute people so the vessel is not overloaded on one side or end, keeping a safe trim and avoiding free movement in a seaway"]'::jsonb, 3, 'Answer D. Passengers must be spread to keep the boat upright and properly trimmed; crowding to one side/end can dangerously reduce stability.'),
  ('bm2:B8-003', 'BM-II', 8, 'B8.3', 'The passenger number and reporting system (Reg. VIII/7) exists so that:', '["The number of persons on board is known and recorded ashore, and never exceeds the certified maximum","Passengers get a souvenir","Crew can be reduced","The owner can bill correctly"]'::jsonb, 0, 'Answer A. Knowing and recording the exact number on board (and not exceeding the certificate) is vital for SAR accountability and stability.'),
  ('bm2:B8-004', 'BM-II', 8, 'B8.4', 'Knowledge of emergency instructions and orderly evacuation (Reg. VIII/10) for a Grade 2 vessel requires the boatmaster to:', '["Evacuate only the crew","Improvise on the day","Rely on passengers to organise themselves","Have a plan for mustering, briefing and evacuating passengers in order, suited to the vessel''s size and area"]'::jsonb, 3, 'Answer D. There must be a practised plan for orderly muster and evacuation appropriate to the vessel and operating area, directed by the crew.'),
  ('bm2:B8-005', 'BM-II', 8, 'B8.5', 'Demonstrating personal life-saving appliances to passengers means showing them:', '["How to put on and adjust a lifejacket correctly, including any light/whistle and child versions","The price of the equipment","Only where the lifejackets are stowed","How to inflate the liferaft"]'::jsonb, 0, 'Answer A. The crew must be able to demonstrate correct donning and adjustment of lifejackets (and their attachments) to passengers.'),
  ('bm2:B8-006', 'BM-II', 8, 'B8.2', 'Carrying more passengers than the certificate permits is dangerous mainly because it:', '["Slows the boat","Improves the ride","Saves fuel","Reduces freeboard and stability and removes the safety margin, and is also unlawful"]'::jsonb, 3, 'Answer D. Overloading reduces freeboard/stability, removes reserve buoyancy and is illegal; the certified maximum must never be exceeded.'),
  ('bm2:B8-007', 'BM-II', 8, 'B8.4', 'During an orderly evacuation of passengers the crew should:', '["Evacuate in the dark to save time","Keep passengers calm, direct them to muster/exit points, assist the vulnerable, and account for everyone","Let passengers decide","Leave first to prepare the dock"]'::jsonb, 1, 'Answer B. Orderly evacuation: keep people calm, direct them to muster/exits, help the vulnerable, and account for all persons — crew lead, not leave.'),
  ('bm2:B13-001', 'BM-II', 9, 'B13.3', 'Under MARPOL, the disposal into the sea of all plastics, including synthetic ropes and garbage bags, is:', '["Allowed if ground up","Totally prohibited everywhere","Allowed beyond 12 miles","Allowed at night only"]'::jsonb, 1, 'Answer B. MARPOL Annex V prohibits the disposal of all plastics into the sea anywhere — they must be retained and landed ashore.'),
  ('bm2:B13-002', 'BM-II', 9, 'B13.2', 'When changing lubricating oil, the key precaution to prevent marine pollution is to:', '["Contain all old oil and drips and keep them clear of anything draining to the sea, landing them at a reception facility","Let spills go to the bilge","Mix oil with detergent and discharge it","Pour the old oil over the side while moving"]'::jsonb, 0, 'Answer A. Old oil and every drip must be contained and kept away from drains/bilge that reach the sea, then landed at a reception facility.'),
  ('bm2:B13-003', 'BM-II', 9, 'B13.2', 'Before pumping out the bilge, the boatmaster must:', '["Pump only at night","Add oil to lubricate the pump","Check the bilge water is not contaminated with oil; oily water must not be discharged but landed ashore","Pump regardless of content"]'::jsonb, 2, 'Answer C. Oily bilge water must never be pumped overboard; check for oil first and, if present, retain it for shore disposal.'),
  ('bm2:B13-004', 'BM-II', 9, 'B13.1', 'MARPOL is the international convention dealing with:', '["Prevention of pollution from ships","Load lines","Crew certification","Collision avoidance"]'::jsonb, 0, 'Answer A. MARPOL is the International Convention for the Prevention of Pollution from Ships, covering oil, chemicals, sewage, garbage and air pollution.'),
  ('bm2:B13-005', 'BM-II', 9, 'B13.1', 'A small fuel spill at the berth during refuelling should be dealt with by:', '["Spreading it with detergent","Stopping the source, containing it with absorbent material, and reporting it as required","Hosing it into the sea","Ignoring it if small"]'::jsonb, 1, 'Answer B. Stop the source, contain with absorbents, and report as required; never disperse oil into the sea with detergent.'),
  ('bm2:B13-006', 'BM-II', 9, 'B13.2', 'A drip tray under the engine and a clean bilge help prevent pollution by:', '["Reducing noise","Cooling the engine","Improving speed","Catching oil leaks so contaminated water is not pumped overboard"]'::jsonb, 3, 'Answer D. A drip tray and clean bilge catch oil leaks, keeping bilge water clean so it does not become oily and unlawful to discharge.'),
  ('bm2:B13-007', 'BM-II', 9, 'B13.1', 'Sewage and garbage management on a small passenger vessel should follow:', '["Owner''s preference","Discharge everything offshore","MARPOL and local requirements — retain and land ashore where discharge is restricted, and never dispose of plastics at sea","No rules inshore"]'::jsonb, 2, 'Answer C. Sewage/garbage are handled under MARPOL and local rules; in restricted/inshore waters retain and land ashore, and plastics are never discharged.'),
  ('bm2:B6-001', 'BM-II', 11, 'B6.1', 'The person in charge of the vessel must, regarding life-saving and fire-fighting appliances:', '["Test them only annually","Leave checks to passengers","Assume the owner has dealt with them","Be satisfied that they are present, in date and properly maintained before sailing"]'::jsonb, 3, 'Answer D. Reg. B6.1: the boatmaster must satisfy himself that LSA and FFA meet statutory requirements and are properly maintained before the voyage.'),
  ('bm2:B6-002', 'BM-II', 11, 'B6.1', 'Portable fire extinguishers on board should be checked to confirm they are:', '["Empty for safety","Stowed in a locked locker","Painted the right colour only","In date (within service period), correctly charged/pressurised, accessible and undamaged"]'::jsonb, 3, 'Answer D. Extinguishers must be in service date, charged (gauge in the green where fitted), unobstructed and undamaged — checked before sailing.'),
  ('bm2:B6-003', 'BM-II', 11, 'B6.5', '''Buoyant apparatus'' (e.g. buoyant seats/floats) must be maintained so that it:', '["Is the right colour","Retains its buoyancy and securing/floatation is intact, with grab-lines and markings serviceable","Is stowed below deck","Looks tidy"]'::jsonb, 1, 'Answer B. Buoyant apparatus must keep its buoyancy; check the body, grab-lines, lashings and markings so it will float and support people when needed.'),
  ('bm2:B6-004', 'BM-II', 11, 'B6.1', 'Lifejackets carried for passengers should be:', '["Inflated and ready at all times","Kept locked away","One size only, stowed centrally","Of suitable sizes (including child sizes if children carried), in good condition, readily accessible and sufficient in number"]'::jsonb, 3, 'Answer D. Sufficient serviceable lifejackets of appropriate sizes (incl. children where carried) must be readily accessible to all persons on board.'),
  ('bm2:B6-005', 'BM-II', 11, 'B6.1', 'A liferaft''s annual servicing is important because it:', '["Confirms the raft will inflate correctly and that its equipment, gas and hydrostatic release are in date and serviceable","Is only a paperwork formality","Repaints the container","Reduces its weight"]'::jsonb, 0, 'Answer A. Servicing verifies inflation, the gas system, the equipment pack and the HRU/painter so the raft works when needed; it must be kept in date.'),
  ('bm2:B6-006', 'BM-II', 11, 'B6.1', 'Lifebuoys (ring buoys) carried for instant MOB use should be:', '["Kept in the wheelhouse only","Lashed down tightly","Readily accessible on deck, with self-igniting light and/or buoyant line as fitted, ready for immediate throwing","Stowed below in a locker"]'::jsonb, 2, 'Answer C. Lifebuoys must be instantly available on deck, with their lights/lines serviceable, so one can be thrown the instant someone goes overboard.'),
  ('bm2:B7-001', 'BM-II', 11, 'B7.1', 'Which of the following is a recognised distress signal under Annex IV of the Collision Regulations?', '["Continuous sounding of a fog-signalling apparatus","A black ball hoisted","A single white flare","Three short blasts"]'::jsonb, 0, 'Answer A. Annex IV distress signals include the continuous sounding of any fog-signalling apparatus, red flares, SOS, MAYDAY, etc.'),
  ('bm2:B7-002', 'BM-II', 11, 'B7.1', 'A red hand-held flare or red parachute rocket is used to:', '["Signal you are altering course","Indicate distress and help rescuers locate you","Show you are at anchor","Mark a fishing net"]'::jsonb, 1, 'Answer B. Red pyrotechnics (hand flare/parachute rocket) are distress signals; red = distress, used to attract attention and pinpoint position.'),
  ('bm2:B7-003', 'BM-II', 11, 'B7.1', 'An orange smoke signal is primarily effective as a distress signal:', '["Underwater","In fog only","At night","By day, to mark position for searching aircraft or vessels"]'::jsonb, 3, 'Answer D. Orange smoke is a daytime distress signal, giving a position datum and wind indication for aircraft/vessels; flares are better by night.'),
  ('bm2:B7-004', 'BM-II', 11, 'B7.1', 'Slowly and repeatedly raising and lowering arms outstretched to each side is:', '["An anchoring signal","A recognised distress signal","A signal to overtake","A greeting"]'::jsonb, 1, 'Answer B. Raising and lowering outstretched arms is one of the Annex IV distress signals indicating need of assistance.'),
  ('bm2:B7-005', 'BM-II', 11, 'B7.2', 'When the Coast Guard receives your distress signal, you should expect them to:', '["Acknowledge, coordinate the SAR response, task assets and maintain communications with you","Charge a fee before responding","Ignore small craft","Wait until daylight"]'::jsonb, 0, 'Answer A. The Coast Guard/MRCC acknowledges, coordinates SAR, tasks vessels/aircraft and keeps communications going until the situation is resolved.'),
  ('bm2:B7-006', 'BM-II', 11, 'B7.1', 'An EPIRB, once activated, sends a distress alert via:', '["VHF Channel 16 voice only","A loud-hailer","A signal lamp","The Cospas-Sarsat satellite system, with a coded identity and (if GPS-equipped) position"]'::jsonb, 3, 'Answer D. An EPIRB transmits a coded 406 MHz distress alert through the Cospas-Sarsat satellites, identifying the vessel and giving position if GPS-equipped.'),
  ('bm2:B18-001', 'BM-II', 12, 'B18.1', 'The boatmaster''s responsibility for the first-aid kit is to:', '["Use it only for the crew","Assume it is complete","Keep it locked away","Know its location and contents, keep it stocked and in date, and know how to use the items"]'::jsonb, 3, 'Answer D. The boatmaster must know where the kit is, what it contains and how to use it, and keep it complete and in date.'),
  ('bm2:B18-002', 'BM-II', 12, 'B18.1', 'A marine first-aid kit should as a minimum contain:', '["Dressings, bandages, antiseptic, adhesive plasters, gloves and basic instructions","Charts","Engine spares","Flares"]'::jsonb, 0, 'Answer A. A first-aid kit holds dressings, bandages, antiseptic, plasters, protective gloves and clear instructions for use.'),
  ('bm2:B18-003', 'BM-II', 12, 'B18.1', 'If first-aid items are used or found out of date during a check, the boatmaster should:', '["Borrow from passengers","Replace/restock them promptly so the kit is complete before the next voyage","Remove the kit","Leave the gap until the next service"]'::jsonb, 1, 'Answer B. Used or expired items must be replaced promptly so the kit is complete and serviceable before sailing.'),
  ('bm2:B18-004', 'BM-II', 12, 'B18.1', 'The simplest immediate first-aid action for a small bleeding wound is to:', '["Apply direct pressure with a clean dressing and elevate if possible","Leave it open","Pour fuel on it","Apply a tourniquet at once"]'::jsonb, 0, 'Answer A. Direct pressure with a clean dressing (and elevation) controls most minor bleeding; tourniquets are only for severe, uncontrollable limb bleeding.'),
  ('bm2:B18-005', 'BM-II', 12, 'B18.1', 'For a suspected spinal injury after a fall on board, basic first-aid principle is to:', '["Move the casualty quickly to the cabin","Avoid unnecessary movement, keep the casualty still and support the head/neck while summoning help","Sit them upright at once","Have them walk it off"]'::jsonb, 1, 'Answer B. With a suspected spinal injury, minimise movement, support the head/neck and keep the casualty still while getting medical help — within your competence.')
on conflict (id) do update set
  course_code = excluded.course_code,
  module_seq  = excluded.module_seq,
  ref         = excluded.ref,
  stem        = excluded.stem,
  opts        = excluded.opts,
  correct     = excluded.correct,
  expl        = excluded.expl;

-- ---- Module-content (reader/deck-paden + gecureerde quizlijst) ----
-- Storage-paden in bucket 'course-content'. Volgnummer = modules.sequence.

update modules m set
  reader_path = 'bm2/readers/M01.pdf',
  deck_path   = 'bm2/decks/M01.pdf',
  quiz_ids    = '["bm2:B2-030","bm2:B2-031","bm2:B2-033","bm2:B3-004","bm2:B3-005","bm2:B3-006","bm2:B3-007","bm2:B3-008"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-II' and m.sequence = 1;
update modules m set
  reader_path = 'bm2/readers/M02.pdf',
  deck_path   = 'bm2/decks/M02.pdf',
  quiz_ids    = '["bm2:B3-001","bm2:B3-002","bm2:B3-003","bm2:B3-004","bm2:B3-005","bm2:B3-006","bm2:B3-007","bm2:B3-008","bm2:B3-009","bm2:B9-001","bm2:B9-002","bm2:B9-003","bm2:B9-004","bm2:B9-005","bm2:B9-006"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-II' and m.sequence = 2;
update modules m set
  reader_path = 'bm2/readers/M03.pdf',
  deck_path   = 'bm2/decks/M03.pdf',
  quiz_ids    = '["bm2:B10-001","bm2:B10-002","bm2:B10-003","bm2:B10-004","bm2:B10-005","bm2:B10-006","bm2:B14-001","bm2:B14-002","bm2:B14-003","bm2:B14-004","bm2:B14-005","bm2:B14-006","bm2:B5-001","bm2:B5-002","bm2:B5-003","bm2:B5-004","bm2:B5-005","bm2:B5-006","bm2:B5-007","bm2:B5-008"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-II' and m.sequence = 3;
update modules m set
  reader_path = 'bm2/readers/M04.pdf',
  deck_path   = 'bm2/decks/M04.pdf',
  quiz_ids    = '["bm2:B2-001","bm2:B2-002","bm2:B2-003","bm2:B2-004","bm2:B2-005","bm2:B2-006","bm2:B2-007","bm2:B2-008","bm2:B2-009","bm2:B2-010","bm2:B2-011","bm2:B2-012","bm2:B2-013","bm2:B2-014","bm2:B2-015","bm2:B2-016","bm2:B2-017","bm2:B2-018","bm2:B2-019","bm2:B2-020","bm2:B2-021","bm2:B2-022","bm2:B2-023","bm2:B2-024","bm2:B2-025","bm2:B2-026","bm2:B2-027","bm2:B2-028","bm2:B2-029","bm2:B2-030","bm2:B2-031","bm2:B2-032","bm2:B2-033","bm2:B2-034"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-II' and m.sequence = 4;
update modules m set
  reader_path = 'bm2/readers/M05.pdf',
  deck_path   = 'bm2/decks/M05.pdf',
  quiz_ids    = '["bm2:B4-001","bm2:B4-002","bm2:B4-003","bm2:B4-004","bm2:B4-005","bm2:B4-006","bm2:B4-007","bm2:B4-008","bm2:B4-009","bm2:B4-010"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-II' and m.sequence = 5;
update modules m set
  reader_path = 'bm2/readers/M06.pdf',
  deck_path   = 'bm2/decks/M06.pdf',
  quiz_ids    = '["bm2:A-001","bm2:A-002","bm2:A-003","bm2:A-004","bm2:A-005","bm2:A-006","bm2:A-007","bm2:A-008","bm2:A-009","bm2:A-010","bm2:A-011","bm2:A-012","bm2:A-013","bm2:A-014","bm2:A-015","bm2:A-016","bm2:A-017","bm2:B17-001","bm2:B17-002","bm2:B17-003","bm2:B17-004","bm2:B17-005","bm2:B17-006"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-II' and m.sequence = 6;
update modules m set
  reader_path = 'bm2/readers/M07.pdf',
  deck_path   = 'bm2/decks/M07.pdf',
  quiz_ids    = '["bm2:B11-001","bm2:B11-002","bm2:B11-003","bm2:B11-004","bm2:B11-005","bm2:B11-006","bm2:B11-007","bm2:B11-008","bm2:B11-009"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-II' and m.sequence = 7;
update modules m set
  reader_path = 'bm2/readers/M08.pdf',
  deck_path   = 'bm2/decks/M08.pdf',
  quiz_ids    = '["bm2:B1-001","bm2:B1-002","bm2:B1-003","bm2:B1-004","bm2:B1-005","bm2:B1-006","bm2:B1-007","bm2:B1-008","bm2:B1-009","bm2:B1-010","bm2:B1-011","bm2:B1-012","bm2:B1-013","bm2:B1-014","bm2:B8-001","bm2:B8-002","bm2:B8-003","bm2:B8-004","bm2:B8-005","bm2:B8-006","bm2:B8-007"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-II' and m.sequence = 8;
update modules m set
  reader_path = 'bm2/readers/M09.pdf',
  deck_path   = 'bm2/decks/M09.pdf',
  quiz_ids    = '["bm2:B13-001","bm2:B13-002","bm2:B13-003","bm2:B13-004","bm2:B13-005","bm2:B13-006","bm2:B13-007"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-II' and m.sequence = 9;
update modules m set
  reader_path = 'bm2/readers/M10.pdf',
  deck_path   = 'bm2/decks/M10.pdf',
  quiz_ids    = '["bm2:B1-011","bm2:B1-012","bm2:B6-001","bm2:B6-002","bm2:B11-007"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-II' and m.sequence = 10;
update modules m set
  reader_path = 'bm2/readers/M11.pdf',
  deck_path   = 'bm2/decks/M11.pdf',
  quiz_ids    = '["bm2:B6-001","bm2:B6-002","bm2:B6-003","bm2:B6-004","bm2:B6-005","bm2:B6-006","bm2:B7-001","bm2:B7-002","bm2:B7-003","bm2:B7-004","bm2:B7-005","bm2:B7-006"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-II' and m.sequence = 11;
update modules m set
  reader_path = 'bm2/readers/M12.pdf',
  deck_path   = 'bm2/decks/M12.pdf',
  quiz_ids    = '["bm2:B18-001","bm2:B18-002","bm2:B18-003","bm2:B18-004","bm2:B18-005"]'::jsonb
from courses c
where m.course_id = c.id and c.code = 'BM-II' and m.sequence = 12;

-- Klaar.
