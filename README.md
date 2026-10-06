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
│   ├── 011_alert_dedupe.sql # dedupe_key + índice único parcial: una alerta activa por situación
│   ├── 012_document_sha256.sql # SHA-256 del archivo: evita subir dos veces el mismo documento a un cliente
│   ├── 013_web_vitals.sql # Métricas Web Vitals (RUM) enviadas por el frontend
│   ├── 014_sessions_and_login_attempts.sql # Refresh tokens rotativos (solo su hash) y bloqueo progresivo de login
│   ├── 015_audit_log.sql # Registro de auditoría (sin datos sensibles)
│   ├── 016_roles.sql # Asistentes asignados a contadores y usuario de portal de cada cliente
│   ├── 017_account_status_and_invitations.sql # Cuentas pendientes (por invitación) garantizadas por el esquema, invitaciones y email_outbox
│   ├── 018_password_reset.sql # Tokens de recuperación de contraseña (15 min, un solo uso, solo cuentas activas)
│   └── 019_mfa.sql # Segundo factor TOTP: secreto cifrado, códigos de recuperación y pasos del login (solo cuentas activas)
├── seed/                 # Datos de prueba (solo desarrollo/demo)
│   ├── 001_seed.sql
│   └── perf/001_heavy_dataset.sql # Datos sintéticos masivos para mediciones de rendimiento (no los carga seed.bat)
├── scripts/
│   ├── migrate.sh / migrate.bat  # Aplica las migraciones pendientes (bash · cmd.exe)
│   ├── fingerprint.sh            # Huella de una base (migraciones, filas por tabla, hash del esquema): solo lectura
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

Para otra base (por ejemplo la de E2E), créala una vez y define `DB_NAME` antes de migrar:

```bat
docker exec renta_ia_postgres psql -U postgres -c "CREATE DATABASE renta_ia_e2e"
set DB_NAME=renta_ia_e2e
scripts\migrate.bat
```

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
| `web_vitals` | Métricas de experiencia real de usuario (LCP, INP, CLS…) |
| `refresh_tokens` | Sesiones: hash de cada refresh token, su familia de rotación y su revocación |
| `login_attempts` | Fallos de login por cuenta (clave = SHA-256 del correo) para el bloqueo progresivo |
| `audit_log` | Quién hizo qué, sobre qué entidad y cuándo (login, accesos, subidas, CRUD) |
| `accountant_assistants` | Qué asistentes trabajan para qué contador (rol `assistant`) |
| `schema_migrations` | Historial de migraciones aplicadas (lo gestionan los scripts) |

## Datos de prueba (seed)

El script `seed/001_seed.sql` crea 3 usuarios, 2 clientes, 2 documentos y algunas alertas/conceptos tributarios de ejemplo, útiles para desarrollar el backend y el frontend sin depender de documentos reales. **No debe ejecutarse en producción.**

Es idempotente: se puede volver a ejecutar sin duplicar datos. Al hacerlo sobre una base sembrada con una versión anterior, actualiza el hash de contraseña de los usuarios de prueba (antes eran hashes de ejemplo que no permitían iniciar sesión).

| Usuario          | Correo              | Rol        | Contraseña     |
| ---------------- | ------------------- | ---------- | -------------- |
| Ana Contadora    | `ana@example.com`   | accountant | `Password123!` |
| Luis Asistente   | `luis@example.com`  | assistant (trabaja para Ana: ve y edita sus clientes, no los crea ni borra) | `Password123!` |
| Admin Plataforma | `admin@example.com` | admin      | `Password123!` |

Las contraseñas del seed son anteriores a la política de contraseñas (10+ caracteres, sin comunes): sirven para iniciar sesión, pero el registro ya no aceptaría una así.

Los documentos del seed son solo metadatos: sus archivos no existen en `uploads/` del backend, así que no se pueden reprocesar.

## Cuentas pendientes: garantías del esquema (migración 017)

Desde la Fase 5 las cuentas se crean solo por invitación. Una cuenta `invited` (pendiente) no
tiene contraseña y **la base impide** que tenga sesiones (y, con el mismo patrón, tokens de
recuperación o pasos de MFA cuando existan esas tablas). No depende del backend.

| Regla | Restricción |
| --- | --- |
| Pendiente ⇔ sin contraseña | `chk_users_password_by_status` |
| Sesión solo de una cuenta activa | `refresh_tokens.user_status` con `CHECK = active` + FK compuesta `fk_refresh_tokens_active_user` → `users (id, status)` |
| No volver pendiente una cuenta con sesiones | La misma FK, `ON UPDATE NO ACTION` |
| Invitación solo para una cuenta pendiente | `fk_user_invitations_invited_user` + `CHECK (user_status = invited)` |
| Vigencia de 72 h como máximo | `chk_user_invitations_expiry` |
| Una invitación vigente por cuenta | índice único parcial `uq_user_invitations_one_open` |
| Solo el hash del token | `token_hash ~ ^[0-9a-f]{64}` |
| Cuerpo del correo solo con el proveedor simulado | `chk_email_outbox_body_only_mock` |
| Token de recuperación solo para una cuenta activa (018) | `fk_password_reset_tokens_active_user` + `CHECK (user_status = active)` |
| Recuperación: vigencia de 15 min como máximo (018) | `chk_password_reset_tokens_expiry` |
| Un token de recuperación vigente por cuenta (018) | índice único parcial `uq_password_reset_tokens_one_open` |
| MFA solo para una cuenta activa (019) | `fk_user_mfa_active_user`; códigos de recuperación y pasos del login cuelgan de `user_mfa` |
| Secreto TOTP solo cifrado (019) | `chk_user_mfa_ciphertext_format` (formato `v1.` de AES-256-GCM) |
| Paso del login: 5 min y 5 intentos como máximo (019) | `chk_mfa_challenges_expiry`, `chk_mfa_challenges_attempts` |

Patrón para cada tabla nueva "de cuenta activa":
`user_status account_status NOT NULL DEFAULT active CHECK (user_status = active)` y
`FOREIGN KEY (user_id, user_status) REFERENCES users (id, status) ON DELETE CASCADE`.
Por qué así y no con triggers: ADR 0009 en `renta-ia-backend/docs/adr/`. Las pruebas que
intentan violar cada regla con SQL directo están en `renta-ia-backend/tests/integration/accountStatus.test.ts`
(017), `passwordReset.test.ts` (018) y `mfa.test.ts` (019).
