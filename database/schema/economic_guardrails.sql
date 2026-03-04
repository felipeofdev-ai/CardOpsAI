-- Guardrails to prevent economically-optimal but operationally-dangerous policies

CREATE TABLE IF NOT EXISTS economic_guardrails (
  guardrail_id BIGSERIAL PRIMARY KEY,
  policy_name TEXT NOT NULL,
  min_approval_rate NUMERIC(10,6),
  max_chargeback_rate NUMERIC(10,6),
  max_capital_usage NUMERIC(18,2),
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (policy_name)
);

CREATE OR REPLACE VIEW guardrail_violations AS
SELECT
  o.objective_name,
  g.policy_name,
  m.approval_rate,
  c.chargeback_rate,
  r.capital_reserve_required,
  (g.min_approval_rate IS NOT NULL AND m.approval_rate < g.min_approval_rate) AS approval_violation,
  (g.max_chargeback_rate IS NOT NULL AND c.chargeback_rate > g.max_chargeback_rate) AS chargeback_violation,
  (g.max_capital_usage IS NOT NULL AND r.capital_reserve_required > g.max_capital_usage) AS capital_violation
FROM economic_objectives o
JOIN economic_guardrails g ON g.policy_name = o.objective_name AND g.active = TRUE
LEFT JOIN (
  SELECT tenant_id, AVG(approval_rate) AS approval_rate
  FROM approval_rate_metrics
  GROUP BY tenant_id
) m ON TRUE
LEFT JOIN (
  SELECT tenant_id, AVG(chargeback_rate) AS chargeback_rate
  FROM chargeback_rate_metrics
  GROUP BY tenant_id
) c ON TRUE
LEFT JOIN (
  SELECT merchant_id, SUM(amount) * 0.05 AS capital_reserve_required
  FROM transactions
  GROUP BY merchant_id
) r ON TRUE;
