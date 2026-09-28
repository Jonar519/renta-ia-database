-- 013_web_vitals.sql
-- Métricas de rendimiento medidas en navegadores reales (RUM): Core Web
-- Vitals (LCP, INP, CLS), TTFB, FCP, FID (histórica, ver docs del frontend)
-- y tareas largas del hilo principal (LONG_TASK, LOAF).
--
-- Privacidad: NO se guarda usuario, IP, user-agent ni la URL real. La ruta
-- se normaliza en el navegador ("/clients/:id", nunca el id) y el
-- dispositivo es solo una categoría (mobile / tablet / desktop).

CREATE TABLE web_vitals (
  id               BIGSERIAL PRIMARY KEY,
  metric           VARCHAR(12)  NOT NULL
                   CHECK (metric IN ('LCP', 'INP', 'CLS', 'TTFB', 'FCP', 'FID', 'LONG_TASK', 'LOAF')),
  value            DOUBLE PRECISION NOT NULL CHECK (value >= 0),
  rating           VARCHAR(20)  CHECK (rating IN ('good', 'needs-improvement', 'poor')),
  route            VARCHAR(100) NOT NULL,
  device           VARCHAR(10)  NOT NULL CHECK (device IN ('mobile', 'tablet', 'desktop')),
  navigation_type  VARCHAR(20),
  -- Para LOAF: origen del script que más bloqueó (nombre de archivo, sin query string).
  attribution      VARCHAR(200),
  created_at       TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Consultas de la vista "Rendimiento": p75 por métrica y ruta en una ventana de días.
CREATE INDEX idx_web_vitals_metric_route_created ON web_vitals (metric, route, created_at DESC);
-- Limpieza por antigüedad (job de retención).
CREATE INDEX idx_web_vitals_created ON web_vitals (created_at);
