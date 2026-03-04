-- Tier 1 Fortune 500 SQL extensions for CardOpsAI

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS config_snapshots (
  snapshot_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  rules_hash TEXT NOT NULL,
  thresholds_hash TEXT NOT NULL,
  feature_schema_hash TEXT NOT NULL,
  risk_weights_hash TEXT NOT NULL,
  created_by TEXT DEFAULT current_user
);

ALTER TABLE decision_audit_log
  ADD COLUMN IF NOT EXISTS snapshot_id UUID REFERENCES config_snapshots(snapshot_id),
  ADD COLUMN IF NOT EXISTS previous_hash TEXT,
  ADD COLUMN IF NOT EXISTS decision_hash TEXT,
  ADD COLUMN IF NOT EXISTS tenant_id BIGINT;

CREATE INDEX IF NOT EXISTS idx_decision_tenant_time
  ON decision_audit_log (tenant_id, created_at DESC);

ALTER TABLE decision_explanations
  ADD COLUMN IF NOT EXISTS feature_value NUMERIC(18,6);

CREATE TABLE IF NOT EXISTS economic_objectives (
  objective_name TEXT PRIMARY KEY,
  revenue_weight NUMERIC(8,4) NOT NULL,
  fraud_weight NUMERIC(8,4) NOT NULL,
  capital_weight NUMERIC(8,4) NOT NULL,
  churn_weight NUMERIC(8,4) NOT NULL,
  active BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (revenue_weight >= 0 AND fraud_weight >= 0 AND capital_weight >= 0 AND churn_weight >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_single_active_economic_objective
  ON economic_objectives (active)
  WHERE active = TRUE;

CREATE TABLE IF NOT EXISTS model_drift_metrics (
  id BIGSERIAL PRIMARY KEY,
  model_version_id BIGINT,
  metric_name TEXT NOT NULL,
  baseline_value NUMERIC(16,6) NOT NULL,
  current_value NUMERIC(16,6) NOT NULL,
  drift_score NUMERIC(16,6) NOT NULL,
  threshold NUMERIC(16,6) NOT NULL,
  breach BOOLEAN GENERATED ALWAYS AS (drift_score > threshold) STORED,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION compute_decision_hash(
  p_previous_hash TEXT,
  p_payload JSONB
)
RETURNS TEXT AS $$
BEGIN
  RETURN encode(digest(COALESCE(p_previous_hash,'GENESIS') || p_payload::TEXT, 'sha256'), 'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION append_tamper_evident_decision(
  p_merchant_id BIGINT,
  p_problem_id TEXT,
  p_decision_score NUMERIC,
  p_action_taken TEXT,
  p_model_version_id BIGINT,
  p_snapshot_id UUID,
  p_tenant_id BIGINT,
  p_payload JSONB
)
RETURNS BIGINT AS $$
DECLARE
  v_prev_hash TEXT;
  v_hash TEXT;
  v_id BIGINT;
BEGIN
  SELECT decision_hash INTO v_prev_hash
  FROM decision_audit_log
  WHERE tenant_id = p_tenant_id
  ORDER BY id DESC
  LIMIT 1;

  v_hash := compute_decision_hash(v_prev_hash, p_payload);

  INSERT INTO decision_audit_log (
    merchant_id, problem_id, decision_score, action_taken,
    model_version_id, snapshot_id, tenant_id, previous_hash, decision_hash
  )
  VALUES (
    p_merchant_id, p_problem_id, p_decision_score, p_action_taken,
    p_model_version_id, p_snapshot_id, p_tenant_id, v_prev_hash, v_hash
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql;
