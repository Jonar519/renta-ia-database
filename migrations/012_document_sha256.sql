-- 012_document_sha256.sql
-- Huella SHA-256 del contenido de cada documento, para rechazar que el
-- mismo archivo se suba dos veces al mismo cliente (duplicaría conceptos,
-- inflaría los totales y gastaría crédito de IA otra vez).
--
-- El navegador la calcula en un Web Worker ANTES de subir (para avisar sin
-- transferir el archivo), pero la que se guarda es la que calcula el
-- backend sobre los bytes recibidos: nunca se confía en la del cliente.
--
-- Documentos anteriores a esta migración quedan con sha256 NULL (no se
-- pueden recalcular aquí porque el archivo vive en el almacenamiento, no en
-- la BD) y no participan en la restricción.

ALTER TABLE documents ADD COLUMN IF NOT EXISTS sha256 CHAR(64);

ALTER TABLE documents
  ADD CONSTRAINT chk_documents_sha256_hex CHECK (sha256 IS NULL OR sha256 ~ '^[0-9a-f]{64}$');

CREATE UNIQUE INDEX IF NOT EXISTS uq_documents_client_sha256
  ON documents (client_id, sha256)
  WHERE sha256 IS NOT NULL;
