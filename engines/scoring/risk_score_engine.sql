-- Operational risk score engine (named expressions — no dynamic SQL)

CREATE OR REPLACE FUNCTION evaluate_rule_expression(
  p_expression TEXT,
  p_amount NUMERIC,
  p_status TEXT,
  p_merchant_risk NUMERIC DEFAULT 0
) RETURNS BOOLEAN AS $$
BEGIN
  RETURN CASE lower(COALESCE(p_expression, ''))
    WHEN 'high_amount' THEN p_amount >= 1000
    WHEN 'amount_over_threshold' THEN p_amount >= 1000
    WHEN 'risky_status' THEN upper(p_status) IN ('DECLINED', 'CHARGEBACK')
    WHEN 'merchant_elevated' THEN COALESCE(p_merchant_risk, 0) >= 60
    WHEN 'decline_band' THEN p_amount >= 2000
    WHEN 'review_band' THEN p_amount >= 400 AND p_amount < 1000
    WHEN 'feature_spike' THEN COALESCE(p_merchant_risk, 0) >= 75 AND p_amount >= 500
    ELSE (
      -- Fallback: treat sql_condition-like tokens heuristically
      (p_expression ILIKE '%amount%' AND p_amount >= 1000)
      OR (p_expression ILIKE '%decline%' AND upper(p_status) = 'DECLINED')
    )
  END;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION compute_risk_score(p_transaction_id BIGINT)
RETURNS NUMERIC AS $$
DECLARE
  v_txn RECORD;
  v_weight_sum NUMERIC := 0;
  v_fired_sum NUMERIC := 0;
  v_rule RECORD;
  v_fired BOOLEAN;
  v_merchant_risk NUMERIC := 0;
BEGIN
  SELECT * INTO v_txn FROM transactions WHERE id = p_transaction_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'transaction % not found', p_transaction_id;
  END IF;

  SELECT COALESCE(MAX(risk_score), 0) INTO v_merchant_risk
  FROM merchants
  WHERE id = v_txn.merchant_id;

  FOR v_rule IN
    SELECT *
      FROM risk_rules
     WHERE COALESCE(is_active, active, TRUE) = TRUE
       AND (tenant_id IS NULL OR tenant_id = v_txn.tenant_id)
     ORDER BY id
  LOOP
    v_fired := evaluate_rule_expression(
      COALESCE(v_rule.rule_expression, v_rule.sql_condition),
      v_txn.amount,
      v_txn.status,
      v_merchant_risk
    );
    v_weight_sum := v_weight_sum + COALESCE(v_rule.risk_weight, 1);
    IF v_fired THEN
      v_fired_sum := v_fired_sum + COALESCE(v_rule.risk_weight, 1);
    END IF;
  END LOOP;

  IF v_weight_sum <= 0 THEN
    RETURN 0;
  END IF;

  RETURN GREATEST(0, LEAST(100, round((v_fired_sum / v_weight_sum) * 100.0, 4)));
END;
$$ LANGUAGE plpgsql STABLE;
