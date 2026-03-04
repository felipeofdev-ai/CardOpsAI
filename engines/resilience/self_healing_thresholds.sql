-- Self-healing threshold adaptation based on fraud, latency and drift signals

CREATE TABLE IF NOT EXISTS threshold_adjustment_log (
  id BIGSERIAL PRIMARY KEY,
  threshold_name TEXT NOT NULL,
  old_value NUMERIC(18,6) NOT NULL,
  new_value NUMERIC(18,6) NOT NULL,
  reason TEXT NOT NULL,
  adjusted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION auto_adjust_threshold(
  p_threshold_name TEXT,
  p_step NUMERIC DEFAULT 0.02
)
RETURNS TEXT AS $$
DECLARE
  v_current NUMERIC;
  v_new NUMERIC;
  v_fraud NUMERIC;
  v_latency NUMERIC;
  v_drift NUMERIC;
  v_reason TEXT := 'NO_CHANGE';
BEGIN
  SELECT value INTO v_current
  FROM risk_thresholds
  WHERE threshold_name = p_threshold_name
  ORDER BY version DESC
  LIMIT 1;

  SELECT AVG(chargeback_rate) INTO v_fraud FROM chargeback_rate_metrics;
  SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY latency_ms) INTO v_latency FROM decision_latency_metrics;
  SELECT AVG(drift_score) INTO v_drift FROM model_drift_metrics WHERE breach = TRUE;

  v_new := v_current;
  IF COALESCE(v_fraud,0) > 0.015 OR COALESCE(v_drift,0) > 0.25 THEN
    v_new := v_current * (1 - p_step);
    v_reason := 'RISK_UP_FRAUD_OR_DRIFT';
  ELSIF COALESCE(v_latency,0) > 300 THEN
    v_new := v_current * (1 + p_step);
    v_reason := 'LATENCY_PRESSURE';
  END IF;

  IF v_new <> v_current THEN
    INSERT INTO risk_thresholds (threshold_name, version, value, effective_from)
    SELECT p_threshold_name, COALESCE(MAX(version),0)+1, v_new, NOW()
    FROM risk_thresholds
    WHERE threshold_name = p_threshold_name;

    INSERT INTO threshold_adjustment_log(threshold_name, old_value, new_value, reason)
    VALUES (p_threshold_name, v_current, v_new, v_reason);
  END IF;

  RETURN v_reason;
END;
$$ LANGUAGE plpgsql;
