-- 019_mfa.sql
-- Segundo factor (TOTP, RFC 6238) — Fase 5, bloque B8.
--
--  * user_mfa: el secreto TOTP de cada cuenta, CIFRADO por la API con
--    AES-256-GCM (clave en la variable de entorno MFA_ENCRYPTION_KEY, que
--    nunca está en la base). Quien lea la base no puede generar códigos.
--    enabled_at NULL = configuración empezada pero no confirmada con un código.
--    last_used_step: último paso de 30 s aceptado; un código ya usado no se
--    acepta otra vez (anti-replay).
--  * mfa_recovery_codes: 10 códigos de un solo uso por cuenta, solo su SHA-256.
--  * mfa_challenges: el paso intermedio del login (contraseña correcta, falta
--    el código). Token firmado de un solo uso, 5 minutos, máximo 5 intentos.
--
-- Solo cuentas ACTIVAS, con el patrón de la migración 017: user_mfa lleva
-- user_status = 'active' y FK compuesta a users (id, status). Los códigos de
-- recuperación y los pasos del login cuelgan de user_mfa: una cuenta
-- pendiente no puede tener ninguno de los tres, y una cuenta con MFA no
-- puede volver a pendiente. Desactivar MFA (borrar user_mfa) borra en cascada
-- sus códigos y sus pasos de login abiertos.

CREATE TABLE user_mfa (
  user_id           UUID PRIMARY KEY,
  user_status       account_status NOT NULL DEFAULT 'active'
                      CONSTRAINT chk_user_mfa_user_active CHECK (user_status = 'active'),
  -- "v1.<iv>.<tag>.<cifrado>" en base64url (formato de la API).
  secret_ciphertext TEXT NOT NULL
                      CONSTRAINT chk_user_mfa_ciphertext_format
                      CHECK (secret_ciphertext ~ '^v1\.[A-Za-z0-9_-]{16}\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{16,}$'),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  enabled_at        TIMESTAMPTZ,
  last_used_step    BIGINT CONSTRAINT chk_user_mfa_last_step CHECK (last_used_step >= 0),

  CONSTRAINT fk_user_mfa_active_user
    FOREIGN KEY (user_id, user_status) REFERENCES users (id, status)
    ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT chk_user_mfa_enabled_after_created CHECK (enabled_at IS NULL OR enabled_at >= created_at)
);

CREATE TABLE mfa_recovery_codes (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES user_mfa (user_id) ON DELETE CASCADE,
  code_hash  CHAR(64) NOT NULL CHECK (code_hash ~ '^[0-9a-f]{64}$'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  used_at    TIMESTAMPTZ,
  CONSTRAINT uq_mfa_recovery_codes_user_code UNIQUE (user_id, code_hash)
);

CREATE TABLE mfa_challenges (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES user_mfa (user_id) ON DELETE CASCADE,
  token_hash CHAR(64) NOT NULL UNIQUE CHECK (token_hash ~ '^[0-9a-f]{64}$'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  attempts   SMALLINT NOT NULL DEFAULT 0
               CONSTRAINT chk_mfa_challenges_attempts CHECK (attempts BETWEEN 0 AND 5),
  used_at    TIMESTAMPTZ,
  CONSTRAINT chk_mfa_challenges_expiry CHECK (
    expires_at > created_at AND expires_at <= created_at + INTERVAL '5 minutes'
  )
);
CREATE INDEX idx_mfa_challenges_user ON mfa_challenges (user_id);

-- Sesiones revocadas al activar MFA (las demás sesiones de la cuenta) o
-- cuando un admin restablece el MFA de otra cuenta.
ALTER TABLE refresh_tokens DROP CONSTRAINT refresh_tokens_revoke_reason_check;
ALTER TABLE refresh_tokens ADD CONSTRAINT refresh_tokens_revoke_reason_check
  CHECK (revoke_reason IN ('rotated', 'logout', 'reuse_detected', 'expired', 'password_reset', 'mfa_enabled', 'mfa_reset'));
