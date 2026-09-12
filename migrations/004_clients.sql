-- 004_clients.sql
-- Clientes contribuyentes (personas naturales o pequeñas empresas) cuya
-- declaración de renta gestiona un contador de la plataforma.

CREATE TABLE clients (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  accountant_user_id  UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  full_name           VARCHAR(200) NOT NULL,
  document_number     VARCHAR(30) NOT NULL, -- cédula o NIT
  email               VARCHAR(150),
  phone               VARCHAR(30),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (accountant_user_id, document_number)
);

CREATE INDEX idx_clients_accountant ON clients(accountant_user_id);
CREATE INDEX idx_clients_document_number ON clients(document_number);
