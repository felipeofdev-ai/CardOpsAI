-- Operational observability metrics

CREATE TABLE IF NOT EXISTS decision_latency_metrics (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT,
  decision_id BIGINT,
  latency_ms NUMERIC(12,3) NOT NULL,
  measured_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rule_execution_metrics (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT,
  rule_name TEXT NOT NULL,
  hit_count BIGINT NOT NULL,
  avg_exec_ms NUMERIC(12,3),
  measured_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS approval_rate_metrics (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT,
  approval_rate NUMERIC(10,6) NOT NULL,
  window_start TIMESTAMPTZ NOT NULL,
  window_end TIMESTAMPTZ NOT NULL,
  measured_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chargeback_rate_metrics (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT,
  chargeback_rate NUMERIC(10,6) NOT NULL,
  window_start TIMESTAMPTZ NOT NULL,
  window_end TIMESTAMPTZ NOT NULL,
  measured_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS anomaly_detection_events (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT,
  metric_name TEXT NOT NULL,
  baseline_value NUMERIC(18,6),
  observed_value NUMERIC(18,6),
  anomaly_score NUMERIC(18,6),
  severity TEXT,
  payload JSONB,
  detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
