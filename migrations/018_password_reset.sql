-- 018_password_reset.sql
-- Recuperación de contraseña (Fase 5, bloque B7).
--
--  * Token firmado de un solo uso que viaja por correo; en la base solo su
--    SHA-256. Vence a los 15 minutos (impuesto por la base).
--  * Solo para cuentas ACTIVAS, con el mismo patrón de la migración 017:
--    user_status siempre 'active' + FK compuesta (user_id, user_status) →
--    users (id, status). Una cuenta pendiente no puede tener tokens de
--    recuperación, y una cuenta con tokens no puede volver a pendiente.
--  * Como máximo UN token vigente por cuenta: pedir otro revoca el anterior.
--  * Al usarse, se revocan todas las sesiones: nuevo motivo de revocación.

CREATE TABLE password_reset_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL,
  user_status account_status NOT NULL DEFAULT 'active'
                CONSTRAINT chk_password_reset_tokens_user_active CHECK (user_status = 'active'),
  token_hash  CHAR(64) NOT NULL UNIQUE CHECK (token_hash ~ '^[0-9a-f]{64}$'),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at  TIMESTAMPTZ NOT NULL,
  -- Usado (cambió la contraseña) o revocado (se pidió otro): nunca ambos.
  used_at     TIMESTAMPTZ,
  revoked_at  TIMESTAMPTZ,

  CONSTRAINT fk_password_reset_tokens_active_user
    FOREIGN KEY (user_id, user_status) REFERENCES users (id, status)
    ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT chk_password_reset_tokens_expiry CHECK (
    expires_at > created_at AND expires_at <= created_at + INTERVAL '15 minutes'
  ),
  CONSTRAINT chk_password_reset_tokens_one_ending CHECK (used_at IS NULL OR revoked_at IS NULL)
);

-- Un solo token vigente (sin usar ni revocar) por cuenta.
CREATE UNIQUE INDEX uq_password_reset_tokens_one_open
  ON password_reset_tokens (user_id) WHERE used_at IS NULL AND revoked_at IS NULL;

-- Sesiones revocadas porque se restableció la contraseña.
ALTER TABLE refresh_tokens DROP CONSTRAINT refresh_tokens_revoke_reason_check;
ALTER TABLE refresh_tokens ADD CONSTRAINT refresh_tokens_revoke_reason_check
  CHECK (revoke_reason IN ('rotated', 'logout', 'reuse_detected', 'expired', 'password_reset'));
