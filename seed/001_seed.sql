-- seed/001_seed.sql
-- Datos de prueba para desarrollo local. NO ejecutar en producción.

-- Usuarios
INSERT INTO users (id, name, email, password_hash, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Ana Contadora', 'ana@example.com', '$2b$10$examplehashaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'accountant'),
  ('22222222-2222-2222-2222-222222222222', 'Luis Asistente', 'luis@example.com', '$2b$10$examplehashbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', 'assistant'),
  ('33333333-3333-3333-3333-333333333333', 'Admin Plataforma', 'admin@example.com', '$2b$10$examplehashccccccccccccccccccccccccccccccccccccccc', 'admin');

-- Clientes contribuyentes
INSERT INTO clients (id, accountant_user_id, full_name, document_number, email, phone) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Carlos Pérez', '1020304050', 'carlos.perez@example.com', '3001234567'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'María Gómez', '1020304060', 'maria.gomez@example.com', '3007654321');

-- Documentos de ejemplo
INSERT INTO documents (id, client_id, uploaded_by, doc_type, original_name, storage_key, status) VALUES
  ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'income_certificate', 'certificado_ingresos_2025.pdf', 'clients/aaaaaaaa-0001/documents/certificado_ingresos_2025.pdf', 'processed'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'bank_statement', 'extracto_bancario_marzo.pdf', 'clients/aaaaaaaa-0001/documents/extracto_bancario_marzo.pdf', 'processing');

-- Conceptos tributarios ya extraídos por IA para el primer documento
INSERT INTO tax_concepts (document_id, client_id, concept_type, description, amount, period_year) VALUES
  ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'gross_income', 'Ingresos laborales', 85000000, 2025),
  ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'withholding', 'Retención en la fuente', 6200000, 2025);

-- Alerta de ejemplo
INSERT INTO alerts (client_id, document_id, alert_type, severity, message, status, due_date) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', NULL, 'deadline', 'medium',
   'La declaración de renta de Carlos Pérez vence el 15 de octubre según el último dígito de su cédula.',
   'open', '2026-10-15');
