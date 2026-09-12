-- 005_documents.sql
-- Metadatos de cada documento subido. El archivo original vive en S3;
-- aquí solo se guarda la referencia (storage_key), nunca el binario.

CREATE TABLE documents (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id      UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  uploaded_by    UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  doc_type       document_type NOT NULL,
  original_name  VARCHAR(255) NOT NULL,
  storage_key    VARCHAR(500) NOT NULL, -- ruta del objeto en S3
  status         document_status NOT NULL DEFAULT 'uploaded',
  error_message  TEXT,
  uploaded_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at   TIMESTAMPTZ
);

CREATE INDEX idx_documents_client ON documents(client_id);
CREATE INDEX idx_documents_status ON documents(status);
CREATE INDEX idx_documents_type ON documents(doc_type);
