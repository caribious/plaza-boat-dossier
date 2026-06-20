-- ============================================================
-- Plaza Boat College — Toelatingseisen & kwalificaties per cursist
-- Migratie 0005 — generieke registratie van toelatingseisen/
-- kwalificaties (VHF, medisch, EHBO, GMDSS/GOC, vaartijd, overig).
-- ------------------------------------------------------------
-- Concrete aanleiding: een geldig VHF-certificaat
--   (SCV Code X / 6.1 — Reg 10.11) moet aantoonbaar zijn vastgelegd.
-- ------------------------------------------------------------
-- Idempotent (veilig her-uitvoerbaar). Volgt de stijl van schema.sql.
-- Voer dit 1x uit in de Supabase SQL Editor NA schema.sql.
-- RLS: staff (admin/instructor) volledige toegang; ILT-inspecteur
-- (auditor) leest mee; de cursist leest ALLEEN zijn eigen rijen.
-- Voer hierna storage-qualifications.sql uit voor de documenten.
-- ============================================================

-- ------------------------------------------------------------
-- STUDENT_QUALIFICATIONS — toelatingseisen/kwalificaties per cursist
--   kind = vrije code; aanbevolen waarden:
--     'vhf'        VHF-certificaat (SCV Code X/6.1 — Reg 10.11)
--     'medical'    Medisch certificaat (geneeskundige verklaring)
--     'first_aid'  EHBO / First Aid
--     'gmdss_goc'  GMDSS / GOC (General Operator's Certificate)
--     'sea_service' Vaartijd / seagoing service
--     'other'      Overige toelatingseis/kwalificatie
-- ------------------------------------------------------------
create table if not exists student_qualifications (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references students(id) on delete cascade,
  kind         text not null,            -- vrije code (zie aanbevolen waarden hierboven)
  title        text,                     -- omschrijving, bv. 'VHF/SRC Marifooncertificaat'
  number       text,                     -- certificaat-/registratienummer
  issuer       text,                     -- uitgevende instantie (bv. Agentschap Telecom / RYA)
  issue_date   date,                     -- afgiftedatum
  valid_until  date,                     -- geldig t/m (null = onbeperkt geldig)
  verified     boolean not null default false,  -- door staff geverifieerd
  verified_by  text,                     -- naam staf die verifieerde
  verified_at  date,                     -- datum verificatie
  file_path    text,                     -- pad in Storage (PDF/afbeelding): <student_id>/<id>.<ext>
  notes        text,
  created_at   timestamptz not null default now()
);

-- ------------------------------------------------------------
-- Indexen — opzoeken per cursist, per type en op vervaldatum
-- ------------------------------------------------------------
create index if not exists idx_student_qual_student     on student_qualifications (student_id);
create index if not exists idx_student_qual_kind        on student_qualifications (kind);
create index if not exists idx_student_qual_valid_until on student_qualifications (valid_until);

-- ------------------------------------------------------------
-- Audit-trigger (zelfde fn_audit als de overige registers)
-- ------------------------------------------------------------
drop trigger if exists audit_student_qualifications on student_qualifications;
create trigger audit_student_qualifications
  after insert or update or delete on student_qualifications
  for each row execute function public.fn_audit();

-- ------------------------------------------------------------
-- RLS — staff bewerkt (alles); staff + ILT-inspecteur lezen;
--       de cursist leest UITSLUITEND zijn eigen rijen.
-- ------------------------------------------------------------
alter table student_qualifications enable row level security;

-- Lezen: staff + auditor alles; cursist alleen eigen rijen
drop policy if exists p_student_qual_select on student_qualifications;
create policy p_student_qual_select on student_qualifications for select
  using ( can_read_all() or student_id = my_student_id() );

-- Schrijven (insert/update/delete): alleen staff
drop policy if exists p_student_qual_staff on student_qualifications;
create policy p_student_qual_staff on student_qualifications for all
  using ( is_staff() ) with check ( is_staff() );

-- Klaar. Voer hierna storage-qualifications.sql uit.
