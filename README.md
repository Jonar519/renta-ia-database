# renta-ia-database

Esquema, migraciones y datos de prueba de la base de datos del **Sistema de Gestión Documental Contable con IA**. Este repositorio es la única fuente de verdad sobre la estructura de la base de datos: cualquier cambio al esquema se hace aquí, mediante una nueva migración numerada, nunca directamente sobre la base de datos.

## Contenido del repositorio

```
renta-ia-database/
├── migrations/          # Scripts SQL numerados, se ejecutan en orden
│   ├── 001_extensions.sql
│   ├── 002_enums.sql
│   ├── 003_users.sql
│   ├── 004_clients.sql
│   ├── 005_documents.sql
│   ├── 006_tax_concepts.sql
│   ├── 007_document_embeddings.sql
│   ├── 008_alerts.sql
│   ├── 009_ai_conversations_and_messages.sql
│   ├── 010_hardening.sql # Índices, UNIQUE/CHECK, email sin mayúsculas, updated_at automático
│   └── 011_alert_dedupe.sql # dedupe_key + índice único parcial: una alerta activa por situación
├── seed/                 # Datos de prueba (solo desarrollo/demo)
│   └── 001_seed.sql
├── scripts/
│   ├── migrate.sh / migrate.bat  # Aplica las migraciones pendientes (bash · cmd.exe)
│   └── seed.sh / seed.bat        # Carga los datos de prueba
├── docs/
│   └── erd.png             # Diagrama entidad-relación
└── docker-compose.yml    # Postgres + pgvector para desarrollo local
```

## Motor de base de datos

- **PostgreSQL 16** con la extensión **pgvector** (búsqueda semántica para RAG) y **pgcrypto** (generación de UUIDs).
- En producción se usa **Amazon RDS for PostgreSQL** (versión 15.3 o superior, que soporta pgvector de forma nativa).

## Cómo levantar la base de datos en local

El `docker-compose.yml` publica Postgres en el puerto **5433** del host (`5433:5432`), para no chocar con un Postgres instalado localmente en el 5432. Usuario/contraseña: `postgres`/`postgres`, base `renta_ia`.

### Windows (cmd.exe): no necesita `psql` instalado

Los `.bat` ejecutan `psql` dentro del contenedor (`docker exec`):

```bat
:: 1. Levantar el contenedor de Postgres con pgvector
docker compose up -d

:: 2. Aplicar las migraciones pendientes
scripts\migrate.bat

:: 3. (Opcional) cargar datos de prueba
scripts\seed.bat
```

### Linux / macOS / Git Bash: requiere `psql` en el host

```bash
# 1. Levantar el contenedor de Postgres con pgvector
docker compose up -d

# 2. Exportar la cadena de conexión (usada por los scripts)
export DATABASE_URL="postgresql://postgres:postgres@localhost:5433/renta_ia"

# 3. Aplicar las migraciones pendientes
./scripts/migrate.sh

# 4. (Opcional) cargar datos de prueba
./scripts/seed.sh
```

Para conectarte manualmente y explorar las tablas:

```bash
psql "$DATABASE_URL"
```

## Cómo aplicar migraciones contra RDS (staging/producción)

```bash
export DATABASE_URL="postgresql://<usuario>:<password>@<endpoint-rds>.rds.amazonaws.com:5432/renta_ia"
./scripts/migrate.sh
```

**Importante:** antes de la primera migración en RDS, conéctate una vez como usuario maestro y confirma que las extensiones estén disponibles:

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;
```

RDS permite `pgvector` desde el parameter group por defecto en versiones recientes de Postgres 15/16; si el `CREATE EXTENSION vector` falla, verifica la versión del motor y el parameter group asociado a la instancia.

## Historial de migraciones (`schema_migrations`)

Los scripts registran cada migración aplicada en la tabla `schema_migrations` (`filename`, `applied_at`) y **saltan las que ya corrieron**, así que `migrate` se puede ejecutar cuantas veces se quiera. Cada migración y su registro corren en **una sola transacción**: si una falla, no queda aplicada a medias ni marcada como aplicada.

**Bases creadas antes de este mecanismo:** si la base ya tiene las tablas pero `schema_migrations` está vacía, los scripts registran 001–009 como ya aplicadas (_baseline_) y solo ejecutan las nuevas (010 en adelante). No hace falta recrear la base.

```sql
-- Ver qué migraciones tiene aplicadas una base
SELECT filename, applied_at FROM schema_migrations ORDER BY filename;
```

## Convención de migraciones

- Cada archivo se numera secuencialmente (`0NN_descripcion.sql`) y **nunca se modifica** después de haberse aplicado en cualquier entorno compartido (staging o producción). Un cambio de esquema siempre se hace con una migración nueva.
- Gracias a `schema_migrations` las migraciones no necesitan ser idempotentes, pero conviene que lo sean cuando es barato (`IF NOT EXISTS`).
- No usar `CREATE INDEX CONCURRENTLY`: los scripts ejecutan cada archivo dentro de una transacción, y `CONCURRENTLY` no puede correr dentro de una.
- El backend (`renta-ia-backend`) consume este esquema a través de Prisma; el archivo `schema.prisma` de ese repositorio debe reflejar exactamente estas tablas. Cualquier cambio aquí implica actualizar el `schema.prisma` correspondiente.

## Diagrama entidad-relación

Ver [`docs/erd.png`](docs/erd.png). Resumen de entidades:

| Entidad | Descripción |
|---|---|
| `users` | Contadores, asistentes, administradores y clientes con acceso a la plataforma |
| `clients` | Personas naturales o pequeñas empresas cuya declaración de renta se gestiona |
| `documents` | Metadatos de cada documento subido (el archivo original vive en S3) |
| `tax_concepts` | Cifras tributarias estructuradas, extraídas por IA de cada documento |
| `document_embeddings` | Vectores semánticos de cada documento, usados para RAG |
| `alerts` | Vencimientos e inconsistencias detectadas |
| `ai_conversations` / `ai_messages` | Historial del chat conversacional con el asistente de IA |
| `schema_migrations` | Historial de migraciones aplicadas (lo gestionan los scripts) |

## Datos de prueba (seed)

El script `seed/001_seed.sql` crea 3 usuarios, 2 clientes, 2 documentos y algunas alertas/conceptos tributarios de ejemplo, útiles para desarrollar el backend y el frontend sin depender de documentos reales. **No debe ejecutarse en producción.**

Es idempotente: se puede volver a ejecutar sin duplicar datos. Al hacerlo sobre una base sembrada con una versión anterior, actualiza el hash de contraseña de los usuarios de prueba (antes eran hashes de ejemplo que no permitían iniciar sesión).

| Usuario          | Correo              | Rol        | Contraseña     |
| ---------------- | ------------------- | ---------- | -------------- |
| Ana Contadora    | `ana@example.com`   | accountant | `Password123!` |
| Luis Asistente   | `luis@example.com`  | assistant  | `Password123!` |
| Admin Plataforma | `admin@example.com` | admin      | `Password123!` |

Los documentos del seed son solo metadatos: sus archivos no existen en `uploads/` del backend, así que no se pueden reprocesar.
