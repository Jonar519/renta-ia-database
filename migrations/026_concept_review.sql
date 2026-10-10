-- 026_concept_review.sql
-- Revisión humana de los conceptos extraídos por IA (Fase 5, bloque B16).
--
-- Un concepto nace de la IA ("Extraído por IA · sin revisar", decisión D5).
-- Una persona lo revisa: lo confirma tal cual o corrige el monto. Se guarda:
--  * ai_amount: lo que leyó la IA (la API no lo modifica: así se ve qué se corrigió);
--  * source: 'ai' si el monto vigente es el de la IA, 'person' si lo corrigió alguien;
--  * reviewed_at / reviewed_by: cuándo y quién lo revisó (los dos o ninguno).
-- reviewed_by es RESTRICT, como los demás autores: una cuenta eliminada queda
-- como lápida (024) y la revisión sigue teniendo autor.
--
-- Reprocesar un documento con conceptos revisados exige confirmar que se
-- descartan esas revisiones (D6); lo controlan la API y el worker.

ALTER TABLE tax_concepts
  ADD COLUMN source VARCHAR(8) NOT NULL DEFAULT 'ai'
    CONSTRAINT chk_tax_concepts_source CHECK (source IN ('ai', 'person')),
  ADD COLUMN ai_amount NUMERIC(14, 2),
  ADD COLUMN reviewed_at TIMESTAMPTZ,
  ADD COLUMN reviewed_by UUID REFERENCES users(id) ON DELETE RESTRICT;

-- Los conceptos existentes: todos de la IA y sin revisar.
UPDATE tax_concepts SET ai_amount = amount;

ALTER TABLE tax_concepts
  ALTER COLUMN ai_amount SET NOT NULL,
  -- "original" y no "ai_amount": PostgreSQL revisa los CHECK en orden alfabético y,
  -- como el trigger copia el monto, un monto negativo debe reportar el CHECK del monto.
  ADD CONSTRAINT chk_tax_concepts_original_non_negative CHECK (ai_amount >= 0),
  ADD CONSTRAINT chk_tax_concepts_review_pair CHECK ((reviewed_at IS NULL) = (reviewed_by IS NULL)),
  -- Si dice 'ai', el monto es exactamente el que leyó la IA.
  ADD CONSTRAINT chk_tax_concepts_ai_amount_kept CHECK (source <> 'ai' OR amount = ai_amount),
  -- Si lo corrigió una persona, está revisado.
  ADD CONSTRAINT chk_tax_concepts_person_reviewed CHECK (source <> 'person' OR reviewed_at IS NOT NULL);

CREATE INDEX idx_tax_concepts_unreviewed ON tax_concepts (client_id) WHERE reviewed_at IS NULL;

-- Una versión de la API que inserte conceptos sin ai_amount (por ejemplo, el
-- worker de main contra la base de desarrollo compartida) sigue funcionando:
-- el valor de la IA es el monto con el que se crea.
CREATE OR REPLACE FUNCTION default_tax_concept_ai_amount()
RETURNS TRIGGER AS $$
BEGIN
  NEW.ai_amount := COALESCE(NEW.ai_amount, NEW.amount);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tax_concepts_ai_amount
  BEFORE INSERT ON tax_concepts
  FOR EACH ROW EXECUTE FUNCTION default_tax_concept_ai_amount();
