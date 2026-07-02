-- ============================================================
-- Plaza Boat College — ILT-aanvraagdossier (erkenning opleiding)
-- Migratie 0010 — mappenstructuur (14 componenten per graad)
-- met uploadregistratie, plus storage-bucket 'ilt-dossier'.
-- ------------------------------------------------------------
-- Idempotent (veilig her-uitvoerbaar). Volgt de stijl van schema.sql.
-- RLS: staff (admin/instructor) volledige toegang; ILT-inspecteur
-- (auditor) leest mee; cursisten geen toegang.
-- ============================================================

-- ------------------------------------------------------------
-- 1. ILT_FOLDERS — de vaste componentenstructuur per graad
-- ------------------------------------------------------------
create table if not exists ilt_folders (
  id           uuid primary key default gen_random_uuid(),
  course_code  text not null check (course_code in ('BM-I','BM-II','BM-III')),
  component_no int  not null check (component_no between 0 and 14),
  title        text not null,
  description  text,
  created_at   timestamptz not null default now(),
  unique (course_code, component_no)
);

-- ------------------------------------------------------------
-- 2. ILT_FILES — geüploade stukken per component
-- ------------------------------------------------------------
create table if not exists ilt_files (
  id          uuid primary key default gen_random_uuid(),
  folder_id   uuid not null references ilt_folders(id) on delete cascade,
  file_name   text not null,
  file_path   text not null,          -- pad in bucket 'ilt-dossier'
  created_by  uuid default auth.uid(),
  created_at  timestamptz not null default now()
);

alter table ilt_folders enable row level security;
alter table ilt_files   enable row level security;

drop policy if exists p_iltf_staff on ilt_folders;
create policy p_iltf_staff on ilt_folders for all
  using ( is_staff() ) with check ( is_staff() );
drop policy if exists p_iltf_read on ilt_folders;
create policy p_iltf_read on ilt_folders for select
  using ( can_read_all() );

drop policy if exists p_iltd_staff on ilt_files;
create policy p_iltd_staff on ilt_files for all
  using ( is_staff() ) with check ( is_staff() );
drop policy if exists p_iltd_read on ilt_files;
create policy p_iltd_read on ilt_files for select
  using ( can_read_all() );

-- ------------------------------------------------------------
-- 3. Storage-bucket 'ilt-dossier'
--    Padconventie: <course_code>/<component_no>/<bestandsnaam>
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('ilt-dossier', 'ilt-dossier', false)
on conflict (id) do nothing;

drop policy if exists p_iltdossier_all on storage.objects;
create policy p_iltdossier_all on storage.objects for all
  using ( bucket_id = 'ilt-dossier' and is_staff() )
  with check ( bucket_id = 'ilt-dossier' and is_staff() );
drop policy if exists p_iltdossier_read on storage.objects;
create policy p_iltdossier_read on storage.objects for select
  using ( bucket_id = 'ilt-dossier' and can_read_all() );

-- ------------------------------------------------------------
-- 4. Seed: componenten 00–14 voor BM-I, BM-II en BM-III
-- ------------------------------------------------------------
insert into ilt_folders (course_code, component_no, title, description)
select g.course_code, c.no, c.title, c.descr
from (values ('BM-I'), ('BM-II'), ('BM-III')) as g(course_code)
cross join (values
  (0,  'Aanbiedingsbrief & aanvraagformulier',
       'Aanbiedingsbrief aan de ILT, ondertekend MijnILT-aanvraagformulier, voorblad en inhoudsopgave.'),
  (1,  'Lesmateriaal',
       'Student readers, PowerPoint-decks en reference annexes. Let op: MijnILT accepteert max. 50 bestanden voor dit onderdeel.'),
  (2,  'Lesplan',
       'Course Programme / lesplan met dag-voor-dag-indeling en Annex 11-mapping. Max. 10 bestanden.'),
  (3,  'Examens en examenprocedure',
       'Vragenbank, examenversies + antwoordsleutels, mock-examens, testmatrix en de examenprocedure.'),
  (4,  'Eisen aan docenten',
       'Eisen aan docenten en instructeurs, incl. Instructor Code of Conduct.'),
  (5,  'Instructeurs en docenten',
       'Overzicht + autorisatiematrix én de instructeurscertificaten zelf (RYA Powerboat Instructor, VHF-SRC, FFA, PST, EFR) met nummer en geldigheid. Praktijkinstructeurs brand & sea survival bij naam.'),
  (6,  'Voorbeeldcertificaten BoatMaster',
       'Specimen-certificaat met correcte SCV Code/RVZ-verwijzing.'),
  (7,  'Auditrapport',
       'Meest recente RYA-auditrapport. Let op: RYA RTC-certificaat verlopen per 31-03-2026 — eerst verlengen.'),
  (8,  'Kwaliteitssysteem',
       'Kwaliteitshandboek/QMS, RYA/MCA-onderbouwing (gelijkwaardigheid), routekaart ISO 9001 en geldig RYA RTC-certificaat.'),
  (9,  'Uitrusting en apparatuur',
       'Specificatie uitrusting en apparatuur, incl. praktijkvaartuig met geldig SCV Safety Certificate.'),
  (10, 'Maximaal aantal deelnemers',
       'Onderbouwing maximale groepsgrootte (8 cursisten).'),
  (11, 'Link e-learning omgeving',
       'Werkende link naar de e-learning-omgeving met alle modules van deze graad geüpload.'),
  (12, 'Inloggegevens e-learning',
       'Werkende inloggegevens voor de ILT (niet alleen de link).'),
  (13, 'Identiteitscheck procedure',
       'Procedure identiteitscontrole van cursisten.'),
  (14, 'Procedure hulpvragen cursisten',
       'Procedure voor vragen/ondersteuning van cursisten.')
) as c(no, title, descr)
on conflict (course_code, component_no) do nothing;

-- Graadspecifieke aanvullingen
update ilt_folders set description =
  'Overzicht + autorisatiematrix én de instructeurscertificaten zelf. EXTRA BM I: bewijs Grade 1-examenbevoegdheid — hogere handling-kwalificatie examinator (Yachtmaster/Advanced Powerboat of hoger), GMDSS GOC en exposed-water-ervaring op 12–24 m.'
  where course_code = 'BM-I' and component_no = 5;
update ilt_folders set description =
  'Overzicht + autorisatiematrix én de instructeurscertificaten zelf. EXTRA BM II: bewijs Grade 2-examinator — hogere handling-kwalificatie + vaarervaring op vaartuigen tot 24 m.'
  where course_code = 'BM-II' and component_no = 5;
update ilt_folders set description =
  'Specificatie uitrusting en apparatuur. EXTRA BM I: 12–24 m praktijkvaartuig met geldig SCV Safety Certificate — certificaat bijvoegen (X/8.2 deel 3).'
  where course_code = 'BM-I' and component_no = 9;
