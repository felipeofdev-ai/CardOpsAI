-- ML challenger lane: statistical anomaly (Isolation Forest-inspired z-score composite)
-- Pure SQL — no external model server required for demo/prod baseline

CREATE OR REPLACE FUNCTION compute_ml_anomaly_score(p_transaction_id BIGINT)
RETURNS NUMERIC AS $$
DECLARE
  v_txn RECORD;
  v_merchant_avg NUMERIC;
  v_merchant_std NUMERIC;
  v_z_amount NUMERIC;
  v_z_vel NUMERIC;
  v_vel RECORD;
  v_score NUMERIC;
BEGIN
  SELECT * INTO v_txn FROM transactions WHERE id = p_transaction_id;
  IF NOT FOUND THEN RETURN 0; END IF;

  SELECT AVG(amount), NULLIF(STDDEV_POP(amount), 0)
  INTO v_merchant_avg, v_merchant_std
  FROM transactions
  WHERE merchant_id = v_txn.merchant_id AND tenant_id = v_txn.tenant_id;

  v_z_amount := CASE
    WHEN v_merchant_std IS NULL OR v_merchant_std = 0 THEN 0
    ELSE ABS(v_txn.amount - COALESCE(v_merchant_avg, v_txn.amount)) / v_merchant_std
  END;

  SELECT * INTO v_vel FROM velocity_features
  WHERE tenant_id = v_txn.tenant_id
    AND entity_type = 'merchant'
    AND entity_id = v_txn.merchant_id::text;

  v_z_vel := COALESCE(v_vel.tx_count_1h, 0) / 10.0;

  -- Composite anomaly 0-100 (higher = more anomalous)
  v_score := LEAST(100, round((v_z_amount * 25 + v_z_vel * 35 + COALESCE(v_vel.amount_spike_ratio, 0) * 10), 4));
  RETURN v_score;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION compute_hybrid_score(p_transaction_id BIGINT)
RETURNS JSONB AS $$
DECLARE
  v_rules NUMERIC;
  v_ml NUMERIC;
  v_hybrid NUMERIC;
  v_explain JSONB;
BEGIN
  v_rules := compute_risk_score(p_transaction_id);
  v_ml := compute_ml_anomaly_score(p_transaction_id);
  v_hybrid := round(v_rules * 0.65 + v_ml * 0.35, 4);
  v_explain := explain_transaction_risk(p_transaction_id);
  RETURN v_explain || jsonb_build_object(
    'rule_score', v_rules,
    'ml_anomaly_score', v_ml,
    'hybrid_score', v_hybrid,
    'model_lane', 'rules+statistical_challenger'
  );
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION compute_ml_anomaly_score IS 'SQL statistical anomaly challenger (z-score + velocity)';
COMMENT ON FUNCTION compute_hybrid_score IS 'Blended rules + ML challenger score with explainability';
