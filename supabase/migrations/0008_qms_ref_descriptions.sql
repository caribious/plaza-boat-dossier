-- Officiële betekenis per SCV/Annex 11-bronverwijzing (syllabus-dekkingsmatrix).
create table if not exists qms_ref_descriptions (
  ref text primary key,
  description text not null,
  source text default 'SCV Code / Annex 11 dekkingsoverzicht',
  created_at timestamptz not null default now()
);
alter table qms_ref_descriptions enable row level security;
drop policy if exists p_qms_refdesc_read on qms_ref_descriptions;
create policy p_qms_refdesc_read on qms_ref_descriptions for select using (can_read_all());
drop policy if exists p_qms_refdesc_all on qms_ref_descriptions;
create policy p_qms_refdesc_all on qms_ref_descriptions for all using (is_staff()) with check (is_staff());
