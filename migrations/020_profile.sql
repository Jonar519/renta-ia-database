-- 020_profile.sql
-- Perfil propio (Fase 5, bloque B11).
--
--  * users.phone: teléfono opcional que cada persona edita en "Mi perfil".
--  * email_change_tokens: cambiar el correo exige confirmar el NUEVO correo
--    con un token firmado de un solo uso (en la base solo su SHA-256), válido
--    24 horas como máximo. Un solo cambio pendiente por cuenta. Solo cuentas
--    ACTIVAS, con el patrón de la migración 017 (FK compuesta a
--    users (id, status)).
--  * Cambiar la contraseña cierra las demás sesiones: nuevo motivo de
--    revocación de refresh tokens.

ALTER TABLE users ADD COLUMN phone VARCHAR(30)
  CONSTRAINT chk_users_phone_format
  CHECK (phone ~ '^\+?[0-9][0-9 ()-]{5,27}[0-9]$');

CREATE TABLE email_change_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL,
  user_status account_status NOT NULL DEFAULT 'active'
                CONSTRAINT chk_email_change_tokens_user_active CHECK (user_status = 'active'),
  -- Siempre normalizado (minúsculas, sin espacios), como users.email.
  new_email   VARCHAR(150) NOT NULL
                CONSTRAINT chk_email_change_tokens_new_email CHECK (new_email = lower(btrim(new_email))),
  token_hash  CHAR(64) NOT NULL UNIQUE CHECK (token_hash ~ '^[0-9a-f]{64}$'),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at  TIMESTAMPTZ NOT NULL,
  used_at     TIMESTAMPTZ,
  revoked_at  TIMESTAMPTZ,

  CONSTRAINT fk_email_change_tokens_active_user
    FOREIGN KEY (user_id, user_status) REFERENCES users (id, status)
    ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT chk_email_change_tokens_expiry CHECK (
    expires_at > created_at AND expires_at <= created_at + INTERVAL '24 hours'
  ),
  CONSTRAINT chk_email_change_tokens_one_ending CHECK (used_at IS NULL OR revoked_at IS NULL)
);

-- Un solo cambio de correo pendiente por cuenta.
CREATE UNIQUE INDEX uq_email_change_tokens_one_open
  ON email_change_tokens (user_id) WHERE used_at IS NULL AND revoked_at IS NULL;

ALTER TABLE refresh_tokens DROP CONSTRAINT refresh_tokens_revoke_reason_check;
ALTER TABLE refresh_tokens ADD CONSTRAINT refresh_tokens_revoke_reason_check
  CHECK (revoke_reason IN ('rotated', 'logout', 'reuse_detected', 'expired', 'password_reset',
                           'mfa_enabled', 'mfa_reset', 'password_change'));
