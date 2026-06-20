-- ============================================================
-- Plaza Boat College — ISO 9001 QMS-registers
-- Migratie 0003 — incidenten/ongevallen, bijna-ongevallen,
-- klachten en verbeteringen (CAPA).
-- ------------------------------------------------------------
-- Idempotent (veilig her-uitvoerbaar). Volgt de stijl van schema.sql.
-- Voer dit 1x uit in de Supabase SQL Editor NA schema.sql + qms.sql.
-- RLS: staff (admin/instructor) volledige toegang; ILT-inspecteur
-- (auditor) leest mee; cursisten geen toegang.
-- ============================================================

-- ------------------------------------------------------------
-- 1. QMS_INCIDENTS — ongevallen + bijna-ongevallen
--    kind: 'ongeval' / 'bijna_ongeval'
--    severity: 'laag' / 'middel' / 'hoog'
--    status: 'open' / 'in_behandeling' / 'gesloten'
-- ------------------------------------------------------------
create table if not exists qms_incidents (
  id                uuid primary key default gen_random_uuid(),
  ref               text,                  -- bv. INC-2026-001 (server-side gegenereerd)
  kind              text not null check (kind in ('ongeval','bijna_ongeval')),
  report_date       date,
  reporter_name     text,
  course_code       text,                  -- 'BM-I' / 'BM-II' / 'BM-III' / null = n.v.t.
  location          text,
  description       text,
  severity          text check (severity in ('laag','middel','hoog')),
  immediate_action  text,                  -- directe (corrigerende) actie
  root_cause        text,                  -- oorzaakanalyse
  corrective_action text,                  -- corrigerende/preventieve maatregel
  owner             text,                  -- eigenaar/verantwoordelijke
  due_date          date,
  status            text not null default 'open' check (status in ('open','in_behandeling','gesloten')),
  closed_date       date,
  created_by        uuid default auth.uid(),
  created_at        timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 2. QMS_COMPLAINTS — klachtenregister
-- ------------------------------------------------------------
create table if not exists qms_complaints (
  id           uuid primary key default gen_random_uuid(),
  ref          text,                       -- bv. KL-2026-001
  report_date  date,
  complainant  text,                       -- klager
  course_code  text,                       -- 'BM-I' / 'BM-II' / 'BM-III' / null = n.v.t.
  channel      text,                       -- kanaal (e-mail/telefoon/persoonlijk/...)
  description  text,
  category     text,                       -- categorie (communicatie/planning/...)
  action       text,                       -- afhandeling/maatregel
  owner        text,
  due_date     date,
  status       text not null default 'open' check (status in ('open','in_behandeling','gesloten')),
  closed_date  date,
  created_by   uuid default auth.uid(),
  created_at   timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 3. QMS_IMPROVEMENTS — verbeterregister (CAPA)
--    type: 'correctief' / 'preventief' / 'verbetering'
-- ------------------------------------------------------------
create table if not exists qms_improvements (
  id                  uuid primary key default gen_random_uuid(),
  ref                 text,                -- bv. VB-2026-001
  raised_date         date,
  source              text,                -- bron (audit/feedback/incident/inspectie/...)
  course_code         text,               -- 'BM-I' / 'BM-II' / 'BM-III' / null = n.v.t.
  description         text,
  type                text check (type in ('correctief','preventief','verbetering')),
  action              text,
  owner               text,
  due_date            date,
  status              text not null default 'open' check (status in ('open','in_behandeling','gesloten')),
  effectiveness_check text,                -- doeltreffendheidstoets (ISO 9001 §10.2)
  closed_date         date,
  created_by          uuid default auth.uid(),
  created_at          timestamptz not null default now()
);

-- ------------------------------------------------------------
-- Indexen — filtering op status/opleiding + nieuwste eerst
-- ------------------------------------------------------------
create index if not exists idx_qms_incidents_status     on qms_incidents (status);
create index if not exists idx_qms_incidents_course     on qms_incidents (course_code);
create index if not exists idx_qms_incidents_created    on qms_incidents (created_at desc);

create index if not exists idx_qms_complaints_status    on qms_complaints (status);
create index if not exists idx_qms_complaints_course    on qms_complaints (course_code);
create index if not exists idx_qms_complaints_created   on qms_complaints (created_at desc);

create index if not exists idx_qms_improvements_status  on qms_improvements (status);
create index if not exists idx_qms_improvements_course  on qms_improvements (course_code);
create index if not exists idx_qms_improvements_created on qms_improvements (created_at desc);

-- ------------------------------------------------------------
-- Audit-triggers (zelfde fn_audit als de overige registers)
-- ------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['qms_incidents','qms_complaints','qms_improvements']
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
alter table qms_incidents    enable row level security;
alter table qms_complaints   enable row level security;
alter table qms_improvements enable row level security;

drop policy if exists p_qms_incidents_all on qms_incidents;
create policy p_qms_incidents_all on qms_incidents for all
  using ( is_staff() ) with check ( is_staff() );
drop policy if exists p_qms_incidents_read on qms_incidents;
create policy p_qms_incidents_read on qms_incidents for select
  using ( can_read_all() );

drop policy if exists p_qms_complaints_all on qms_complaints;
create policy p_qms_complaints_all on qms_complaints for all
  using ( is_staff() ) with check ( is_staff() );
drop policy if exists p_qms_complaints_read on qms_complaints;
create policy p_qms_complaints_read on qms_complaints for select
  using ( can_read_all() );

drop policy if exists p_qms_improvements_all on qms_improvements;
create policy p_qms_improvements_all on qms_improvements for all
  using ( is_staff() ) with check ( is_staff() );
drop policy if exists p_qms_improvements_read on qms_improvements;
create policy p_qms_improvements_read on qms_improvements for select
  using ( can_read_all() );

-- Klaar. Voer hierna optioneel seed-qms-documents.sql uit.
