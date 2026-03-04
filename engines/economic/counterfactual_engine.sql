-- Counterfactual laboratory: compare historical outcomes for multiple policies

CREATE TABLE IF NOT EXISTS counterfactual_runs (
  run_id BIGSERIAL PRIMARY KEY,
  policy_name TEXT NOT NULL,
  threshold_value NUMERIC NOT NULL,
  from_ts TIMESTAMPTZ NOT NULL,
  to_ts TIMESTAMPTZ NOT NULL,
  approval_rate NUMERIC,
  estimated_fraud_rate NUMERIC,
  estimated_profit NUMERIC,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION run_counterfactual(
  p_policy_name TEXT,
  p_threshold NUMERIC,
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ
)
RETURNS BIGINT AS $$
DECLARE
  v_run BIGINT;
  v_approval NUMERIC;
  v_review NUMERIC;
  v_block NUMERIC;
  v_fraud NUMERIC;
  v_profit NUMERIC;
BEGIN
  SELECT approval_rate, review_rate, block_rate, estimated_fraud_rate, estimated_profit
  INTO v_approval, v_review, v_block, v_fraud, v_profit
  FROM simulate_policy(p_threshold, p_from, p_to);

  INSERT INTO counterfactual_runs(policy_name, threshold_value, from_ts, to_ts, approval_rate, estimated_fraud_rate, estimated_profit)
  VALUES (p_policy_name, p_threshold, p_from, p_to, v_approval, v_fraud, v_profit)
  RETURNING run_id INTO v_run;

  RETURN v_run;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW counterfactual_ranking AS
SELECT policy_name,
       AVG(estimated_profit) AS avg_profit,
       AVG(approval_rate) AS avg_approval,
       AVG(estimated_fraud_rate) AS avg_fraud,
       COUNT(*) AS runs
FROM counterfactual_runs
GROUP BY policy_name
ORDER BY avg_profit DESC;
