-- Scenario backtesting + policy simulation

CREATE OR REPLACE FUNCTION simulate_policy(
  p_threshold_value NUMERIC,
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ
)
RETURNS TABLE(
  approval_rate NUMERIC,
  review_rate NUMERIC,
  block_rate NUMERIC,
  estimated_fraud_rate NUMERIC,
  estimated_profit NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  WITH base AS (
    SELECT
      t.id,
      t.amount,
      CASE
        WHEN t.amount >= p_threshold_value THEN 'BLOCK'
        WHEN t.amount >= (p_threshold_value * 0.7) THEN 'REVIEW'
        ELSE 'APPROVE'
      END AS simulated_action
    FROM transactions t
    WHERE t.created_at BETWEEN p_from AND p_to
  )
  SELECT
    ROUND(COUNT(*) FILTER (WHERE simulated_action='APPROVE')::NUMERIC / NULLIF(COUNT(*),0), 6),
    ROUND(COUNT(*) FILTER (WHERE simulated_action='REVIEW')::NUMERIC / NULLIF(COUNT(*),0), 6),
    ROUND(COUNT(*) FILTER (WHERE simulated_action='BLOCK')::NUMERIC / NULLIF(COUNT(*),0), 6),
    ROUND(COUNT(*) FILTER (WHERE simulated_action='APPROVE' AND amount > p_threshold_value*1.2)::NUMERIC / NULLIF(COUNT(*),0), 6),
    ROUND(
      SUM(CASE WHEN simulated_action='APPROVE' THEN amount ELSE 0 END)
      - SUM(CASE WHEN simulated_action='APPROVE' AND amount > p_threshold_value*1.2 THEN amount*0.015 ELSE 0 END)
    , 2)
  FROM base;
END;
$$ LANGUAGE plpgsql;
