-- 023_account_status_deleted.sql
-- Estado "deleted" para las cuentas eliminadas (Fase 5, bloque B14).
--
-- Va sola en su migración: PostgreSQL no deja USAR un valor nuevo de un enum
-- en la misma transacción que lo agrega, y cada migración corre en UNA
-- transacción. Las reglas que lo usan están en 024_account_deletion.sql.

ALTER TYPE account_status ADD VALUE IF NOT EXISTS 'deleted';
