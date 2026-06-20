-- ============================================================
-- Plaza Boat College — Seed QMS-documentenbibliotheek
-- Standaard ISO 9001-documentenset (procedures, formulieren).
-- ------------------------------------------------------------
-- Idempotent: voegt alleen toe wat nog niet bestaat (op titel).
-- Voer dit uit NA qms.sql (qms_documents-tabel moet bestaan).
-- LET OP: file_path = pad in bucket 'qms-documents'. De echte
-- bestandsnamen worden later geüpload; dit zijn nette placeholders.
-- ============================================================

insert into qms_documents (title, doc_type, reference, clause_number, file_path)
select v.title, v.doc_type, v.reference, v.clause_number, v.file_path
from (values
  -- Procedures PR-01..09 (ISO 9001-procedureset)
  ('PR-01 Documentbeheer',                         'Procedure', 'PR-01', '7', 'qms-documents/PR-01-documentbeheer.pdf'),
  ('PR-02 Beheer van registraties',                'Procedure', 'PR-02', '7', 'qms-documents/PR-02-beheer-registraties.pdf'),
  ('PR-03 Interne audit',                          'Procedure', 'PR-03', '9', 'qms-documents/PR-03-interne-audit.pdf'),
  ('PR-04 Afwijkingen en corrigerende maatregelen','Procedure', 'PR-04', '10', 'qms-documents/PR-04-corrigerende-maatregelen.pdf'),
  ('PR-05 Klachtenbehandeling',                    'Procedure', 'PR-05', '10', 'qms-documents/PR-05-klachtenbehandeling.pdf'),
  ('PR-06 Incidenten- en ongevallenmelding',       'Procedure', 'PR-06', '8', 'qms-documents/PR-06-incidentenmelding.pdf'),
  ('PR-07 Competentie en opleiding personeel',     'Procedure', 'PR-07', '7', 'qms-documents/PR-07-competentie-opleiding.pdf'),
  ('PR-08 Inschrijving en uitvoering opleidingen', 'Procedure', 'PR-08', '8', 'qms-documents/PR-08-inschrijving-uitvoering.pdf'),
  ('PR-09 Directiebeoordeling',                    'Procedure', 'PR-09', '9', 'qms-documents/PR-09-directiebeoordeling.pdf'),
  -- Examinator-formulieren
  ('FORM Examinator — mondeling examen',           'Formulier', 'EX-MOND', '8', 'qms-documents/form-examinator-mondeling.pdf'),
  ('FORM Examinator — praktijkexamen',             'Formulier', 'EX-PRAK', '8', 'qms-documents/form-examinator-praktijk.pdf'),
  ('FORM Examinator — kennistoets',                'Formulier', 'EX-KENN', '8', 'qms-documents/form-examinator-kennistoets.pdf'),
  -- QMS-formulieren (registers)
  ('FORM Incidentmelding',                         'Formulier', 'F-INC', '8', 'qms-documents/form-incidentmelding.pdf'),
  ('FORM Bijna-ongevalmelding',                    'Formulier', 'F-NM', '8', 'qms-documents/form-bijna-ongeval.pdf'),
  ('FORM Klachtformulier',                         'Formulier', 'F-KL', '10', 'qms-documents/form-klacht.pdf'),
  ('FORM Verbetervoorstel (CAPA)',                 'Formulier', 'F-VB', '10', 'qms-documents/form-verbetervoorstel.pdf'),
  ('FORM Cursistenfeedback',                       'Formulier', 'F-FB', '9', 'qms-documents/form-cursistenfeedback.pdf')
) as v(title, doc_type, reference, clause_number, file_path)
where not exists (
  select 1 from qms_documents d where d.title = v.title
);

-- Klaar.
