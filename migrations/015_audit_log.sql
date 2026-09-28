-- 015_audit_log.sql
-- Registro de auditoría: quién hizo qué, sobre qué y cuándo.
--
-- Sin datos sensibles: ni contraseñas, ni tokens, ni contenido de
-- documentos, ni montos, ni el texto de las preguntas al chat. Solo la
-- acción, la entidad y su id. user_id es NULL en intentos fallidos de login
-- (no se revela ni se guarda el correo intentado).

CREATE TABLE audit_log (
  id          BIGSERIAL PRIMARY KEY,
  user_id     UUID REFERENCES users(id) ON DELETE SET NULL,
  action      VARCHAR(50)  NOT NULL,
  entity      VARCHAR(30),
  entity_id   VARCHAR(64),
  ip          VARCHAR(45),
  user_agent  VARCHAR(200),
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_log_created ON audit_log (created_at DESC);
CREATE INDEX idx_audit_log_user_created ON audit_log (user_id, created_at DESC);
CREATE INDEX idx_audit_log_entity ON audit_log (entity, entity_id);
