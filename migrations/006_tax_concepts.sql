-- 006_tax_concepts.sql
-- Cifras tributarias estructuradas, extraídas por el pipeline de IA a partir
-- del texto de cada documento (ingresos, retenciones, deducciones, aportes).

CREATE TABLE tax_concepts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id   UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  client_id     UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  concept_type  tax_concept_type NOT NULL,
  description   VARCHAR(255),
  amount        NUMERIC(14, 2) NOT NULL,
  period_year   SMALLINT NOT NULL,
  is_anomalous  BOOLEAN NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_tax_concepts_client_year ON tax_concepts(client_id, period_year);
CREATE INDEX idx_tax_concepts_document ON tax_concepts(document_id);
CREATE INDEX idx_tax_concepts_type ON tax_concepts(concept_type);
