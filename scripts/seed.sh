#!/usr/bin/env bash
# scripts/seed.sh
# Carga los datos de prueba. Solo para entornos de desarrollo/demo.
#
# Uso:
#   export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/renta_ia"
#   ./scripts/seed.sh

set -euo pipefail

if [ -z "${DATABASE_URL:-}" ]; then
  echo "ERROR: define la variable de entorno DATABASE_URL antes de ejecutar este script."
  exit 1
fi

SEED_DIR="$(dirname "$0")/../seed"

for file in $(ls "$SEED_DIR"/*.sql | sort); do
  echo "-> cargando $(basename "$file")"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$file"
done

echo "Datos de prueba cargados correctamente."
