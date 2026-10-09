-- 024_account_deletion.sql
-- Eliminar la propia cuenta (Fase 5, bloque B14). Política completa:
-- renta-ia-backend/docs/data-retention.md.
--
-- Una cuenta eliminada NO se borra de users: queda como lápida anónima.
--  * documents.uploaded_by y clients.accountant_user_id son ON DELETE
--    RESTRICT: los documentos son del expediente del cliente y deben seguir
--    diciendo quién los subió ("Cuenta eliminada"), no desaparecer ni quedar
--    sin autor.
--  * audit_log conserva a quién pertenece cada registro (no cae a NULL).
-- Garantías de la base:
--  * Una cuenta eliminada no conserva ningún dato personal: ni nombre, ni
--    correo, ni teléfono, ni foto, ni contraseña (CHECK).
--  * Tampoco sesiones, MFA ni tokens: las FK compuestas de 017-022 exigen
--    status = 'active' y no dejan cambiar el estado mientras existan.
--  * Un contador con clientes no puede eliminarse: los clientes exigen un
--    contador ACTIVO (FK compuesta, el mismo patrón de 017).

ALTER TABLE users ADD COLUMN deleted_at TIMESTAMPTZ;

ALTER TABLE users DROP CONSTRAINT chk_users_password_by_status;
ALTER TABLE users ADD CONSTRAINT chk_users_password_by_status CHECK (
  (status = 'invited' AND password_hash IS NULL)
  OR (status = 'active' AND password_hash IS NOT NULL)
  OR (status = 'deleted' AND password_hash IS NULL)
);

-- La lápida: fecha de eliminación si y solo si está eliminada, y nada personal.
ALTER TABLE users ADD CONSTRAINT chk_users_deleted_at
  CHECK ((status = 'deleted') = (deleted_at IS NOT NULL));
ALTER TABLE users ADD CONSTRAINT chk_users_deleted_scrubbed CHECK (
  status <> 'deleted'
  OR (
    name = 'Cuenta eliminada'
    AND email = 'eliminada-' || id::text || '@renta-ia.invalid'
    AND phone IS NULL
    AND avatar_key IS NULL
  )
);

-- Los clientes exigen un contador activo.
ALTER TABLE clients
  ADD COLUMN accountant_status account_status NOT NULL DEFAULT 'active'
    CONSTRAINT chk_clients_accountant_active CHECK (accountant_status = 'active');
ALTER TABLE clients DROP CONSTRAINT clients_accountant_user_id_fkey;
ALTER TABLE clients
  ADD CONSTRAINT fk_clients_active_accountant
  FOREIGN KEY (accountant_user_id, accountant_status) REFERENCES users (id, status)
  ON DELETE RESTRICT ON UPDATE NO ACTION;
