-- Nacha-style / audit regulatory export packet

CREATE OR REPLACE FUNCTION export_regulatory_packet(p_tenant_id BIGINT)
RETURNS JSONB AS $$
DECLARE
  v_ledger JSONB;
  v_snap TEXT;
  v_hash TEXT;
  v_id UUID;
BEGIN
  SELECT jsonb_build_object(
    'ok', (verify_decision_ledger_integrity(p_tenant_id)->>'ok')::boolean,
    'detail', verify_decision_ledger_integrity(p_tenant_id),
    'decision_count', (SELECT count(*) FROM decision_audit_log WHERE tenant_id = p_tenant_id),
    'audit_sample', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'id', id, 'action_taken', action_taken,
        'decision_hash', decision_hash, 'created_at', created_at
      ) ORDER BY id DESC), '[]'::jsonb)
      FROM (SELECT id, action_taken, decision_hash, created_at
            FROM decision_audit_log WHERE tenant_id = p_tenant_id
            ORDER BY id DESC LIMIT 50) s
    )
  ) INTO v_ledger;

  SELECT rules_hash INTO v_snap
  FROM config_snapshots ORDER BY created_at DESC LIMIT 1;

  v_hash := encode(
    digest(v_ledger::text || COALESCE(v_snap, ''), 'sha256'),
    'hex'
  );

  INSERT INTO regulatory_exports (tenant_id, export_type, packet_hash, payload)
  VALUES (
    p_tenant_id,
    'nacha_audit_packet',
    v_hash,
    jsonb_build_object(
      'tenant_id', p_tenant_id,
      'exported_at', cardops_now(),
      'policy_version_hash', v_snap,
      'ledger', v_ledger,
      'adverse_action_codes', (SELECT jsonb_agg(jsonb_build_object('code', code, 'title', title)) FROM adverse_action_codes),
      'shadow_backtest_latest', (
        SELECT row_to_json(s)::jsonb FROM (
          SELECT * FROM shadow_backtest_runs WHERE tenant_id = p_tenant_id ORDER BY created_at DESC LIMIT 1
        ) s
      )
    )
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object(
    'export_id', v_id,
    'packet_hash', v_hash,
    'tenant_id', p_tenant_id
  );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW prometheus_cardops_metrics AS
SELECT
  'cardops_pending_queue' AS metric,
  (SELECT count(*) FROM decision_queue WHERE upper(status) = 'PENDING')::numeric AS value
UNION ALL
SELECT 'cardops_p1_alerts', (SELECT count(*) FROM alert_triage_queue WHERE priority_band = 'P1')::numeric
UNION ALL
SELECT 'cardops_drift_breaches', (SELECT count(*) FROM drift_breaches)::numeric
UNION ALL
SELECT 'cardops_shadow_divergences_24h',
  (SELECT count(*) FROM shadow_decision_log WHERE diverged AND created_at >= cardops_now() - interval '24 hours')::numeric
UNION ALL
SELECT 'cardops_ledger_ok',
  CASE WHEN (verify_decision_ledger_integrity()->>'ok')::boolean THEN 1 ELSE 0 END;

COMMENT ON FUNCTION export_regulatory_packet IS 'Tamper-evident regulatory audit packet with policy + ledger';
