-- Cursisttevredenheid (ISO 9001 §9.1.2 / doelstelling D5).
create table if not exists qms_satisfaction (
  id uuid primary key default gen_random_uuid(),
  course_code text, period text, survey_date date,
  respondents integer, avg_score numeric(3,1), comments text,
  recorded_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);
alter table qms_satisfaction enable row level security;
drop policy if exists p_qms_sat_all on qms_satisfaction;
create policy p_qms_sat_all on qms_satisfaction for all using (is_staff()) with check (is_staff());
drop policy if exists p_qms_sat_read on qms_satisfaction;
create policy p_qms_sat_read on qms_satisfaction for select using (can_read_all());
