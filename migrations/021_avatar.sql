-- 021_avatar.sql
-- Foto de perfil (Fase 5, bloque B12).
--
-- El archivo vive en el almacenamiento (StorageService, ADR 0006); aquí solo
-- su clave y cuándo cambió (el frontend la usa para no mostrar una foto vieja).
--  * La clave tiene el formato que arma la API (storageKeys.avatar) y debe
--    estar bajo la carpeta de ESA cuenta: una fila no puede apuntar al avatar
--    de otra persona ni a un documento de un cliente.
--  * Clave y fecha van juntas: las dos o ninguna.

ALTER TABLE users
  ADD COLUMN avatar_key VARCHAR(200),
  ADD COLUMN avatar_updated_at TIMESTAMPTZ,
  ADD CONSTRAINT chk_users_avatar_key_format
    CHECK (avatar_key ~ '^users/[0-9a-f-]{36}/avatar/[0-9]{13}-[0-9a-f]{16}\.(jpg|png)$'),
  ADD CONSTRAINT chk_users_avatar_key_owner
    CHECK (avatar_key LIKE 'users/' || id::text || '/avatar/%'),
  ADD CONSTRAINT chk_users_avatar_pair
    CHECK ((avatar_key IS NULL) = (avatar_updated_at IS NULL));
