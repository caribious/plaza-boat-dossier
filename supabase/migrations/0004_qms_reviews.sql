-- ============================================================
-- Plaza Boat College — ISO 9001 audit- & beoordelingscyclus
-- Migratie 0004 — interne audit (§9.2) en directiebeoordeling (§9.3)
-- Idempotent. RLS: staff volledige toegang; auditor leest mee.
-- ============================================================
create table if not exists qms_reviews (
  id             uuid primary key default gen_random_uuid(),
  ref            text,
  kind           text not null check (kind in ('interne_audit','directiebeoordeling')),
  planned_date   date,
  completed_date date,
  scope          text,
  summary        text,
  owner          text,
  status         text not null default 'gepland' check (status in ('gepland','uitgevoerd','afgerond')),
  created_by     uuid default auth.uid(),
  created_at     timestamptz not null default now()
);

alter table qms_reviews enable row level security;

drop policy if exists p_qms_reviews_all on qms_reviews;
create policy p_qms_reviews_all on qms_reviews for all
  using (is_staff()) with check (is_staff());

drop policy if exists p_qms_reviews_read on qms_reviews;
create policy p_qms_reviews_read on qms_reviews for select
  using (can_read_all());
