-- Risk scoring pipeline stages (feature extraction -> scoring -> policy)

CREATE OR REPLACE VIEW v_feature_extraction AS
SELECT
  t.id AS tx_id,
  t.merchant_id,
  t.amount,
  t.status,
  t.created_at,
  AVG(t.amount) OVER (
    PARTITION BY t.merchant_id
    ORDER BY t.created_at
    ROWS BETWEEN 50 PRECEDING AND CURRENT ROW
  ) AS rolling_avg_ticket,
  COUNT(*) FILTER (WHERE t.status = 'DECLINED') OVER (
    PARTITION BY t.merchant_id
    ORDER BY t.created_at
    RANGE BETWEEN INTERVAL '24 hours' PRECEDING AND CURRENT ROW
  ) AS declines_24h
FROM transactions t;

CREATE OR REPLACE VIEW v_risk_scoring AS
SELECT
  tx_id,
  merchant_id,
  amount,
  ((COALESCE(declines_24h,0) * 2) + (amount / NULLIF(rolling_avg_ticket,0)))::NUMERIC(12,4) AS risk_score
FROM v_feature_extraction;

CREATE OR REPLACE VIEW v_decision_policy AS
WITH active_threshold AS (
  SELECT value
  FROM risk_thresholds
  WHERE threshold_name = 'tx_risk_threshold'
    AND NOW() >= effective_from
    AND (effective_to IS NULL OR NOW() < effective_to)
  ORDER BY version DESC
  LIMIT 1
)
SELECT
  s.tx_id,
  s.merchant_id,
  s.risk_score,
  CASE
    WHEN s.risk_score >= at.value THEN 'BLOCK'
    WHEN s.risk_score >= (at.value * 0.7) THEN 'REVIEW'
    ELSE 'APPROVE'
  END AS policy_action
FROM v_risk_scoring s
CROSS JOIN active_threshold at;
