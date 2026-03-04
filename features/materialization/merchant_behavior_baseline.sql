-- Merchant behavioral baseline and anomaly context

CREATE MATERIALIZED VIEW IF NOT EXISTS merchant_behavior_baseline AS
SELECT
  merchant_id,
  AVG(amount) AS avg_ticket,
  STDDEV(amount) AS ticket_stddev,
  COUNT(*) AS tx_count,
  COUNT(DISTINCT geolocation) AS geo_distribution,
  COUNT(DISTINCT device_id) AS device_distribution,
  MIN(created_at) AS first_seen,
  MAX(created_at) AS last_seen
FROM transactions
GROUP BY merchant_id;
