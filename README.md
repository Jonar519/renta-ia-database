# renta-ia-database: la base de datos de Renta IA

Este repositorio es la **única fuente de verdad** del esquema de PostgreSQL de **Renta IA**: las
migraciones SQL numeradas, los datos de prueba (seed) y el modelo de dominio. El backend solo lo
consume (Prisma como cliente). La **guía completa para evaluar el proyecto** (acceso, roles y la prueba
de cada función paso a paso) está en el README principal, en
[renta-ia-backend](https://github.com/Jonar519/renta-ia-backend#readme).

## Contenido

1. [Qué es](#1-qué-es)
2. [Cómo funciona](#2-cómo-funciona)
3. [Tecnologías](#3-tecnologías)
4. [Qué se necesita](#4-qué-se-necesita)
5. [Acceso y roles](#5-acceso-y-roles)
6. [Guía de pruebas de la base](#6-guía-de-pruebas-de-la-base)
7. [Pruebas automatizadas](#7-pruebas-automatizadas)
8. [Limitaciones y decisiones de diseño](#8-limitaciones-y-decisiones-de-diseño)
9. [Solución de problemas](#9-solución-de-problemas)
10. [Estructura del repositorio](#10-estructura-del-repositorio)
11. [Glosario](#11-glosario)

## 1. Qué es

La base guarda las cuentas y su seguridad (invitaciones, sesiones, verificación en dos pasos,
recuperación, auditoría), los clientes de cada contador, los documentos y sus conceptos tributarios
con la revisión humana, los embeddings para el chat, las alertas, las conversaciones con la IA y las
métricas de rendimiento web.

Además **protege las reglas por sí misma**: una cuenta pendiente no tiene contraseña ni puede tener
sesiones, una invitación vence en 72 horas como máximo, solo se guarda el hash de cada token, el
secreto de la verificación en dos pasos solo se guarda cifrado y el cuerpo de un correo solo se guarda
con el proveedor simulado. Así se cumplen aunque el backend tenga un error.

## 2. Cómo funciona

- **26 migraciones** (`migrations/001_…sql` a `026_…sql`), cada una aplicada una sola vez y registrada
  en `schema_migrations`. Una migración aplicada no se edita: un cambio es un archivo nuevo.
- **Seed** (`seed/001_seed.sql`): 3 usuarios, 2 clientes, 2 documentos y algunos conceptos y alertas
  de ejemplo para desarrollo. Se puede cargar varias veces sin duplicar y **nunca** se carga en
  producción.
- **El backend no migra:** sus tests crean una base desechable con estas mismas migraciones (por eso
  los repositorios deben estar en carpetas hermanas).

```mermaid
erDiagram
  USERS ||--o{ CLIENTS : "contador de"
  USERS ||--o{ ACCOUNTANT_ASSISTANTS : "asistente de"
  CLIENTS ||--o{ DOCUMENTS : "tiene"
  DOCUMENTS ||--o{ TAX_CONCEPTS : "cifras extraídas"
  DOCUMENTS ||--o{ DOCUMENT_EMBEDDINGS : "fragmentos para el chat"
  CLIENTS ||--o{ ALERTS : "avisos"
  CLIENTS ||--o{ AI_CONVERSATIONS : "chat"
  USERS ||--o{ USER_SESSIONS : "sesiones"
  USERS ||--o| USER_INVITATIONS : "invitación"
```

El modelo completo (roles, entidades, ciclos de vida y qué regla hace cumplir la base y cuál la API)
está en [docs/modelo-de-dominio.md](docs/modelo-de-dominio.md); la lista de tablas y las garantías del
esquema, en la [referencia técnica](docs/referencia-tecnica.md).

## 3. Tecnologías

| Tecnología                        | Versión                              | Para qué se usa                                                | Por qué se eligió                                                                 |
| --------------------------------- | ------------------------------------ | -------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| **PostgreSQL**                    | 16 (imagen `pgvector/pgvector:pg16`) | Base de datos                                                  | Restricciones, FKs compuestas e índices únicos parciales para proteger las reglas. |
| **pgvector** · **pgcrypto**       | extensiones                          | Embeddings para el chat (RAG) · generación de UUID             | Datos y vectores en la misma base.                                                |
| **SQL puro** + scripts `.bat`/`.sh` | —                                  | Migraciones y seed                                             | Sin ORM gestionando el esquema: lo que se revisa es exactamente lo que corre.     |
| **Docker Compose**                | —                                    | PostgreSQL en el puerto 5433 en desarrollo                     | Mismo entorno en cualquier equipo.                                                |
| **GitHub Actions** · **gitleaks** | gitleaks `v8.21.2`                   | Migraciones sobre una base vacía, repetibles, seed idempotente y secretos | Cada `push` demuestra que el esquema se crea de cero.                    |
| **Railway**                       | —                                    | PostgreSQL con pgvector en producción                          | Mismo proyecto que la API y el worker.                                            |

## 4. Qué se necesita

- **Para evaluar en producción:** nada de este repositorio; solo el navegador (ver
  [Qué necesita el profesor](https://github.com/Jonar519/renta-ia-backend#4-qué-necesita-el-profesor)).
- **Para levantar la base en local:** Docker Desktop en marcha. En Windows (`cmd.exe`) no hace falta
  `psql`; en Linux o macOS, sí (lo usan los scripts `.sh`).

```bat
cd renta-ia-database
docker compose up -d
scripts\migrate.bat
scripts\seed.bat
```

En Linux o macOS:

```bash
cd renta-ia-database
docker compose up -d
export DATABASE_URL="postgresql://postgres:postgres@localhost:5433/renta_ia"
./scripts/migrate.sh
./scripts/seed.sh
```

Esperado: la migración aplica hasta `026_concept_review.sql` y el seed termina con
`Datos de prueba cargados correctamente.` Conexión de desarrollo (solo local):

```ini
DATABASE_URL=postgresql://postgres:postgres@localhost:5433/renta_ia
```

Después sigue con el backend y el frontend:
[opción local](https://github.com/Jonar519/renta-ia-backend#b-opción-local-opcional).

## 5. Acceso y roles

En la base, los roles son `admin`, `accountant` (contador), `assistant` (asistente de un contador) y
`client` (contribuyente con acceso a su expediente). Cómo se entra a la aplicación, las invitaciones y
la verificación en dos pasos:
[Acceso y roles](https://github.com/Jonar519/renta-ia-backend#5-acceso-y-roles).

Las cuentas del seed (`ana@example.com`, contadora; `luis@example.com`, su asistente;
`admin@example.com`, administrador) **solo existen en local**; su contraseña de prueba está en la
[referencia técnica](docs/referencia-tecnica.md#datos-de-prueba-seed). En producción no se carga el seed.

## 6. Guía de pruebas de la base

Con la base local levantada (sección 4). Las funciones de la aplicación se prueban con la
[guía principal](https://github.com/Jonar519/renta-ia-backend#6-guía-de-pruebas-función-por-función).

| Función                           | Qué hace                                             | Pasos para probarla                                                                                                                                                         | Resultado esperado                                                                                 |
| --------------------------------- | ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Migraciones repetibles            | Aplica solo lo pendiente                             | Corre `scripts\migrate.bat` dos veces                                                                                                                                       | La segunda vez: `Listo: 0 migracion(es) nueva(s) aplicada(s).`                                     |
| Seed idempotente                  | Recargar los datos de prueba no duplica              | Corre `scripts\seed.bat` dos veces y cuenta: `docker exec renta_ia_postgres psql -U postgres -d renta_ia -At -c "SELECT count(*) FROM users WHERE email LIKE '%@example.com'"` | El mismo número las dos veces.                                                                     |
| Regla: cuenta pendiente sin contraseña | Una cuenta activa no puede volver a pendiente con contraseña | `docker exec renta_ia_postgres psql -U postgres -d renta_ia -c "BEGIN; UPDATE users SET status = 'invited' WHERE email = 'ana@example.com'; ROLLBACK;"`        | `ERROR: new row for relation "users" violates check constraint "chk_users_password_by_status"`.    |
| Regla: formato del teléfono       | La base rechaza un teléfono inválido                 | `docker exec renta_ia_postgres psql -U postgres -d renta_ia -c "BEGIN; UPDATE users SET phone = 'abc' WHERE email = 'ana@example.com'; ROLLBACK;"`                          | `ERROR: new row for relation "users" violates check constraint "chk_users_phone_format"`.          |
| Modelo de dominio                 | Documenta roles, entidades, ciclos de vida y reglas  | Abre [docs/modelo-de-dominio.md](docs/modelo-de-dominio.md)                                                                                                                 | Diagrama al día (Mermaid) y cada regla con dónde se aplica.                                        |

## 7. Pruebas automatizadas

| Comando o paso                               | Qué cubre                                                                                                      | Resultado esperado                               |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| CI (`.github/workflows/`)                    | Migraciones sobre una base vacía, segunda corrida sin cambios, seed dos veces, todas registradas, base creada antes de `schema_migrations` y gitleaks | En verde en cada `push`.          |
| `scripts\migrate.bat` y `scripts\seed.bat`   | Lo mismo a mano, en local                                                                                      | 26 migraciones la primera vez, 0 la segunda.     |

Las reglas de la base también las prueban los tests de integración de `renta-ia-backend`, que aplican
estas migraciones en su propia base desechable.

## 8. Limitaciones y decisiones de diseño

- **El seed es solo para desarrollo:** sus contraseñas de prueba son públicas y anteriores a la
  política actual (sirven para entrar, pero el registro ya no las aceptaría). En producción no se carga.
- **El administrador del seed no trae la verificación en dos pasos activa:** el secreto se cifra con la
  clave de cada instalación, que la base no conoce; la activa en su primer ingreso.
- **Sin pruebas SQL propias:** las reglas se comprueban desde los tests del backend y la CI de este
  repositorio verifica que el esquema se crea de cero.
- **Las migraciones no corren solas en producción:** se aplican con el mismo script antes de desplegar.
- **`docs/erd.png` muestra el esquema inicial (001–009);** el diagrama al día está en el modelo de
  dominio.

## 9. Solución de problemas

| Síntoma                                                  | Qué hacer                                                                                                |
| -------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `docker compose up -d` falla: puerto 5433 ocupado        | Otro servicio usa el puerto: detenlo o cambia el puerto publicado (y el `DATABASE_URL` del backend).      |
| `migrate.bat` no se conecta                              | Docker Desktop no está en marcha o falta `docker compose up -d`.                                         |
| `migrate.sh` o `seed.sh`: `psql: command not found`      | Instala el cliente de PostgreSQL, o usa los `.bat` en Windows.                                           |
| `ERROR: define la variable de entorno DATABASE_URL`      | En Linux o macOS: `export DATABASE_URL="postgresql://postgres:postgres@localhost:5433/renta_ia"`.        |
| No puedo entrar con una cuenta del seed                  | Vuelve a cargar el seed (actualiza los hashes de las contraseñas de prueba) y revisa que sea en local.   |

## 10. Estructura del repositorio

```
renta-ia-database/
├── migrations/          # 001 … 026: extensiones, tipos, tablas, reglas y endurecimiento, en orden
├── seed/001_seed.sql    # datos de prueba (solo desarrollo)
├── scripts/             # migrate y seed en .bat (Windows) y .sh (Linux, macOS y CI); fingerprint.sh
├── docs/
│   ├── modelo-de-dominio.md   # roles, entidades, ciclos de vida y reglas
│   ├── referencia-tecnica.md  # motor, migraciones, tablas, seed y garantías del esquema
│   └── erd.png                # diagrama del esquema inicial
└── docker-compose.yml   # PostgreSQL 16 + pgvector
```

## 11. Glosario

| Término                  | Qué significa aquí                                                                                    |
| ------------------------ | ----------------------------------------------------------------------------------------------------- |
| **Migración**            | Archivo SQL numerado que cambia el esquema; se aplica una vez y queda registrado.                     |
| **Seed**                 | Datos de prueba que se cargan en una base de desarrollo.                                              |
| **Idempotente**          | Que se puede ejecutar varias veces con el mismo resultado.                                            |
| **CHECK / FK compuesta** | Condición que toda fila debe cumplir / referencia a varias columnas a la vez (por ejemplo, id y estado de la cuenta). |
| **Índice único parcial** | Unicidad solo entre las filas que cumplen una condición (por ejemplo, una invitación vigente por cuenta). |
| **Embedding / pgvector** | Lista de números que representa el significado de un texto / extensión que los guarda y compara.      |

El glosario completo del proyecto está en el
[README principal](https://github.com/Jonar519/renta-ia-backend#11-glosario).
