-- Geauthenticeerde ondertekening van QMS-documenten (§7.5). Onveranderbaar.
create table if not exists qms_document_signatures (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references qms_documents(id) on delete cascade,
  signer_profile_id uuid not null default auth.uid(),
  signer_name text not null, signer_role text,
  statement text default 'Vastgesteld en ondertekend',
  signed_at timestamptz not null default now(),
  unique (document_id, signer_profile_id)
);
alter table qms_document_signatures enable row level security;
drop policy if exists p_qms_docsig_read on qms_document_signatures;
create policy p_qms_docsig_read on qms_document_signatures for select using (can_read_all());
drop policy if exists p_qms_docsig_sign on qms_document_signatures;
create policy p_qms_docsig_sign on qms_document_signatures for insert with check (is_staff() and signer_profile_id = auth.uid());
