-- 022_user_sessions.sql
-- Sesiones activas (Fase 5, bloque B13).
--
-- Una sesión = una familia de refresh tokens (family_id; el "sid" del access
-- token). Aquí se guarda lo que la persona necesita para reconocerla:
--  * cuándo empezó y su última actividad (cada renovación del token);
--  * la IP RECORTADA (IPv4 sin el último octeto, IPv6 solo el /48): nunca la
--    IP completa;
--  * una ubicación APROXIMADA (calculada al vuelo desde la IP completa, que
--    no se guarda) y el navegador/sistema.
-- Las sesiones anteriores a esta migración quedan sin IP ni ubicación: la
-- pantalla las muestra como "desconocida".
--
-- Garantías de la base:
--  * Solo cuentas activas tienen sesiones (FK compuesta, como en 017).
--  * Todo refresh token pertenece a una sesión de SU misma cuenta
--    (FK (family_id, user_id)).
--  * La fila de la sesión la crea la base al insertar el primer refresh token
--    de la familia, y cada token nuevo (rotación) actualiza la última
--    actividad. Así la garantía vale para cualquier versión de la API que
--    escriba en refresh_tokens; la API solo completa IP, ubicación y equipo.

CREATE TABLE user_sessions (
  id           UUID PRIMARY KEY,
  user_id      UUID NOT NULL,
  user_status  account_status NOT NULL DEFAULT 'active'
                 CONSTRAINT chk_user_sessions_user_active CHECK (user_status = 'active'),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- IPv4 con el último octeto en 0 (a.b.c.0) o el prefijo /48 de una IPv6 (x:y:z::).
  ip_prefix    VARCHAR(45)
                 CONSTRAINT chk_user_sessions_ip_prefix CHECK (
                   ip_prefix ~ '^(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])){2}\.0$'
                   OR ip_prefix ~ '^([0-9a-f]{1,4}(:[0-9a-f]{1,4}){0,2})?::$'
                 ),
  location     VARCHAR(120) CONSTRAINT chk_user_sessions_location CHECK (length(btrim(location)) > 0),
  device       VARCHAR(80) CONSTRAINT chk_user_sessions_device CHECK (length(btrim(device)) > 0),
  CONSTRAINT chk_user_sessions_seen CHECK (last_seen_at >= created_at),
  CONSTRAINT uq_user_sessions_id_user UNIQUE (id, user_id),
  CONSTRAINT fk_user_sessions_active_user
    FOREIGN KEY (user_id, user_status) REFERENCES users (id, status)
    ON DELETE CASCADE ON UPDATE NO ACTION
);

CREATE INDEX idx_user_sessions_user ON user_sessions (user_id);

-- Sesiones que ya existían: una fila por familia, sin IP ni ubicación.
INSERT INTO user_sessions (id, user_id, created_at, last_seen_at)
SELECT family_id, user_id, min(created_at), max(created_at)
FROM refresh_tokens
GROUP BY family_id, user_id;

-- Cada refresh token nuevo: crea la sesión si es el primero de su familia;
-- si no, mueve la última actividad (nunca hacia atrás).
CREATE OR REPLACE FUNCTION touch_user_session()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_sessions (id, user_id, created_at, last_seen_at)
  VALUES (NEW.family_id, NEW.user_id, NEW.created_at, NEW.created_at)
  ON CONFLICT (id) DO UPDATE
    SET last_seen_at = GREATEST(user_sessions.last_seen_at, EXCLUDED.last_seen_at);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_refresh_tokens_touch_session
  BEFORE INSERT ON refresh_tokens
  FOR EACH ROW EXECUTE FUNCTION touch_user_session();

ALTER TABLE refresh_tokens
  ADD CONSTRAINT fk_refresh_tokens_session
  FOREIGN KEY (family_id, user_id) REFERENCES user_sessions (id, user_id)
  ON DELETE CASCADE ON UPDATE NO ACTION;

-- Cerrar una sesión desde "Sesiones activas" (una, o todas las demás).
ALTER TABLE refresh_tokens DROP CONSTRAINT refresh_tokens_revoke_reason_check;
ALTER TABLE refresh_tokens ADD CONSTRAINT refresh_tokens_revoke_reason_check
  CHECK (revoke_reason IN ('rotated', 'logout', 'reuse_detected', 'expired', 'password_reset',
                           'mfa_enabled', 'mfa_reset', 'password_change', 'session_closed'));
