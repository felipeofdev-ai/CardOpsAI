-- Continuous statistical validation: PSI, KS and ROC recalculation helpers

CREATE TABLE IF NOT EXISTS statistical_validation_runs (
  run_id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT,
  metric_name TEXT NOT NULL,
  score NUMERIC(18,6) NOT NULL,
  details JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION compute_psi(
  p_expected FLOAT8[],
  p_actual FLOAT8[]
)
RETURNS NUMERIC AS $$
DECLARE
  i INT;
  v_psi NUMERIC := 0;
BEGIN
  IF array_length(p_expected,1) IS DISTINCT FROM array_length(p_actual,1) THEN
    RAISE EXCEPTION 'PSI arrays must have same length';
  END IF;
  FOR i IN 1..array_length(p_expected,1) LOOP
    v_psi := v_psi + ((p_actual[i]-p_expected[i]) * LN((p_actual[i]+1e-9)/(p_expected[i]+1e-9)));
  END LOOP;
  RETURN ROUND(v_psi, 6);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION compute_ks_from_scores(
  p_threshold NUMERIC DEFAULT 0.5
)
RETURNS NUMERIC AS $$
DECLARE
  v_good_cdf NUMERIC;
  v_bad_cdf NUMERIC;
BEGIN
  SELECT
    COUNT(*) FILTER (WHERE decision_score <= p_threshold AND outcome='GOOD')::NUMERIC / NULLIF(COUNT(*) FILTER (WHERE outcome='GOOD'),0),
    COUNT(*) FILTER (WHERE decision_score <= p_threshold AND outcome='BAD')::NUMERIC / NULLIF(COUNT(*) FILTER (WHERE outcome='BAD'),0)
  INTO v_good_cdf, v_bad_cdf
  FROM decision_audit_log
  WHERE outcome IN ('GOOD','BAD');

  RETURN ROUND(ABS(COALESCE(v_good_cdf,0)-COALESCE(v_bad_cdf,0)), 6);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW roc_recalculation AS
SELECT
  threshold,
  tpr,
  fpr,
  (tpr - fpr) AS ks_proxy
FROM (
  SELECT
    gs.threshold,
    COUNT(*) FILTER (WHERE decision_score >= gs.threshold AND outcome='BAD')::NUMERIC / NULLIF(COUNT(*) FILTER (WHERE outcome='BAD'),0) AS tpr,
    COUNT(*) FILTER (WHERE decision_score >= gs.threshold AND outcome='GOOD')::NUMERIC / NULLIF(COUNT(*) FILTER (WHERE outcome='GOOD'),0) AS fpr
  FROM generate_series(0.05, 0.95, 0.05) AS gs(threshold)
  CROSS JOIN decision_audit_log
  WHERE outcome IN ('GOOD','BAD')
  GROUP BY gs.threshold
) q
ORDER BY threshold;
