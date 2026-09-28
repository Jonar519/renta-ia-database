-- 016_roles.sql
-- Roles "assistant" y "client" (existían en el enum user_role sin uso).
--
--   assistant: ayuda a uno o varios contadores. Accede a los clientes de
--              los contadores que tiene asignados; no puede borrar clientes.
--   client:    el contribuyente mismo. Solo lectura de SU cliente.
--
-- Ambos los crea un admin (el registro público solo crea contadores).

CREATE TABLE accountant_assistants (
  assistant_user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  accountant_user_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (assistant_user_id, accountant_user_id),
  CHECK (assistant_user_id <> accountant_user_id)
);

CREATE INDEX idx_accountant_assistants_accountant ON accountant_assistants (accountant_user_id);

-- Usuario del portal del contribuyente (rol client), como máximo uno por cliente.
ALTER TABLE clients ADD COLUMN portal_user_id UUID REFERENCES users(id) ON DELETE SET NULL;
CREATE UNIQUE INDEX uq_clients_portal_user ON clients (portal_user_id) WHERE portal_user_id IS NOT NULL;
