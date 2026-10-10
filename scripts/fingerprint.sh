#!/usr/bin/env bash
# scripts/fingerprint.sh
# Huella de una base de datos, para comparar antes/después de un cambio:
#   1. migraciones aplicadas (schema_migrations),
#   2. número exacto de filas por tabla,
#   3. SHA-256 del esquema (pg_dump --schema-only, sin comentarios ni
#      líneas que cambian entre corridas).
#
# Solo lectura: no modifica nada. Usa el psql/pg_dump del contenedor del
# docker-compose de este repo (no hace falta tener psql instalado).
#
# Uso:
#   ./scripts/fingerprint.sh                 # base renta_ia
#   ./scripts/fingerprint.sh renta_ia > huella.txt
#   diff huella-antes.txt huella-despues.txt

set -euo pipefail

DB="${1:-renta_ia}"
CONTAINER="${PG_CONTAINER:-renta_ia_postgres}"
PSQL=(docker exec -i "$CONTAINER" psql -U postgres -d "$DB" -X -q -tA)

echo "# Huella de la base '$DB'"
echo
echo "## Migraciones aplicadas"
"${PSQL[@]}" -c "SELECT filename FROM schema_migrations ORDER BY filename"
echo
echo "## Filas por tabla"
tables=$("${PSQL[@]}" -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename")
for t in $tables; do
  printf '%s\t%s\n' "$t" "$("${PSQL[@]}" -c "SELECT count(*) FROM \"$t\"")"
done
echo
echo "## Esquema"
schema_hash=$(docker exec -i "$CONTAINER" pg_dump -U postgres -d "$DB" --schema-only --no-owner --no-privileges \
  | grep -v -E '^(--|SET |SELECT pg_catalog\.set_config|\\(un)?restrict )' | sed '/^$/d' | sha256sum | cut -d' ' -f1)
echo "sha256 $schema_hash"
