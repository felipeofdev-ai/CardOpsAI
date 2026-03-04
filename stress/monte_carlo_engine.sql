-- Liquidity shock + revenue-at-risk simulation engine

CREATE TABLE IF NOT EXISTS liquidity_scenarios (
  id BIGSERIAL PRIMARY KEY,
  scenario_name TEXT NOT NULL UNIQUE,
  chargeback_shock_pct NUMERIC(8,4) NOT NULL,
  approval_drop_pct NUMERIC(8,4) NOT NULL,
  merchant_block_rate_pct NUMERIC(8,4) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE VIEW revenue_at_risk AS
SELECT
  merchant_id,
  SUM(amount) FILTER (WHERE status = 'APPROVED') AS approved_volume,
  (SUM(amount) FILTER (WHERE status = 'APPROVED')
    * (COUNT(*) FILTER (WHERE status = 'CHARGEBACK')::NUMERIC / NULLIF(COUNT(*),0))) AS revenue_at_risk
FROM transactions
GROUP BY merchant_id;

CREATE OR REPLACE VIEW liquidity_shock_projection AS
SELECT
  r.merchant_id,
  l.scenario_name,
  r.approved_volume,
  r.revenue_at_risk,
  ROUND(r.revenue_at_risk * (1 + l.chargeback_shock_pct), 2) AS stressed_revenue_at_risk,
  ROUND(r.approved_volume * l.approval_drop_pct, 2) AS projected_volume_loss
FROM revenue_at_risk r
CROSS JOIN liquidity_scenarios l;
