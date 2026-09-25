#!/usr/bin/env bash
# scripts/migrate.sh
# Aplica, en orden, las migraciones de migrations/ que todavía no se hayan
# aplicado a la base indicada en DATABASE_URL. Se puede correr las veces
# que se quiera: las ya aplicadas se saltan.
#
# Historial: tabla schema_migrations (filename, applied_at). Cada migración
# y su registro en el historial se ejecutan en UNA transacción: si la
# migración falla, no queda aplicada a medias ni marcada como aplicada.
#
# Uso local (con el docker-compose de este repo, que publica el puerto 5433):
#   export DATABASE_URL="postgresql://postgres:postgres@localhost:5433/renta_ia"
#   ./scripts/migrate.sh
#
# Uso contra RDS (producción/staging; RDS escucha en el 5432):
#   export DATABASE_URL="postgresql://usuario:password@<endpoint-rds>:5432/renta_ia"
#   ./scripts/migrate.sh

set -euo pipefail

if [ -z "${DATABASE_URL:-}" ]; then
  echo "ERROR: define la variable de entorno DATABASE_URL antes de ejecutar este script."
  exit 1
fi

MIGRATIONS_DIR="$(cd "$(dirname "$0")/../migrations" && pwd)"
# Oculta los NOTICE de Postgres (ej. "already exists, skipping"); los errores se siguen mostrando.
export PGOPTIONS="${PGOPTIONS:-} -c client_min_messages=warning"
PSQL=(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -X -q)

"${PSQL[@]}" -c "CREATE TABLE IF NOT EXISTS schema_migrations (
  filename   VARCHAR(255) PRIMARY KEY,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);"

# Baseline: una base creada antes de que existiera schema_migrations ya
# tiene aplicadas las migraciones 001-009. Se registran como aplicadas en
# vez de volver a ejecutarlas (fallarían en CREATE TYPE / CREATE TABLE).
tracked=$("${PSQL[@]}" -tAc "SELECT count(*) FROM schema_migrations")
has_schema=$("${PSQL[@]}" -tAc "SELECT to_regclass('public.users') IS NOT NULL")
if [ "$tracked" = "0" ] && [ "$has_schema" = "t" ]; then
  echo "Base existente sin historial de migraciones: se registran 001-009 como ya aplicadas (baseline)."
  for file in "$MIGRATIONS_DIR"/00[1-9]_*.sql; do
    "${PSQL[@]}" -c "INSERT INTO schema_migrations (filename) VALUES ('$(basename "$file")') ON CONFLICT DO NOTHING"
  done
fi

echo "Aplicando migraciones pendientes desde $MIGRATIONS_DIR ..."
pending=0
for file in "$MIGRATIONS_DIR"/*.sql; do
  name="$(basename "$file")"
  if [ "$("${PSQL[@]}" -tAc "SELECT 1 FROM schema_migrations WHERE filename = '$name'")" = "1" ]; then
    echo "   ya aplicada: $name"
    continue
  fi
  echo "-> aplicando $name"
  "${PSQL[@]}" --single-transaction -f "$file" -c "INSERT INTO schema_migrations (filename) VALUES ('$name')"
  pending=$((pending + 1))
done

echo "Listo: $pending migración(es) nueva(s) aplicada(s)."
