-- Drift detection and alerting primitives

CREATE OR REPLACE FUNCTION record_model_drift(
  p_model_version_id BIGINT,
  p_metric_name TEXT,
  p_baseline NUMERIC,
  p_current NUMERIC,
  p_threshold NUMERIC
)
RETURNS BIGINT AS $$
DECLARE
  v_score NUMERIC;
  v_id BIGINT;
BEGIN
  v_score := ABS(p_current - p_baseline) / NULLIF(ABS(p_baseline), 0);

  INSERT INTO model_drift_metrics (
    model_version_id, metric_name, baseline_value, current_value, drift_score, threshold
  ) VALUES (
    p_model_version_id, p_metric_name, p_baseline, p_current, COALESCE(v_score, 0), p_threshold
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql;

CREATE VIEW drift_breaches AS
SELECT *
FROM model_drift_metrics
WHERE breach = TRUE
ORDER BY recorded_at DESC;
