-- 12-month risk capital forecast using seasonality and growth assumptions

CREATE TABLE IF NOT EXISTS forecast_assumptions (
  assumption_id BIGSERIAL PRIMARY KEY,
  growth_rate_monthly NUMERIC(10,6) NOT NULL DEFAULT 0.02,
  seasonality_factor NUMERIC(10,6) NOT NULL DEFAULT 1.00,
  capital_ratio NUMERIC(10,6) NOT NULL DEFAULT 0.05,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE VIEW risk_capital_forecast_12m AS
WITH base AS (
  SELECT DATE_TRUNC('month', created_at)::DATE AS month_bucket,
         SUM(amount) AS volume
  FROM transactions
  WHERE created_at >= NOW() - INTERVAL '12 months'
  GROUP BY DATE_TRUNC('month', created_at)
), last_month AS (
  SELECT COALESCE(MAX(month_bucket), DATE_TRUNC('month', NOW())::DATE) AS m,
         COALESCE((SELECT volume FROM base ORDER BY month_bucket DESC LIMIT 1), 0) AS v
  FROM base
), params AS (
  SELECT growth_rate_monthly, seasonality_factor, capital_ratio
  FROM forecast_assumptions
  ORDER BY assumption_id DESC
  LIMIT 1
), horizon AS (
  SELECT generate_series(1,12) AS step
)
SELECT
  (lm.m + (h.step || ' month')::INTERVAL)::DATE AS forecast_month,
  ROUND((lm.v * POWER(1 + p.growth_rate_monthly, h.step) * p.seasonality_factor), 2) AS projected_volume,
  ROUND((lm.v * POWER(1 + p.growth_rate_monthly, h.step) * p.seasonality_factor * p.capital_ratio), 2) AS projected_capital_required
FROM last_month lm
CROSS JOIN params p
CROSS JOIN horizon h
ORDER BY forecast_month;
