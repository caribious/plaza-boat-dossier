-- ============================================================
-- DEMO-SEED — Plaza Boat College Student Records
-- Voer dit uit NA schema.sql om het systeem direct te kunnen
-- uittesten. Maakt twee inlogaccounts en één voorbeelddossier.
--
--   Admin    : admin@plazaboatcollege.test   / Password123!
--   Student  : student@plazaboatcollege.test / Password123!
--   ILT      : ilt@plazaboatcollege.test     / Password123!  (inspecteur, read-only)
--
-- LET OP: dit is alleen voor een demo-/testomgeving.
-- Verwijder deze accounts voordat je live gaat.
-- ============================================================

do $$
declare
  v_admin_id   uuid := gen_random_uuid();
  v_student_id uuid := gen_random_uuid();
  v_ilt_id     uuid := gen_random_uuid();
  v_course_id  uuid;
  v_enroll_id  uuid;
  v_stud_rec   uuid;
  v_instr      uuid;
  m record;
begin
  -- ---------- Auth-gebruikers ----------
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data
  ) values
  ('00000000-0000-0000-0000-000000000000', v_admin_id, 'authenticated','authenticated',
   'admin@plazaboatcollege.test', crypt('Password123!', gen_salt('bf')),
   now(), now(), now(),
   '{"provider":"email","providers":["email"]}',
   '{"full_name":"Beheerder Plaza Boat College","role":"admin"}'),
  ('00000000-0000-0000-0000-000000000000', v_student_id, 'authenticated','authenticated',
   'student@plazaboatcollege.test', crypt('Password123!', gen_salt('bf')),
   now(), now(), now(),
   '{"provider":"email","providers":["email"]}',
   '{"full_name":"Demo Cursist","role":"student"}'),
  ('00000000-0000-0000-0000-000000000000', v_ilt_id, 'authenticated','authenticated',
   'ilt@plazaboatcollege.test', crypt('Password123!', gen_salt('bf')),
   now(), now(), now(),
   '{"provider":"email","providers":["email"]}',
   '{"full_name":"ILT Inspecteur","role":"auditor"}');

  -- Identities (nodig voor e-mail/wachtwoord-login)
  insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values
  (v_admin_id::text,   v_admin_id,   format('{"sub":"%s","email":"%s"}', v_admin_id,   'admin@plazaboatcollege.test')::jsonb,   'email', now(), now(), now()),
  (v_student_id::text, v_student_id, format('{"sub":"%s","email":"%s"}', v_student_id, 'student@plazaboatcollege.test')::jsonb, 'email', now(), now(), now()),
  (v_ilt_id::text,     v_ilt_id,     format('{"sub":"%s","email":"%s"}', v_ilt_id,     'ilt@plazaboatcollege.test')::jsonb,     'email', now(), now(), now());

  -- Profiles worden automatisch aangemaakt door de trigger handle_new_user().

  -- ---------- Cursistdossier ----------
  select id into v_course_id from courses where code = 'BM-III';

  insert into students (profile_id, student_number, first_name, last_name, date_of_birth, place_of_birth,
                        email, phone, nationality, address, identity_verified, id_document_type)
  values (v_student_id, 'PBC-2026-0001', 'Demo', 'Cursist', '1998-04-12', 'Kralendijk, Bonaire',
          'student@plazaboatcollege.test', '+599 700 0000', 'Nederlandse',
          'Plaza Marina, Bonaire', true, 'Paspoort')
  returning id into v_stud_rec;

  insert into enrollments (student_id, course_id, status, start_date, target_end_date)
  values (v_stud_rec, v_course_id, 'active', date '2026-05-01', date '2026-07-15')
  returning id into v_enroll_id;

  -- Voortgang per module: eerste helft afgerond, rest onderweg/open
  for m in select id, sequence from modules where course_id = v_course_id order by sequence loop
    insert into module_progress (enrollment_id, module_id, status, hours_logged, completed_at, instructor_name)
    values (
      v_enroll_id, m.id,
      case when m.sequence <= 6 then 'completed'::progress_status
           when m.sequence <= 8 then 'in_progress'::progress_status
           else 'not_started'::progress_status end,
      case when m.sequence <= 6 then 8.0 when m.sequence <= 8 then 4.0 else 0 end,
      case when m.sequence <= 6 then now() - (m.sequence || ' days')::interval else null end,
      'R. Janssen (RYA Chief Instructor)'
    );
  end loop;

  -- Examenresultaten: kennistoets gehaald, mondeling gepland, praktijk open
  insert into exam_results (enrollment_id, kind, attempt, exam_date, examiner_name, score, max_score, outcome, valid_until, remarks) values
  (v_enroll_id, 'knowledge_mcq', 1, date '2026-06-10', 'M. de Vries (extern examinator)', 44, 50, 'passed', date '2027-06-10', 'Ondersteunende kennistoets SCV X/8.5'),
  (v_enroll_id, 'oral',          1, date '2026-06-25', 'M. de Vries (extern examinator)', null, null, 'pending', null, 'Gepland — mondeling examen X/8.1'),
  (v_enroll_id, 'practical',     1, null,              null,                              null, null, 'pending', null, 'Praktijktoets X/8.1 nog in te plannen');

  -- Certificatenregister (voorbeeld deelcertificaat)
  insert into certificates (student_id, course_id, certificate_number, title, regulatory_reference, issued_date, expiry_date)
  values (v_stud_rec, v_course_id, 'PBC-FFA-2026-0001', 'Elementary First Aid & Fire Fighting (deelcertificaat)',
          'SCV Code Ch X / RVZ Bijlage 6', date '2026-06-08', date '2031-06-08');

  -- ---------- Instructeurregister ----------
  insert into instructors (first_name, last_name, title, email, active)
  values ('Rik', 'Janssen', 'RYA Chief Instructor', 'rik@plazaboatcollege.test', true)
  returning id into v_instr;

  insert into instructor_certificates (instructor_id, cert_type, certificate_number, issuing_body, issued_date, expiry_date) values
  (v_instr, 'RYA Powerboat Instructor',  'RYA-PBI-12345', 'RYA',          date '2023-03-01', date '2028-03-01'),
  (v_instr, 'VHF/SRC Assessor',          'RYA-SRC-06789', 'RYA',          date '2022-06-01', date '2027-06-01'),
  (v_instr, 'Fire Fighting (FFA)',       'FFA-2024-022',  'MCA approved', date '2024-01-15', date '2029-01-15'),
  (v_instr, 'Personal Survival (PST)',   'PST-2024-008',  'MCA approved', date '2024-01-15', date '2029-01-15');

end $$;
