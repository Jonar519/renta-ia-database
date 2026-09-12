#!/usr/bin/env bash
# scripts/migrate.sh
# Ejecuta todas las migraciones en orden contra la base de datos indicada
# en la variable de entorno DATABASE_URL.
#
# Uso local (con el docker-compose de este repo):
#   export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/renta_ia"
#   ./scripts/migrate.sh
#
# Uso contra RDS (producción/staging):
#   export DATABASE_URL="postgresql://usuario:password@<endpoint-rds>:5432/renta_ia"
#   ./scripts/migrate.sh

set -euo pipefail

if [ -z "${DATABASE_URL:-}" ]; then
  echo "ERROR: define la variable de entorno DATABASE_URL antes de ejecutar este script."
  exit 1
fi

MIGRATIONS_DIR="$(dirname "$0")/../migrations"

echo "Aplicando migraciones desde $MIGRATIONS_DIR ..."
for file in $(ls "$MIGRATIONS_DIR"/*.sql | sort); do
  echo "-> ejecutando $(basename "$file")"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$file"
done

echo "Migraciones aplicadas correctamente."
