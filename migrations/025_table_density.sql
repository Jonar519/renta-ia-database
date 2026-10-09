-- 025_table_density.sql
-- Densidad de las tablas (Fase 5, bloque B15): preferencia de trabajo de
-- cada persona, guardada en su cuenta para que la siga en cualquier equipo.
-- El tema (claro/oscuro) no se guarda: es del entorno y lo decide el sistema
-- operativo. La densidad es una forma de trabajar.

ALTER TABLE users
  ADD COLUMN table_density VARCHAR(12) NOT NULL DEFAULT 'comfortable'
    CONSTRAINT chk_users_table_density CHECK (table_density IN ('comfortable', 'compact'));
