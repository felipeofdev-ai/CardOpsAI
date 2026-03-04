-- Versioned threshold management for deterministic backtesting

CREATE TABLE IF NOT EXISTS risk_thresholds (
  threshold_id BIGSERIAL PRIMARY KEY,
  threshold_name TEXT NOT NULL,
  version INT NOT NULL,
  value NUMERIC(18,6) NOT NULL,
  effective_from TIMESTAMPTZ NOT NULL,
  effective_to TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by TEXT DEFAULT current_user,
  UNIQUE (threshold_name, version)
);

CREATE TABLE IF NOT EXISTS threshold_sets (
  threshold_set_id BIGSERIAL PRIMARY KEY,
  set_name TEXT NOT NULL,
  version TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (set_name, version)
);

CREATE TABLE IF NOT EXISTS threshold_set_items (
  threshold_set_id BIGINT NOT NULL REFERENCES threshold_sets(threshold_set_id),
  threshold_id BIGINT NOT NULL REFERENCES risk_thresholds(threshold_id),
  PRIMARY KEY (threshold_set_id, threshold_id)
);
