-- 017_account_status_and_invitations.sql
-- Alta de cuentas SOLO por invitación (Fase 5): estado de la cuenta,
-- invitaciones de un solo uso y bandeja de correos del proveedor simulado.
--
-- Garantía en el esquema (no solo en el backend):
--   una cuenta "invited" (pendiente) no tiene contraseña y NUNCA puede tener
--   sesiones (refresh_tokens), ni tokens de recuperación ni pasos de MFA
--   (tablas futuras, mismo patrón): solo su token de invitación.
--
-- Cómo, de forma declarativa (sin triggers):
--   * users tiene UNIQUE (id, status).
--   * Cada tabla "de cuenta activa" guarda una columna user_status con
--     CHECK (user_status = 'active') y una FK COMPUESTA
--     (user_id, user_status) → users (id, status).
--     - Insertar una sesión para una cuenta pendiente: la FK busca
--       (id, 'active') y no existe → error.
--     - Volver pendiente una cuenta con sesiones: la FK es ON UPDATE NO
--       ACTION → el UPDATE de users.status falla mientras existan filas.
--   * user_invitations usa el mismo patrón con 'invited': una invitación solo
--     puede apuntar a una cuenta pendiente, y una cuenta no se puede activar
--     mientras le queden invitaciones (hay que consumirlas en la misma
--     transacción en que se activa).
--
-- Patrón obligatorio para B7 (password_reset_tokens) y B8 (pasos de MFA):
--   user_status account_status NOT NULL DEFAULT 'active' CHECK (user_status = 'active'),
--   FOREIGN KEY (user_id, user_status) REFERENCES users (id, status) ON DELETE CASCADE

-- ---------------------------------------------------------------------------
-- 1. Estado de la cuenta
-- ---------------------------------------------------------------------------

CREATE TYPE account_status AS ENUM ('invited', 'active');

-- Las cuentas existentes ya tienen contraseña: quedan activas.
ALTER TABLE users ADD COLUMN status account_status NOT NULL DEFAULT 'active';
ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;

-- Pendiente ⇔ sin contraseña. Un admin no fija contraseñas ajenas: la cuenta
-- nace pendiente y la contraseña la define la persona invitada al activarla.
ALTER TABLE users ADD CONSTRAINT chk_users_password_by_status CHECK (
  (status = 'invited' AND password_hash IS NULL)
  OR (status = 'active' AND password_hash IS NOT NULL)
);

-- Destino de las FK compuestas (id ya es único; esto habilita la referencia).
ALTER TABLE users ADD CONSTRAINT uq_users_id_status UNIQUE (id, status);

-- ---------------------------------------------------------------------------
-- 2. Sesiones (refresh tokens): solo de cuentas activas
-- ---------------------------------------------------------------------------

ALTER TABLE refresh_tokens
  ADD COLUMN user_status account_status NOT NULL DEFAULT 'active'
    CONSTRAINT chk_refresh_tokens_user_active CHECK (user_status = 'active');

ALTER TABLE refresh_tokens DROP CONSTRAINT refresh_tokens_user_id_fkey;
ALTER TABLE refresh_tokens
  ADD CONSTRAINT fk_refresh_tokens_active_user
  FOREIGN KEY (user_id, user_status) REFERENCES users (id, status)
  ON DELETE CASCADE ON UPDATE NO ACTION;

-- ---------------------------------------------------------------------------
-- 3. Invitaciones: token firmado de un solo uso, 72 h, solo su hash
-- ---------------------------------------------------------------------------

CREATE TABLE user_invitations (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL,
  user_status   account_status NOT NULL DEFAULT 'invited'
                  CONSTRAINT chk_user_invitations_user_invited CHECK (user_status = 'invited'),
  -- SHA-256 del token; el token en claro solo viaja en el correo.
  token_hash    CHAR(64) NOT NULL UNIQUE CHECK (token_hash ~ '^[0-9a-f]{64}$'),
  invited_by    UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at    TIMESTAMPTZ NOT NULL,
  -- Reenviar invalida el enlace anterior (resent); el admin puede cancelar.
  revoked_at    TIMESTAMPTZ,
  revoke_reason VARCHAR(20) CHECK (revoke_reason IN ('resent', 'cancelled')),

  CONSTRAINT fk_user_invitations_invited_user
    FOREIGN KEY (user_id, user_status) REFERENCES users (id, status)
    ON DELETE CASCADE ON UPDATE NO ACTION,
  -- Vigencia de 72 horas como máximo, impuesta también por la base.
  CONSTRAINT chk_user_invitations_expiry CHECK (
    expires_at > created_at AND expires_at <= created_at + INTERVAL '72 hours'
  ),
  CONSTRAINT chk_user_invitations_revoke_pair CHECK ((revoked_at IS NULL) = (revoke_reason IS NULL))
);

-- Como máximo UNA invitación vigente (no revocada) por cuenta.
CREATE UNIQUE INDEX uq_user_invitations_one_open
  ON user_invitations (user_id) WHERE revoked_at IS NULL;
CREATE INDEX idx_user_invitations_invited_by ON user_invitations (invited_by);

-- ---------------------------------------------------------------------------
-- 4. Bandeja de correos (EmailProvider)
-- ---------------------------------------------------------------------------

-- Cada correo "enviado". Con el proveedor simulado (mock, solo desarrollo y
-- pruebas: la API se niega a arrancar con él en producción) se guarda el
-- contenido completo para que las pruebas y las demos puedan leerlo, por
-- ejemplo el enlace de invitación. Con el proveedor real (SES) solo se
-- guardan metadatos: el CHECK impide guardar el cuerpo, que puede llevar un
-- token en claro.
CREATE TABLE email_outbox (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider            VARCHAR(10)  NOT NULL CHECK (provider IN ('mock', 'ses')),
  to_address          VARCHAR(150) NOT NULL,
  template            VARCHAR(40)  NOT NULL,
  subject             VARCHAR(200) NOT NULL,
  body_text           TEXT,
  body_html           TEXT,
  status              VARCHAR(10)  NOT NULL CHECK (status IN ('sent', 'failed')),
  provider_message_id VARCHAR(200),
  error               VARCHAR(300),
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),

  CONSTRAINT chk_email_outbox_body_only_mock
    CHECK (provider = 'mock' OR (body_text IS NULL AND body_html IS NULL)),
  CONSTRAINT chk_email_outbox_error_when_failed CHECK ((status = 'failed') = (error IS NOT NULL))
);

CREATE INDEX idx_email_outbox_to_created ON email_outbox (lower(to_address), created_at DESC);
CREATE INDEX idx_email_outbox_created ON email_outbox (created_at DESC);
