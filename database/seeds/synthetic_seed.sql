-- Synthetic demo seed for CardOpsAI (idempotent by tenant name)

DO $$
DECLARE
  v_tid BIGINT;
  v_mids BIGINT[] := ARRAY[]::BIGINT[];
  v_cids UUID[] := ARRAY[]::UUID[];
  v_mid BIGINT;
  v_cid UUID;
  v_txn BIGINT;
  v_i INT;
  v_j INT;
  v_payload JSONB;
  v_action TEXT;
  v_score NUMERIC;
BEGIN
  ALTER TABLE IF EXISTS tenants DISABLE ROW LEVEL SECURITY;
  ALTER TABLE IF EXISTS merchants DISABLE ROW LEVEL SECURITY;
  ALTER TABLE IF EXISTS cards DISABLE ROW LEVEL SECURITY;
  ALTER TABLE IF EXISTS transactions DISABLE ROW LEVEL SECURITY;
  ALTER TABLE IF EXISTS decision_queue DISABLE ROW LEVEL SECURITY;
  ALTER TABLE IF EXISTS decision_audit_log DISABLE ROW LEVEL SECURITY;
  ALTER TABLE IF EXISTS merchant_risk_graph DISABLE ROW LEVEL SECURITY;
  ALTER TABLE IF EXISTS event_inbox DISABLE ROW LEVEL SECURITY;

  DELETE FROM decision_audit_log WHERE tenant_id IN (SELECT id FROM tenants WHERE name = 'Synthetic Tenant 1');
  DELETE FROM decision_queue WHERE tenant_id IN (SELECT id FROM tenants WHERE name = 'Synthetic Tenant 1');
  DELETE FROM transactions WHERE tenant_id IN (SELECT id FROM tenants WHERE name = 'Synthetic Tenant 1');
  DELETE FROM merchant_risk_graph WHERE tenant_id IN (SELECT id FROM tenants WHERE name = 'Synthetic Tenant 1');
  DELETE FROM cards WHERE tenant_id IN (SELECT id FROM tenants WHERE name = 'Synthetic Tenant 1');
  DELETE FROM merchants WHERE tenant_id IN (SELECT id FROM tenants WHERE name = 'Synthetic Tenant 1');
  DELETE FROM risk_rules WHERE tenant_id IN (SELECT id FROM tenants WHERE name = 'Synthetic Tenant 1');
  DELETE FROM tenants WHERE name = 'Synthetic Tenant 1';

  INSERT INTO tenants (name, status, risk_tier)
  VALUES ('Synthetic Tenant 1', 'active', 'medium')
  RETURNING id INTO v_tid;

  FOR v_j IN 1..10 LOOP
    INSERT INTO merchants (tenant_id, name, mcc_code, risk_score, status)
    VALUES (v_tid, format('Merchant-%s', v_j), lpad((4000+v_j)::text, 4, '0'), (v_j * 8)::numeric, 'active')
    RETURNING id INTO v_mid;
    v_mids := array_append(v_mids, v_mid);
  END LOOP;

  FOR v_j IN 1..50 LOOP
    INSERT INTO cards (tenant_id, card_hash, card_type, status)
    VALUES (v_tid, encode(digest('pan-' || v_j::text, 'sha256'), 'hex'), 'credit', 'active')
    RETURNING id INTO v_cid;
    v_cids := array_append(v_cids, v_cid);
  END LOOP;

  INSERT INTO risk_rules (rule_name, sql_condition, risk_weight, active, tenant_id, rule_expression, threshold, is_active, version)
  VALUES
    ('seed_high_amount_' || v_tid, 'amount >= 1000', 1.5, TRUE, v_tid, 'high_amount', 40, TRUE, 1),
    ('seed_merchant_elevated_' || v_tid, 'merchant risk', 1.2, TRUE, v_tid, 'merchant_elevated', 40, TRUE, 1),
    ('seed_decline_band_' || v_tid, 'amount >= 2000', 2.0, TRUE, v_tid, 'decline_band', 40, TRUE, 1),
    ('seed_review_band_' || v_tid, 'amount band', 0.8, TRUE, v_tid, 'review_band', 40, TRUE, 1),
    ('seed_feature_spike_' || v_tid, 'spike', 1.3, TRUE, v_tid, 'feature_spike', 40, TRUE, 1)
  ON CONFLICT (rule_name) DO NOTHING;

  INSERT INTO merchant_risk_graph (tenant_id, source_merchant, related_merchant, shared_device, risk_link_score)
  VALUES
    (v_tid, v_mids[1], v_mids[2], TRUE, 90),
    (v_tid, v_mids[2], v_mids[3], TRUE, 85),
    (v_tid, v_mids[3], v_mids[4], TRUE, 80),
    (v_tid, v_mids[4], v_mids[1], TRUE, 95),
    (v_tid, v_mids[5], v_mids[6], FALSE, 60);

  FOR v_j IN 1..200 LOOP
    v_score := least(100, (v_j % 50) * 2 + (v_j % 7));
    IF v_score < 40 THEN v_action := 'APPROVED';
    ELSIF v_score > 80 THEN v_action := 'DECLINED';
    ELSE v_action := 'APPROVED';
    END IF;

    INSERT INTO transactions (tenant_id, merchant_id, card_id, amount, currency, status, risk_score, decision)
    VALUES (
      v_tid,
      v_mids[1 + ((v_j - 1) % 10)],
      v_cids[1 + ((v_j - 1) % 50)],
      (10 + (v_j * 17) % 3000)::numeric,
      'USD',
      v_action,
      v_score,
      lower(v_action)
    )
    RETURNING id INTO v_txn;

    IF v_j <= 40 THEN
      INSERT INTO decision_queue (tenant_id, tx_id, status, priority)
      VALUES (v_tid, v_txn, 'PENDING', 100);
    END IF;

    IF v_j <= 30 THEN
      v_payload := jsonb_build_object(
        'tx_id', v_txn,
        'score', v_score,
        'action', CASE WHEN v_action = 'DECLINED' THEN 'BLOCK' ELSE 'APPROVE' END
      );
      PERFORM append_tamper_evident_decision(
        v_mids[1 + ((v_j - 1) % 10)],
        'seed:' || v_txn::text,
        v_score,
        CASE WHEN v_action = 'DECLINED' THEN 'BLOCK' ELSE 'APPROVE' END,
        NULL,
        NULL,
        v_tid,
        v_payload,
        v_txn
      );
    END IF;
  END LOOP;

  -- Insert default alert budget for synthetic tenant
  INSERT INTO alert_budget_config (tenant_id, daily_alert_budget)
  SELECT id, 100 FROM tenants WHERE name = 'Synthetic Tenant 1'
  ON CONFLICT DO NOTHING;

  -- Re-apply RLS policies
  ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
  ALTER TABLE merchants ENABLE ROW LEVEL SECURITY;
  ALTER TABLE cards ENABLE ROW LEVEL SECURITY;
  ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
  ALTER TABLE decision_queue ENABLE ROW LEVEL SECURITY;
  ALTER TABLE decision_audit_log ENABLE ROW LEVEL SECURITY;
  ALTER TABLE merchant_risk_graph ENABLE ROW LEVEL SECURITY;
  ALTER TABLE event_inbox ENABLE ROW LEVEL SECURITY;
END $$;
