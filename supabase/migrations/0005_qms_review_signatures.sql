-- Geauthenticeerde ondertekening van interne audit (§9.2) en directiebeoordeling (§9.3).
-- Onveranderbaar: alleen invoegen en lezen.
create table if not exists qms_review_signatures (
  id                uuid primary key default gen_random_uuid(),
  review_id         uuid not null references qms_reviews(id) on delete cascade,
  signer_profile_id uuid not null default auth.uid(),
  signer_name       text not null,
  signer_role       text,
  statement         text default 'Vastgesteld en ondertekend',
  signed_at         timestamptz not null default now(),
  unique (review_id, signer_profile_id)
);
alter table qms_review_signatures enable row level security;
drop policy if exists p_qms_revsig_read on qms_review_signatures;
create policy p_qms_revsig_read on qms_review_signatures for select using (can_read_all());
drop policy if exists p_qms_revsig_sign on qms_review_signatures;
create policy p_qms_revsig_sign on qms_review_signatures for insert with check (is_staff() and signer_profile_id = auth.uid());
