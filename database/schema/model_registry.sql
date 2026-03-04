-- Model registry + deployments for SQL-native governance

CREATE TABLE IF NOT EXISTS model_registry (
  model_id BIGSERIAL PRIMARY KEY,
  model_name TEXT NOT NULL UNIQUE,
  model_type TEXT NOT NULL,
  owner TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS model_versions (
  model_version_id BIGSERIAL PRIMARY KEY,
  model_id BIGINT NOT NULL REFERENCES model_registry(model_id),
  version_label TEXT NOT NULL,
  training_window_start DATE,
  training_window_end DATE,
  feature_set_hash TEXT,
  metrics JSONB,
  approved_by TEXT,
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (model_id, version_label)
);

CREATE TABLE IF NOT EXISTS model_deployments (
  deployment_id BIGSERIAL PRIMARY KEY,
  model_version_id BIGINT NOT NULL REFERENCES model_versions(model_version_id),
  environment TEXT NOT NULL,
  traffic_pct NUMERIC(5,2) NOT NULL DEFAULT 100,
  is_shadow BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT FALSE,
  deployed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  rolled_back_at TIMESTAMPTZ
);
