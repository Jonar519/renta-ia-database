-- seed/perf/001_heavy_dataset.sql
-- DATOS SINTÉTICOS SOLO PARA MEDICIONES DE RENDIMIENTO. NO ejecutar en
-- producción ni en la base de desarrollo normal: úsalo en una base aparte
-- (p. ej. renta_ia_e2e). No lo ejecuta scripts\seed.bat (está en una subcarpeta).
--
-- Requiere el seed normal (usa a Ana, 11111111-...). Crea:
--   · 1.000 clientes "Cliente sintético NNNN" para Ana
--   · 1 cliente "Carga pesada" con 1.500 documentos, 4.000 conceptos y 300 alertas
-- Es idempotente: si "Carga pesada" ya existe, no hace nada.
--
-- Uso (cmd.exe, desde renta-ia-database):
--   docker exec -i renta_ia_postgres psql -U postgres -d renta_ia_e2e -v ON_ERROR_STOP=1 < seed\perf\001_heavy_dataset.sql

DO $$
DECLARE
  ana CONSTANT uuid := '11111111-1111-1111-1111-111111111111';
  heavy CONSTANT uuid := 'eeeeeeee-0000-0000-0000-000000000001';
BEGIN
  IF EXISTS (SELECT 1 FROM clients WHERE id = heavy) THEN
    RAISE NOTICE 'El dataset pesado ya existe; no se hace nada.';
    RETURN;
  END IF;

  INSERT INTO clients (accountant_user_id, full_name, document_number, email, created_at)
  SELECT ana,
         'Cliente sintético ' || lpad(n::text, 4, '0'),
         (7000000000 + n)::text,
         'sintetico' || n || '@example.com',
         now() - (n || ' minutes')::interval
  FROM generate_series(1, 1000) AS n;

  INSERT INTO clients (id, accountant_user_id, full_name, document_number, email)
  VALUES (heavy, ana, 'Carga pesada (sintético)', '9999999999', 'carga@example.com');

  INSERT INTO documents (client_id, uploaded_by, doc_type, original_name, storage_key, status, error_message, uploaded_at, processed_at)
  SELECT heavy, ana,
         (ARRAY['income_certificate','bank_statement','deductible_invoice','exogenous_info','pension_certificate','other'])[1 + n % 6]::document_type,
         'documento-sintetico-' || lpad(n::text, 4, '0') || '.pdf',
         'clients/' || heavy || '/documents/sintetico-' || n || '.pdf',
         (ARRAY['processed','processed','processed','error','uploaded'])[1 + n % 5]::document_status,
         CASE WHEN n % 5 = 3 THEN 'El PDF no tiene texto extraíble (sintético)'
              WHEN n % 7 = 0 THEN 'Procesado con advertencias: Generación de embeddings falló (sintético)'
              ELSE NULL END,
         now() - (n || ' hours')::interval,
         now() - (n || ' hours')::interval
  FROM generate_series(1, 1500) AS n;

  INSERT INTO tax_concepts (document_id, client_id, concept_type, description, amount, period_year)
  SELECT d.id, heavy,
         (ARRAY['gross_income','withholding','deduction','pension_contribution','health_contribution','other'])[1 + g % 6]::tax_concept_type,
         'Concepto sintético ' || g,
         (1000000 + (g * 7919) % 50000000)::numeric,
         2023 + g % 3
  FROM (SELECT id, row_number() OVER (ORDER BY id) AS rn FROM documents WHERE client_id = heavy) d
  JOIN generate_series(1, 4000) AS g ON d.rn = 1 + (g % 1500);

  INSERT INTO alerts (client_id, alert_type, severity, message, status, created_at)
  SELECT heavy,
         (ARRAY['inconsistency','deadline'])[1 + n % 2]::alert_type,
         (ARRAY['low','medium','high','critical'])[1 + n % 4]::alert_severity,
         'Alerta sintética número ' || n || ': revisar los conceptos reportados antes de declarar.',
         (ARRAY['open','acknowledged','resolved'])[1 + n % 3]::alert_status,
         now() - (n || ' minutes')::interval
  FROM generate_series(1, 300) AS n;
END $$;
