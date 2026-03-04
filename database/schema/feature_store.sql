-- Feature store lineage + versioning

CREATE TABLE IF NOT EXISTS feature_registry (
  feature_name TEXT PRIMARY KEY,
  domain TEXT NOT NULL,
  owner TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS feature_versions (
  feature_version_id BIGSERIAL PRIMARY KEY,
  feature_name TEXT NOT NULL REFERENCES feature_registry(feature_name),
  version INT NOT NULL,
  sql_definition TEXT NOT NULL,
  data_type TEXT NOT NULL,
  snapshot_compatible BOOLEAN NOT NULL DEFAULT TRUE,
  active BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (feature_name, version)
);

CREATE TABLE IF NOT EXISTS feature_materializations (
  materialization_id BIGSERIAL PRIMARY KEY,
  feature_version_id BIGINT NOT NULL REFERENCES feature_versions(feature_version_id),
  snapshot_id UUID,
  tenant_id BIGINT,
  target_object TEXT NOT NULL,
  window_start TIMESTAMPTZ,
  window_end TIMESTAMPTZ,
  row_count BIGINT,
  checksum TEXT,
  materialized_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS feature_drift_scores (
  id BIGSERIAL PRIMARY KEY,
  feature_name TEXT NOT NULL,
  feature_version_id BIGINT,
  baseline_value NUMERIC(18,6) NOT NULL,
  current_value NUMERIC(18,6) NOT NULL,
  delta NUMERIC(18,6) NOT NULL,
  drift_score NUMERIC(18,6) NOT NULL,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
