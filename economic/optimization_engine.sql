-- Economic objective optimizer for decision policy tuning

CREATE TABLE IF NOT EXISTS decision_candidates (
  id BIGSERIAL PRIMARY KEY,
  merchant_id BIGINT NOT NULL,
  scenario_id TEXT NOT NULL,
  expected_revenue NUMERIC(16,2) NOT NULL,
  expected_fraud_loss NUMERIC(16,2) NOT NULL,
  expected_capital_cost NUMERIC(16,2) NOT NULL,
  expected_churn_cost NUMERIC(16,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE VIEW decision_profit_scores AS
SELECT
  c.id,
  c.merchant_id,
  c.scenario_id,
  e.objective_name,
  (
    (c.expected_revenue * e.revenue_weight)
    - (c.expected_fraud_loss * e.fraud_weight)
    - (c.expected_capital_cost * e.capital_weight)
    - (c.expected_churn_cost * e.churn_weight)
  ) AS profit_score
FROM decision_candidates c
CROSS JOIN economic_objectives e
WHERE e.active = TRUE;

CREATE OR REPLACE VIEW best_decision_candidate AS
SELECT DISTINCT ON (merchant_id, scenario_id)
  merchant_id,
  scenario_id,
  id AS candidate_id,
  objective_name,
  profit_score
FROM decision_profit_scores
ORDER BY merchant_id, scenario_id, profit_score DESC;
