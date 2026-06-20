-- ============================================================
-- Plaza Boat College — ISO 9001 KPI's, kwaliteitsdoelstellingen
-- en risicoregister.
-- Migratie 0004 — qms_objectives (kwaliteitsdoelstellingen)
-- en qms_risks (risicoregister, ISO 9001 §6.1 risico's & kansen).
-- ------------------------------------------------------------
-- Idempotent (veilig her-uitvoerbaar). Volgt de stijl van 0003.
-- Voer dit 1x uit in de Supabase SQL Editor NA 0003_qms_registers.sql.
-- RLS: staff (admin/instructor) volledige toegang; ILT-inspecteur
-- (auditor) leest mee; cursisten geen toegang.
-- ============================================================

-- ------------------------------------------------------------
-- 1. QMS_OBJECTIVES — kwaliteitsdoelstellingen (ISO 9001 §6.2)
--    target = streefwaarde (numeriek). De actuele waarde wordt
--    waar mogelijk LIVE in de UI berekend uit de operationele data;
--    waar dat niet kan toont de UI '—' (handmatige beoordeling).
-- ------------------------------------------------------------
create table if not exists qms_objectives (
  id          uuid primary key default gen_random_uuid(),
  code        text,                  -- bv. 'D1' (kort kenmerk)
  naam        text not null,         -- korte naam van de doelstelling
  doelstelling text,                 -- volledige formulering
  target      numeric,               -- streefwaarde (numeriek)
  eenheid     text,                  -- '%', 'punten', 'aantal', 'x/jaar', ...
  meet_bron   text,                  -- waar de actuele waarde vandaan komt
  periode     text,                  -- meetperiode (bv. 'jaarlijks', 'doorlopend')
  sort_order  int not null default 0,
  created_at  timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 2. QMS_RISKS — risicoregister (ISO 9001 §6.1)
--    likelihood (1..5) x impact (1..5) = score (1..25)
--    response: 'vermijden' / 'beperken' / 'delen' / 'accepteren'
--    status:   'open' / 'in_behandeling' / 'gesloten'
-- ------------------------------------------------------------
create table if not exists qms_risks (
  id           uuid primary key default gen_random_uuid(),
  ref          text,                       -- bv. RIS-2026-001 (server-side gegenereerd)
  raised_date  date,
  context      text,                       -- context/omgeving (intern/extern)
  course_code  text,                       -- 'BM-I' / 'BM-II' / 'BM-III' / null = n.v.t.
  description  text,                        -- omschrijving van het risico
  category     text,                        -- categorie (veiligheid/kwaliteit/planning/...)
  likelihood   int check (likelihood between 1 and 5),
  impact       int check (impact between 1 and 5),
  score        int,                         -- likelihood x impact (1..25)
  response     text,                        -- vermijden/beperken/delen/accepteren
  action       text,                        -- beheersmaatregel
  owner        text,
  due_date     date,
  status       text not null default 'open' check (status in ('open','in_behandeling','gesloten')),
  closed_date  date,
  created_by   uuid default auth.uid(),
  created_at   timestamptz not null default now()
);

-- ------------------------------------------------------------
-- Indexen — filtering + nieuwste eerst
-- ------------------------------------------------------------
create index if not exists idx_qms_objectives_sort   on qms_objectives (sort_order);

create index if not exists idx_qms_risks_status       on qms_risks (status);
create index if not exists idx_qms_risks_course       on qms_risks (course_code);
create index if not exists idx_qms_risks_score        on qms_risks (score desc);
create index if not exists idx_qms_risks_created       on qms_risks (created_at desc);

-- ------------------------------------------------------------
-- Audit-triggers (zelfde fn_audit als de overige registers)
-- ------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['qms_objectives','qms_risks']
  loop
    execute format('drop trigger if exists audit_%1$s on %1$s;', t);
    execute format('create trigger audit_%1$s after insert or update or delete on %1$s
                    for each row execute function public.fn_audit();', t);
  end loop;
end $$;

-- ------------------------------------------------------------
-- RLS — staff bewerkt (select/insert/update/delete);
--       staff + ILT-inspecteur lezen; cursisten geen toegang.
-- ------------------------------------------------------------
alter table qms_objectives enable row level security;
alter table qms_risks      enable row level security;

drop policy if exists p_qms_objectives_all on qms_objectives;
create policy p_qms_objectives_all on qms_objectives for all
  using ( is_staff() ) with check ( is_staff() );
drop policy if exists p_qms_objectives_read on qms_objectives;
create policy p_qms_objectives_read on qms_objectives for select
  using ( can_read_all() );

drop policy if exists p_qms_risks_all on qms_risks;
create policy p_qms_risks_all on qms_risks for all
  using ( is_staff() ) with check ( is_staff() );
drop policy if exists p_qms_risks_read on qms_risks;
create policy p_qms_risks_read on qms_risks for select
  using ( can_read_all() );

-- ------------------------------------------------------------
-- Seed — kwaliteitsdoelstellingen voor een maritieme opleider.
-- Alleen seeden wanneer de tabel nog leeg is (idempotent).
-- ------------------------------------------------------------
insert into qms_objectives (code, naam, doelstelling, target, eenheid, meet_bron, periode, sort_order)
select * from (values
  ('D1', 'Slaagpercentage theorie',
   'Het slaagpercentage op de theorie-/kennistoetsen bedraagt minimaal 80%.',
   80, '%', 'quiz_attempts (mock) + exam_results (knowledge_mcq)', 'doorlopend', 1),
  ('D2', 'Klachten tijdig afgehandeld',
   'Minimaal 95% van de klachten wordt binnen 20 werkdagen afgehandeld.',
   95, '%', 'qms_complaints (status gesloten t.o.v. streefdatum)', 'doorlopend', 2),
  ('D3', 'CAPA-acties op tijd afgerond',
   'Minimaal 90% van de verbeter-/CAPA-acties wordt vóór de streefdatum afgerond.',
   90, '%', 'qms_improvements (gesloten zonder overschrijding streefdatum)', 'doorlopend', 3),
  ('D4', 'Geen ongevallen met ernstig letsel',
   'Nul ongevallen met ernstig letsel (ernst hoog) per jaar.',
   0, 'aantal', 'qms_incidents (kind ongeval, ernst hoog, lopend jaar)', 'jaarlijks', 4),
  ('D5', 'Cursisttevredenheid',
   'De gemiddelde cursisttevredenheid bedraagt minimaal 4,2 op een schaal van 5.',
   4.2, 'punten', 'cursistevaluaties (handmatig ingevoerd)', 'jaarlijks', 5),
  ('D6', 'Interne audit + directiebeoordeling',
   'Minimaal eenmaal per jaar een interne audit en een directiebeoordeling uitvoeren.',
   1, 'x/jaar', 'qms_documents / auditplanning (handmatige bevestiging)', 'jaarlijks', 6)
) as v(code, naam, doelstelling, target, eenheid, meet_bron, periode, sort_order)
where not exists (select 1 from qms_objectives);

-- Klaar.
