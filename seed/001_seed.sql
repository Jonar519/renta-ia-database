-- seed/001_seed.sql
-- Datos de prueba para desarrollo local. NO ejecutar en producción.
--
-- Idempotente: se puede ejecutar varias veces (ON CONFLICT). Volver a
-- ejecutarlo sobre una base ya sembrada actualiza el hash de contraseña de
-- los usuarios de prueba.
--
-- Contraseña de TODOS los usuarios de prueba: Password123!
-- (hash bcrypt real, costo 10, el mismo que usa el backend al registrar).

-- Usuarios
INSERT INTO users (id, name, email, password_hash, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Ana Contadora', 'ana@example.com', '$2a$10$xDx7brDnEU371AL7aF0tse7rBu4X.Or66jKV1hqpKFocp133QkF8u', 'accountant'),
  ('22222222-2222-2222-2222-222222222222', 'Luis Asistente', 'luis@example.com', '$2a$10$xDx7brDnEU371AL7aF0tse7rBu4X.Or66jKV1hqpKFocp133QkF8u', 'assistant'),
  ('33333333-3333-3333-3333-333333333333', 'Admin Plataforma', 'admin@example.com', '$2a$10$xDx7brDnEU371AL7aF0tse7rBu4X.Or66jKV1hqpKFocp133QkF8u', 'admin')
ON CONFLICT (id) DO UPDATE SET password_hash = EXCLUDED.password_hash;

-- Clientes contribuyentes
INSERT INTO clients (id, accountant_user_id, full_name, document_number, email, phone) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Carlos Pérez', '1020304050', 'carlos.perez@example.com', '3001234567'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'María Gómez', '1020304060', 'maria.gomez@example.com', '3007654321')
ON CONFLICT (id) DO NOTHING;

-- Documentos de ejemplo (solo metadatos: los archivos no existen en uploads/,
-- por eso no se encolan para procesamiento).
INSERT INTO documents (id, client_id, uploaded_by, doc_type, original_name, storage_key, status) VALUES
  ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'income_certificate', 'certificado_ingresos_2025.pdf', 'clients/aaaaaaaa-0001/documents/certificado_ingresos_2025.pdf', 'processed'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'bank_statement', 'extracto_bancario_marzo.pdf', 'clients/aaaaaaaa-0001/documents/extracto_bancario_marzo.pdf', 'processing')
ON CONFLICT (id) DO NOTHING;

-- Conceptos tributarios ya extraídos por IA para el primer documento.
-- (Sin id fijo: se insertan solo si el documento aún no tiene conceptos, para
-- no duplicarlos en bases sembradas con versiones anteriores de este archivo.)
INSERT INTO tax_concepts (document_id, client_id, concept_type, description, amount, period_year)
SELECT v.document_id::uuid, v.client_id::uuid, v.concept_type::tax_concept_type, v.description, v.amount, v.period_year
FROM (VALUES
  ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'gross_income', 'Ingresos laborales', 85000000, 2025),
  ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'withholding', 'Retención en la fuente', 6200000, 2025)
) AS v(document_id, client_id, concept_type, description, amount, period_year)
WHERE NOT EXISTS (SELECT 1 FROM tax_concepts WHERE document_id = 'bbbbbbbb-0000-0000-0000-000000000001');

-- Alerta de ejemplo (misma estrategia: solo si el cliente no tiene ya una
-- alerta de vencimiento).
INSERT INTO alerts (client_id, document_id, alert_type, severity, message, status, due_date)
SELECT 'aaaaaaaa-0000-0000-0000-000000000001', NULL, 'deadline', 'medium',
       'La declaración de renta de Carlos Pérez vence el 15 de octubre según el último dígito de su cédula.',
       'open', '2026-10-15'
WHERE NOT EXISTS (
  SELECT 1 FROM alerts WHERE client_id = 'aaaaaaaa-0000-0000-0000-000000000001' AND alert_type = 'deadline'
);
