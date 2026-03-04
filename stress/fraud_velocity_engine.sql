-- Fraud velocity engine using window functions

CREATE OR REPLACE VIEW fraud_velocity_signals AS
WITH tx AS (
  SELECT
    merchant_id,
    geolocation,
    created_at,
    amount,
    status,
    DATE_TRUNC('minute', created_at) AS minute_bucket
  FROM transactions
  WHERE created_at >= NOW() - INTERVAL '24 hours'
)
SELECT
  merchant_id,
  minute_bucket,
  COUNT(*) AS tx_per_minute,
  AVG(amount) AS avg_ticket,
  COUNT(*) FILTER (WHERE status = 'DECLINED') AS declines,
  COUNT(DISTINCT geolocation) AS geo_spread,
  AVG(COUNT(*)) OVER (
    PARTITION BY merchant_id
    ORDER BY minute_bucket
    ROWS BETWEEN 60 PRECEDING AND 1 PRECEDING
  ) AS baseline_tpm_60m,
  CASE
    WHEN AVG(COUNT(*)) OVER (
      PARTITION BY merchant_id
      ORDER BY minute_bucket
      ROWS BETWEEN 60 PRECEDING AND 1 PRECEDING
    ) IS NULL THEN NULL
    ELSE COUNT(*) / NULLIF(
      AVG(COUNT(*)) OVER (
        PARTITION BY merchant_id
        ORDER BY minute_bucket
        ROWS BETWEEN 60 PRECEDING AND 1 PRECEDING
      ), 0)
  END AS velocity_ratio
FROM tx
GROUP BY merchant_id, minute_bucket;
