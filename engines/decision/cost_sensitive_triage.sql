-- Cost-sensitive alert triage with daily investigator budget

CREATE OR REPLACE FUNCTION consume_alert_budget(
  p_tenant_id BIGINT,
  p_transaction_id BIGINT,
  p_expected_loss NUMERIC
) RETURNS BOOLEAN AS $$
DECLARE
  v_budget INT;
  v_used INT;
BEGIN
  INSERT INTO alert_budget_config (tenant_id)
  VALUES (p_tenant_id)
  ON CONFLICT (tenant_id) DO NOTHING;

  SELECT daily_alert_budget INTO v_budget
  FROM alert_budget_config WHERE tenant_id = p_tenant_id;

  INSERT INTO alert_budget_usage (tenant_id, usage_date, alerts_consumed, expected_loss_total)
  VALUES (p_tenant_id, cardops_now()::date, 0, 0)
  ON CONFLICT (tenant_id, usage_date) DO NOTHING;

  SELECT alerts_consumed INTO v_used
  FROM alert_budget_usage
  WHERE tenant_id = p_tenant_id AND usage_date = cardops_now()::date
  FOR UPDATE;

  IF v_used >= v_budget THEN
    RETURN FALSE;
  END IF;

  UPDATE alert_budget_usage
     SET alerts_consumed = alerts_consumed + 1,
         expected_loss_total = expected_loss_total + COALESCE(p_expected_loss, 0)
   WHERE tenant_id = p_tenant_id AND usage_date = cardops_now()::date;

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION triage_within_budget(
  p_tenant_id BIGINT,
  p_limit INT DEFAULT NULL
)
RETURNS TABLE (
  transaction_id BIGINT,
  merchant_id BIGINT,
  amount NUMERIC,
  risk_score NUMERIC,
  expected_loss NUMERIC,
  priority_band TEXT,
  budget_slot INT
) AS $$
DECLARE
  v_budget INT;
  v_row RECORD;
  v_slot INT := 0;
BEGIN
  INSERT INTO alert_budget_config (tenant_id) VALUES (p_tenant_id)
  ON CONFLICT DO NOTHING;

  SELECT daily_alert_budget INTO v_budget
  FROM alert_budget_config WHERE tenant_id = p_tenant_id;

  FOR v_row IN
    SELECT a.*
    FROM alert_triage_queue a
    WHERE a.tenant_id = p_tenant_id
    ORDER BY a.expected_loss DESC NULLS LAST, a.created_at DESC
    LIMIT COALESCE(p_limit, v_budget)
  LOOP
    EXIT WHEN v_slot >= v_budget;
    IF consume_alert_budget(p_tenant_id, v_row.transaction_id, v_row.expected_loss) THEN
      v_slot := v_slot + 1;
      transaction_id := v_row.transaction_id;
      merchant_id := v_row.merchant_id;
      amount := v_row.amount;
      risk_score := v_row.risk_score;
      expected_loss := v_row.expected_loss;
      priority_band := v_row.priority_band;
      budget_slot := v_slot;
      RETURN NEXT;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW alert_budget_status AS
SELECT
  c.tenant_id,
  c.daily_alert_budget,
  COALESCE(u.alerts_consumed, 0) AS alerts_consumed_today,
  c.daily_alert_budget - COALESCE(u.alerts_consumed, 0) AS remaining_budget,
  COALESCE(u.expected_loss_total, 0) AS expected_loss_triaged_today
FROM alert_budget_config c
LEFT JOIN alert_budget_usage u
  ON u.tenant_id = c.tenant_id AND u.usage_date = cardops_now()::date;

COMMENT ON FUNCTION triage_within_budget IS 'Rank alerts by expected loss under daily investigator capacity';
