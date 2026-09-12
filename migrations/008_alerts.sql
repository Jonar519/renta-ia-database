-- 008_alerts.sql
-- Vencimientos próximos e inconsistencias detectadas por el motor de reglas
-- e IA. document_id es opcional porque una alerta de vencimiento puede no
-- estar asociada a un documento específico.

CREATE TABLE alerts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id     UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  document_id   UUID REFERENCES documents(id) ON DELETE SET NULL,
  alert_type    alert_type NOT NULL,
  severity      alert_severity NOT NULL DEFAULT 'medium',
  message       TEXT NOT NULL,
  status        alert_status NOT NULL DEFAULT 'open',
  due_date      DATE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at   TIMESTAMPTZ
);

CREATE INDEX idx_alerts_client ON alerts(client_id);
CREATE INDEX idx_alerts_status ON alerts(status);
CREATE INDEX idx_alerts_due_date ON alerts(due_date);
