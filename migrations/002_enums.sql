-- 002_enums.sql
-- Tipos enumerados usados por varias tablas. Se definen aparte para poder
-- referenciarlos desde múltiples migraciones y documentarlos en un solo lugar.

CREATE TYPE user_role AS ENUM ('admin', 'accountant', 'assistant', 'client');

CREATE TYPE document_type AS ENUM (
  'income_certificate',   -- certificado de ingresos y retenciones
  'bank_statement',       -- extracto bancario
  'deductible_invoice',   -- factura deducible
  'exogenous_info',       -- información exógena
  'pension_certificate',  -- certificado de aportes a pensión/salud
  'other'
);

CREATE TYPE document_status AS ENUM ('uploaded', 'processing', 'processed', 'error');

CREATE TYPE tax_concept_type AS ENUM (
  'gross_income',
  'withholding',
  'deduction',
  'pension_contribution',
  'health_contribution',
  'other'
);

CREATE TYPE alert_type AS ENUM ('deadline', 'inconsistency');

CREATE TYPE alert_severity AS ENUM ('low', 'medium', 'high', 'critical');

CREATE TYPE alert_status AS ENUM ('open', 'acknowledged', 'resolved');

CREATE TYPE ai_message_role AS ENUM ('user', 'assistant');
