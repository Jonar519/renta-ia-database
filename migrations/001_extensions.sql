-- 001_extensions.sql
-- Extensiones necesarias para el proyecto.
-- pgcrypto: generación de UUIDs (gen_random_uuid())
-- vector (pgvector): almacenamiento y búsqueda de embeddings para RAG
--
-- En AWS RDS, estas extensiones deben estar en el parameter group de la
-- instancia (shared_preload_libraries) y el usuario maestro debe tener
-- privilegios para crearlas. RDS Postgres 15.3+ soporta pgvector de forma nativa.

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;
