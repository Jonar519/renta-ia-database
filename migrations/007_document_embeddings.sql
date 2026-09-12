-- 007_document_embeddings.sql
-- Representación vectorial de fragmentos de cada documento, usada para
-- búsqueda semántica y RAG (Retrieval-Augmented Generation) en el chat de IA.
--
-- Dimensión 1024: corresponde a modelos de embeddings tipo Voyage AI
-- (recomendado para usarse junto con la API de Anthropic). Si se usa otro
-- proveedor de embeddings, ajustar la dimensión del vector aquí.

CREATE TABLE document_embeddings (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id  UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  chunk_index  INT NOT NULL DEFAULT 0,
  chunk_text   TEXT NOT NULL,
  embedding    VECTOR(1024) NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_document_embeddings_document ON document_embeddings(document_id);

-- Índice HNSW para búsqueda aproximada de vecinos más cercanos (similitud coseno).
-- Se crea después de tener datos representativos cargados, idealmente.
CREATE INDEX idx_document_embeddings_vector
  ON document_embeddings
  USING hnsw (embedding vector_cosine_ops);
