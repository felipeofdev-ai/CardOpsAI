-- Temporal fraud pattern views

CREATE OR REPLACE VIEW time_of_day_risk AS
SELECT
  EXTRACT(HOUR FROM created_at)::INT AS hour_of_day,
  COUNT(*) AS total_tx,
  COUNT(*) FILTER (WHERE status = 'CHARGEBACK') AS chargebacks,
  ROUND(COUNT(*) FILTER (WHERE status = 'CHARGEBACK')::NUMERIC / NULLIF(COUNT(*),0), 6) AS chargeback_rate
FROM transactions
GROUP BY EXTRACT(HOUR FROM created_at)
ORDER BY hour_of_day;

CREATE OR REPLACE VIEW day_of_week_risk AS
SELECT
  EXTRACT(DOW FROM created_at)::INT AS day_of_week,
  COUNT(*) AS total_tx,
  COUNT(*) FILTER (WHERE status = 'CHARGEBACK') AS chargebacks,
  ROUND(COUNT(*) FILTER (WHERE status = 'CHARGEBACK')::NUMERIC / NULLIF(COUNT(*),0), 6) AS chargeback_rate
FROM transactions
GROUP BY EXTRACT(DOW FROM created_at)
ORDER BY day_of_week;

CREATE OR REPLACE VIEW seasonality_risk AS
SELECT
  DATE_TRUNC('month', created_at)::DATE AS month_bucket,
  COUNT(*) AS total_tx,
  COUNT(*) FILTER (WHERE status = 'CHARGEBACK') AS chargebacks,
  ROUND(COUNT(*) FILTER (WHERE status = 'CHARGEBACK')::NUMERIC / NULLIF(COUNT(*),0), 6) AS chargeback_rate,
  LAG(COUNT(*) FILTER (WHERE status = 'CHARGEBACK')) OVER (ORDER BY DATE_TRUNC('month', created_at)) AS prev_chargebacks
FROM transactions
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month_bucket;
