-- Expected-loss triage + explainable scoring + adverse action codes
-- Patterns from capacity-aware fraud ops: rank by P(fraud)*amount, not raw score.

CREATE TABLE IF NOT EXISTS adverse_action_codes (
  code TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  regulatory_ref TEXT DEFAULT 'ECOA/FCRA-style adverse action'
);

INSERT INTO adverse_action_codes (code, title, description) VALUES
  ('AA-VEL', 'Unusual velocity', 'Transaction velocity exceeded historical pattern for the payment instrument or merchant.'),
  ('AA-AMT', 'Amount anomaly', 'Transaction amount materially exceeded typical ticket size.'),
  ('AA-NET', 'Network risk', 'Merchant appears in elevated-risk linkage cluster.'),
  ('AA-GEO', 'Impossible travel / geo anomaly', 'Geolocation pattern inconsistent with recent activity.'),
  ('AA-RULE', 'Policy rule breach', 'One or more active risk policies fired above threshold.'),
  ('AA-ML', 'Model risk band', 'Composite risk score entered decline band under current policy.')
ON CONFLICT (code) DO NOTHING;

CREATE OR REPLACE FUNCTION explain_transaction_risk(p_transaction_id BIGINT)
RETURNS JSONB AS $$
DECLARE
  v_txn RECORD;
  v_score NUMERIC;
  v_factors JSONB := '[]'::jsonb;
  v_rule RECORD;
  v_fired BOOLEAN;
  v_merchant_risk NUMERIC := 0;
  v_vel RECORD;
  v_weight NUMERIC;
  v_contrib NUMERIC;
  v_codes TEXT[] := ARRAY[]::TEXT[];
  v_action TEXT;
  v_threshold NUMERIC;
BEGIN
  SELECT * INTO v_txn FROM transactions WHERE id = p_transaction_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'transaction % not found', p_transaction_id;
  END IF;

  SELECT COALESCE(MAX(risk_score), 0) INTO v_merchant_risk
  FROM merchants WHERE id = v_txn.merchant_id;

  SELECT * INTO v_vel
  FROM velocity_features
  WHERE tenant_id = v_txn.tenant_id
    AND entity_type = 'merchant'
    AND entity_id = v_txn.merchant_id::text;

  SELECT COALESCE(AVG(COALESCE(threshold, 50)), 50) INTO v_threshold
  FROM risk_rules WHERE COALESCE(is_active, active, TRUE);

  v_score := compute_risk_score(p_transaction_id);

  FOR v_rule IN
    SELECT * FROM risk_rules
     WHERE COALESCE(is_active, active, TRUE)
       AND (tenant_id IS NULL OR tenant_id = v_txn.tenant_id)
     ORDER BY id
  LOOP
    v_fired := evaluate_rule_expression(
      COALESCE(v_rule.rule_expression, v_rule.sql_condition),
      v_txn.amount,
      v_txn.status,
      v_merchant_risk
    );
    v_weight := COALESCE(v_rule.risk_weight, 1);
    v_contrib := CASE WHEN v_fired THEN v_weight ELSE 0 END;
    v_factors := v_factors || jsonb_build_array(jsonb_build_object(
      'factor', COALESCE(v_rule.rule_name, v_rule.rule_expression),
      'fired', v_fired,
      'weight', v_weight,
      'contribution', v_contrib
    ));
    IF v_fired AND v_rule.rule_expression IN ('high_amount', 'amount_over_threshold', 'decline_band') THEN
      v_codes := array_append(v_codes, 'AA-AMT');
    ELSIF v_fired AND v_rule.rule_expression IN ('merchant_elevated', 'feature_spike') THEN
      v_codes := array_append(v_codes, 'AA-NET');
    ELSIF v_fired THEN
      v_codes := array_append(v_codes, 'AA-RULE');
    END IF;
  END LOOP;

  IF v_vel.tx_count_1h IS NOT NULL AND v_vel.tx_count_1h >= 8 THEN
    v_factors := v_factors || jsonb_build_array(jsonb_build_object(
      'factor', 'velocity_1h', 'fired', true, 'weight', 1.5,
      'contribution', 1.5, 'value', v_vel.tx_count_1h
    ));
    v_codes := array_append(v_codes, 'AA-VEL');
  END IF;

  IF v_score < v_threshold THEN
    v_action := 'APPROVE';
  ELSIF v_score > (v_threshold * 2) THEN
    v_action := 'BLOCK';
    v_codes := array_append(v_codes, 'AA-ML');
  ELSE
    v_action := 'REVIEW';
  END IF;

  -- Deduplicate codes
  SELECT array_agg(DISTINCT c) INTO v_codes FROM unnest(v_codes) AS c;

  RETURN jsonb_build_object(
    'transaction_id', p_transaction_id,
    'score', v_score,
    'threshold', v_threshold,
    'action', v_action,
    'expected_loss', round((v_score / 100.0) * v_txn.amount, 4),
    'factors', v_factors,
    'adverse_action_codes', COALESCE(to_jsonb(v_codes), '[]'::jsonb),
    'scored_at', cardops_now()
  );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION score_transaction(p_transaction_id BIGINT)
RETURNS JSONB AS $$
DECLARE
  v_result JSONB;
  v_decision_id BIGINT;
  v_factor JSONB;
BEGIN
  v_result := explain_transaction_risk(p_transaction_id);

  UPDATE transactions
     SET risk_score = (v_result->>'score')::numeric,
         decision = lower(v_result->>'action'),
         decision_reason = v_result,
         updated_at = cardops_now()
   WHERE id = p_transaction_id;

  -- Persist factor-level explainability when a decision row exists for this tx
  SELECT id INTO v_decision_id
  FROM decision_audit_log
  WHERE transaction_id = p_transaction_id
  ORDER BY id DESC
  LIMIT 1;

  IF v_decision_id IS NOT NULL THEN
    DELETE FROM decision_explanations WHERE decision_id = v_decision_id;
    FOR v_factor IN SELECT * FROM jsonb_array_elements(v_result->'factors')
    LOOP
      INSERT INTO decision_explanations (decision_id, factor, feature_value, weight, contribution)
      VALUES (
        v_decision_id,
        v_factor->>'factor',
        NULLIF(v_factor->>'value', '')::numeric,
        COALESCE((v_factor->>'weight')::numeric, 0),
        COALESCE((v_factor->>'contribution')::numeric, 0)
      );
    END LOOP;
  END IF;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Investigation triage ordered by expected loss (capacity-aware ops)
CREATE OR REPLACE VIEW alert_triage_queue AS
SELECT
  t.id AS transaction_id,
  t.tenant_id,
  t.merchant_id,
  t.amount,
  t.risk_score,
  t.decision,
  t.status,
  round((COALESCE(t.risk_score, 0) / 100.0) * t.amount, 4) AS expected_loss,
  t.created_at,
  CASE
    WHEN COALESCE(t.risk_score, 0) >= 80 OR upper(t.status) IN ('DECLINED', 'CHARGEBACK') THEN 'P1'
    WHEN COALESCE(t.risk_score, 0) >= 50 THEN 'P2'
    ELSE 'P3'
  END AS priority_band
FROM transactions t
WHERE COALESCE(t.decision, '') IN ('review', 'block', 'declined')
   OR upper(t.status) IN ('DECLINED', 'CHARGEBACK')
   OR COALESCE(t.risk_score, 0) >= 50
ORDER BY expected_loss DESC NULLS LAST, t.created_at DESC;

CREATE OR REPLACE FUNCTION top_alerts_by_expected_loss(
  p_tenant_id BIGINT,
  p_limit INT DEFAULT 100
)
RETURNS TABLE (
  transaction_id BIGINT,
  merchant_id BIGINT,
  amount NUMERIC,
  risk_score NUMERIC,
  expected_loss NUMERIC,
  priority_band TEXT
) AS $$
  SELECT
    a.transaction_id,
    a.merchant_id,
    a.amount,
    a.risk_score,
    a.expected_loss,
    a.priority_band
  FROM alert_triage_queue a
  WHERE a.tenant_id = p_tenant_id
  ORDER BY a.expected_loss DESC
  LIMIT GREATEST(p_limit, 1);
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION explain_transaction_risk IS 'Return score, factors, adverse-action codes, expected loss';
COMMENT ON FUNCTION score_transaction IS 'Score + persist decision_reason and explanation factors';
COMMENT ON VIEW alert_triage_queue IS 'Capacity-aware alert ranking by expected loss';
