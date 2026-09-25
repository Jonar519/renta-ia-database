-- 010_hardening.sql
-- Endurecimiento posterior a la auditoría: índices para las consultas
-- reales del backend, integridad (unicidad, CHECKs), emails sin distinción
-- de mayúsculas y updated_at automático.
--
-- Se ejecuta dentro de una transacción (ver scripts/migrate.*): si algún
-- paso falla, no se aplica nada. Los CREATE INDEX no usan CONCURRENTLY
-- porque este no puede correr dentro de una transacción; con el volumen de
-- datos del proyecto el bloqueo es de milisegundos.

-- ---------------------------------------------------------------------------
-- 1. Índices
-- ---------------------------------------------------------------------------

-- Listados que el backend ordena por fecha (alerts.service, documents.service,
-- clients.service). Un índice compuesto (filtro + orden) evita el sort.
CREATE INDEX IF NOT EXISTS idx_alerts_client_created
  ON alerts (client_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_documents_client_uploaded
  ON documents (client_id, uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_clients_accountant_created
  ON clients (accountant_user_id, created_at DESC);

-- Claves foráneas sin índice: se recorren al borrar el registro padre
-- (ON DELETE SET NULL / RESTRICT / CASCADE) y en los joins.
CREATE INDEX IF NOT EXISTS idx_alerts_document ON alerts (document_id);
CREATE INDEX IF NOT EXISTS idx_documents_uploaded_by ON documents (uploaded_by);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_user ON ai_conversations (user_id);

-- Documentos pendientes de procesar: índice parcial, pequeño y selectivo
-- (la gran mayoría de documentos terminan en 'processed').
CREATE INDEX IF NOT EXISTS idx_documents_pending
  ON documents (status)
  WHERE status IN ('uploaded', 'processing');

-- ---------------------------------------------------------------------------
-- 2. Un solo embedding por (documento, fragmento)
-- ---------------------------------------------------------------------------

-- Si un documento se reprocesó antes de esta migración pudo quedar con
-- fragmentos duplicados: se conserva el más antiguo de cada par.
DELETE FROM document_embeddings a
  USING document_embeddings b
  WHERE a.document_id = b.document_id
    AND a.chunk_index = b.chunk_index
    AND (a.created_at, a.id) > (b.created_at, b.id);

ALTER TABLE document_embeddings
  ADD CONSTRAINT uq_document_embeddings_document_chunk UNIQUE (document_id, chunk_index);

-- ---------------------------------------------------------------------------
-- 3. Email sin distinción de mayúsculas
-- ---------------------------------------------------------------------------

-- El backend normaliza a minúsculas al registrar y al iniciar sesión.
-- Si existieran dos usuarios que solo difieren en mayúsculas, este UPDATE
-- falla (por el UNIQUE de email) y hay que fusionarlos a mano primero.
UPDATE users SET email = lower(email) WHERE email <> lower(email);

CREATE UNIQUE INDEX IF NOT EXISTS uq_users_email_lower ON users (lower(email));

-- ---------------------------------------------------------------------------
-- 4. CHECKs de datos tributarios
-- ---------------------------------------------------------------------------

ALTER TABLE tax_concepts
  ADD CONSTRAINT chk_tax_concepts_period_year CHECK (period_year BETWEEN 2000 AND 2100),
  ADD CONSTRAINT chk_tax_concepts_amount_non_negative CHECK (amount >= 0);

-- ---------------------------------------------------------------------------
-- 5. updated_at automático
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_clients_updated_at ON clients;
CREATE TRIGGER trg_clients_updated_at
  BEFORE UPDATE ON clients
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
