-- ============================================================
-- Plaza Boat College — Kwaliteitsmodule (ISO 9001-gericht)
-- Voer dit uit NA schema.sql (1x).
-- Bevat: clausuleregister (kwaliteitshandboek) + documentenbibliotheek
-- + storage-bucket. RLS: staff bewerkt, ILT-inspecteur leest mee.
-- LET OP: dit is een EIGEN kwaliteitshandboek dat de ISO 9001-STRUCTUUR
-- volgt; het bevat NIET de (auteursrechtelijk beschermde) normtekst.
-- ============================================================

-- ------------------------------------------------------------
-- 1. QMS_CLAUSES — kwaliteitshandboek per ISO 9001-hoofdstuk
-- ------------------------------------------------------------
create table if not exists qms_clauses (
  id            uuid primary key default gen_random_uuid(),
  clause_number text not null,          -- '4', '5', ... '10'
  title         text not null,          -- hoofdstuktitel
  pbc_approach  text,                   -- Plaza Boat College's eigen invulling (origineel)
  sort_order    int not null default 0,
  updated_at    timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 2. QMS_DOCUMENTS — documentenbibliotheek (per clausule)
-- ------------------------------------------------------------
create table if not exists qms_documents (
  id            uuid primary key default gen_random_uuid(),
  clause_number text,                   -- koppeling aan hoofdstuk (optioneel)
  title         text not null,
  doc_type      text,                   -- 'Procedure' / 'Beleid' / 'Audit' / 'Bewijsstuk' / 'Norm (eigen licentie)'
  reference     text,                   -- bv. documentnummer/versie
  file_path     text,                   -- pad in Supabase Storage (PDF)
  created_at    timestamptz not null default now()
);

-- Audit-triggers
do $$
declare t text;
begin
  foreach t in array array['qms_clauses','qms_documents']
  loop
    execute format('drop trigger if exists audit_%1$s on %1$s;', t);
    execute format('create trigger audit_%1$s after insert or update or delete on %1$s
                    for each row execute function public.fn_audit();', t);
  end loop;
end $$;

-- ------------------------------------------------------------
-- RLS — staff bewerkt; staff + ILT-inspecteur lezen
-- ------------------------------------------------------------
alter table qms_clauses   enable row level security;
alter table qms_documents enable row level security;

drop policy if exists p_qms_clauses_all on qms_clauses;
create policy p_qms_clauses_all on qms_clauses for all
  using ( is_staff() ) with check ( is_staff() );
drop policy if exists p_qms_clauses_read on qms_clauses;
create policy p_qms_clauses_read on qms_clauses for select
  using ( can_read_all() );

drop policy if exists p_qms_docs_all on qms_documents;
create policy p_qms_docs_all on qms_documents for all
  using ( is_staff() ) with check ( is_staff() );
drop policy if exists p_qms_docs_read on qms_documents;
create policy p_qms_docs_read on qms_documents for select
  using ( can_read_all() );

-- ------------------------------------------------------------
-- Storage-bucket voor kwaliteitsdocumenten
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('qms-documents', 'qms-documents', false)
on conflict (id) do nothing;

drop policy if exists p_qms_storage_all on storage.objects;
create policy p_qms_storage_all on storage.objects for all
  using ( bucket_id = 'qms-documents' and is_staff() )
  with check ( bucket_id = 'qms-documents' and is_staff() );
drop policy if exists p_qms_storage_read on storage.objects;
create policy p_qms_storage_read on storage.objects for select
  using ( bucket_id = 'qms-documents' and can_read_all() );

-- ------------------------------------------------------------
-- SEED — inhoud uit het eigen Kwaliteitshandboek KH-001 v2.0
-- (Plaza Boat College, conform NEN-EN-ISO 9001:2015). De volledige
-- PDF staat als werkdocument in de documentenbibliotheek.
-- ------------------------------------------------------------
insert into qms_clauses (clause_number, title, pbc_approach, sort_order) values
('0', 'Inleiding en organisatieprofiel',
 'Plaza Boat College bv — RYA Recognised Training Centre #921038887, Bonaire (Caribisch Nederland). RYA-erkenning voor Powerboat Levels 1 & 2 en Shorebased SRC (marifonie/VHF). Principal: Johan Duits (RYA-lidnr. 921038902); Chief Instructor: Rowan Beenakkers; Instructeur EFR: Bram van Zwol. Operationele basis: Plaza Resort Marina. Dit handboek (KH-001 v2.0) volgt de ISO 9001-structuur en vormt de managementlaag boven het bestaande RYA Safety Management System (SMS); het verwijst naar de SOP-documenten in plaats van ze te dupliceren.', 0),
('1', 'Toepassingsgebied (scope)',
 'Het organiseren en uitvoeren van door de RYA erkende vaaropleidingen op Bonaire — RYA Powerboat (Levels 1 en 2) en RYA Shorebased SRC (marifonie/VHF) — inclusief advisering, inschrijving, cursistenbegeleiding, examen-/certificeringsvoorbereiding en nazorg. Uitsluitingen: 8.3 Ontwerp & ontwikkeling (eindtermen door RYA bepaald) en 7.1.5 meetmiddelen (geen kalibratie van toepassing).', 1),
('2', 'Normatieve verwijzingen',
 'NEN-EN-ISO 9001:2015 en ISO 9000:2015; RYA Recognition Guidance Notes en RYA "Guidance for Writing Operating Procedures"; RYA-cursussyllabi en instructeurshandboeken (Powerboat en SRC); lokale wet- en regelgeving Bonaire/Caribisch Nederland; eisen van de ILT voor zover van toepassing.', 2),
('3', 'Termen en definities',
 'Termen uit NEN-EN-ISO 9000:2015, aangevuld met: KMS (kwaliteitsmanagementsysteem), SMS/SOP (RYA Safety Management System / Standard Operating Procedures), RYA/RTC, Principal (eindverantwoordelijke + kwaliteitscoördinator), Chief Instructor, SRC, Cursist, Afwijking/CM (corrigerende maatregel), ILT.', 3),
('4', 'Context van de organisatie',
 'Externe onderwerpen: RYA-eisen en periodieke RYA-inspectie, lokale regelgeving/ILT-toezicht, weer- en zee-omstandigheden (vaargebied tot 3 NM), seizoensvraag, concurrentie. Interne onderwerpen: beschikbaarheid/kwalificaties instructeurs, actualiteit cursusplannen, onderhoud vaartuig (Axopar), financiële continuïteit, veiligheidscultuur. Belanghebbenden: cursisten, RYA, ILT, lokale autoriteiten/kustwacht, instructeurs en directie.', 4),
('5', 'Leiderschap',
 'De Principal toont leiderschap door beleid en doelstellingen vast te stellen, RYA-standaarden in de bedrijfsvoering te integreren, risicogebaseerd denken te bevorderen en middelen beschikbaar te stellen. Kwaliteitsbeleid: cursisten opleiden tot veilige, deskundige vaarweggebruikers volgens de RYA-standaarden en wet- en regelgeving; veiligheid staat altijd voorop. Rollen: Principal (Johan Duits) eindverantwoordelijk; Chief Instructor (Rowan Beenakkers) vakinhoud/veiligheid; instructeurs (o.a. Bram van Zwol).', 5),
('6', 'Planning (risico''s, kansen, doelstellingen)',
 'Risico''s/kansen worden bepaald en beheerst via de RYA-risicoanalyses en, op organisatieniveau, door de Principal. Beheersmaatregelen o.a.: jaarlijks RYA Training Support raadplegen, meerdere gekwalificeerde instructeurs, safety briefs/kill-cord/reddingsvesten, bewaken van vervaldata. Doelstellingen (KPI''s): ≥85% geslaagde cursisten (per kwartaal), klanttevredenheid ≥8,0, 0 incidenten met letsel, 100% geldige kwalificaties/First Aid, jaarlijkse tijdige herziening SMS/SOP.', 6),
('7', 'Ondersteuning (middelen, competentie, documentatie)',
 'Middelen: gekwalificeerde instructeurs, opleidingsvaartuig (Axopar 22 ft, Mercury 200 pk), veiligheidsuitrusting (vesten, kill-cords, VHF, EHBO, brandblussers), leslocaties en RYA-materialen. Competentie: aantoonbare RYA-kwalificaties + geldig First Aid; Principal bewaakt vervaldata (kwalificatieregister). Communicatie via SMS-handboek, inductie en verklaring. Gedocumenteerde informatie: dit handboek + RYA-SMS; documenten met titel/nummer/versie/datum; registraties bewaard conform bewaartermijnen (≥7 jaar) en AVG/lokale privacyregels.', 7),
('8', 'Uitvoering (de opleidingen)',
 'Opleidingen worden gepland en uitgevoerd volgens de RYA-cursusplannen en SOP''s onder beheerste omstandigheden. Vóór inschrijving krijgt de cursist duidelijke informatie; bij inschrijving worden eisen, medische gegevens en noodcontacten vastgelegd. Eindtermen volgen uit de RYA-syllabi; Plaza Boat College stelt eigen cursusplannen op. Uitvoering onder SOP-beheersmaatregelen (safety briefs, kill-cord, vesten, snelheidslimiet, ratio 3:1). Vrijgave/certificering pas bij aangetoond niveau ("can, knows, understands"); anders een Action Plan. Afwijkingen/near-misses worden geregistreerd en gecorrigeerd.', 8),
('9', 'Evaluatie van de prestaties',
 'Monitoring van behaalde certificaten, klanttevredenheid (feedbackformulier), incidenten/near-misses en voortgang op de doelstellingen. Interne borging via interne controles én de periodieke RYA-inspectie, die als onafhankelijke externe audit functioneert (initiële inspectie 23–24 sep 2024: geen acties vereist). De directie/Principal voert ten minste jaarlijks een directiebeoordeling van het KMS uit.', 9),
('10', 'Verbetering',
 'Plaza Boat College selecteert verbeterkansen en pakt afwijkingen aan: beheersen/corrigeren, oorzaak bepalen, maatregel treffen en doeltreffendheid beoordelen. Klachten worden geregistreerd en afgehandeld (communicatie als veelvoorkomende oorzaak). Resultaten van feedback, incidenten, interne beoordeling en RYA-inspectie verbeteren het KMS en de SOP''s continu, met een jaarlijkse herziening als vast moment.', 10),
('A', 'Bijlage A — Koppeling ISO 9001 ↔ RYA-SMS / SOP',
 'Kruisverwijzing tussen ISO 9001:2015-clausules en de RYA-SMS/SOP-documenten, o.a.: 5.3 Rollen → SMS §3.2 + instructeursverklaring 6.7; 6.1 Risico''s → risicoanalyses app. 3.0/3.1/3.2; 7.2 Competentie → training & review app. 5.0/5.1 + IR1; 7.5 Documentbeheer → SMS versiebeheer §3.0; 8.2 Eisen → booking form 6.4 + emergency contact list 6.6; 8.3 Cursusplannen → app. 4.1/4.2/4.3; 8.6 Vrijgave → SMS §3.20 + Action Plan 6.1 + certificaten app. 7.1; 9.1.2 Klanttevredenheid → feedback form 6.5; 9.2 Audit → RYA-inspectie (IR1); EAP/noodprocedures → SMS App. 1 + EAP 6.8.', 11)
on conflict do nothing;

-- Documentenbibliotheek vooraf gevuld met de bestaande kwaliteitsdocumenten.
-- (De PDF's worden in de bucket 'qms-documents' geplaatst onder onderstaande paden.)
insert into qms_documents (title, doc_type, reference, clause_number, file_path) values
('Kwaliteitshandboek Plaza Boat College (ISO 9001)', 'Handboek', 'KH-001 v2.0', null, 'KH-001.pdf'),
('Onderbouwing productie 8 — RYA/MCA-erkenning kwaliteitssysteem', 'Onderbouwing', 'Productie 8', '9', 'onderbouwing-productie-8.pdf'),
('Routekaart ISO 9001-certificering', 'Plan', 'Routekaart', '10', 'routekaart-iso-9001.pdf')
on conflict do nothing;
