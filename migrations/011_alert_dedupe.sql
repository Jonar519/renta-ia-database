-- 011_alert_dedupe.sql
-- Evita alertas duplicadas desde la base de datos, no solo desde el código.
--
-- Antes, el motor de reglas hacía "buscar alerta abierta → si no existe,
-- crearla". Con el worker procesando 2 documentos a la vez, dos jobs del
-- mismo cliente podían pasar ambos el "no existe" y crear dos alertas.
--
-- dedupe_key identifica QUÉ situación describe la alerta, por ejemplo:
--   'deductions_over_limit'        deducciones > límite del ingreso bruto
--   'exogenous_mismatch:2025'      exógena vs. certificado de ingresos, año 2025
--   'deadline:2025'                vencimiento de la declaración del año gravable 2025
-- El índice único parcial permite UNA sola alerta no resuelta por
-- (cliente, dedupe_key). Las resueltas no cuentan: si la situación vuelve
-- a aparecer después de resolverla, se puede crear una nueva.
-- Alertas sin dedupe_key (NULL) no están restringidas.

ALTER TABLE alerts ADD COLUMN IF NOT EXISTS dedupe_key VARCHAR(100);

-- Alertas de deducciones creadas antes de esta migración: se marca solo la
-- más reciente no resuelta de cada cliente (si hubiera duplicados, las
-- demás quedan sin dedupe_key y no bloquean la creación del índice).
UPDATE alerts a
SET dedupe_key = 'deductions_over_limit'
WHERE a.id IN (
  SELECT DISTINCT ON (client_id) id
  FROM alerts
  WHERE alert_type = 'inconsistency'
    AND status <> 'resolved'
    AND dedupe_key IS NULL
    AND message LIKE 'Las deducciones reportadas%'
  ORDER BY client_id, created_at DESC
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_alerts_active_dedupe
  ON alerts (client_id, dedupe_key)
  WHERE dedupe_key IS NOT NULL AND status <> 'resolved';

-- El job diario de vencimientos busca por (cliente, dedupe_key) incluyendo
-- las resueltas (para no recrear una alerta que el contador ya cerró).
CREATE INDEX IF NOT EXISTS idx_alerts_client_dedupe ON alerts (client_id, dedupe_key);
