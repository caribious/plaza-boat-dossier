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
