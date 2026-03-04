-- Config snapshot engine for deterministic replay

CREATE OR REPLACE FUNCTION create_config_snapshot()
RETURNS UUID AS $$
DECLARE
  v_rules_hash TEXT;
  v_thresholds_hash TEXT;
  v_feature_schema_hash TEXT;
  v_risk_weights_hash TEXT;
  v_snapshot_id UUID;
BEGIN
  SELECT encode(digest(COALESCE(string_agg(rule_name || ':' || sql_condition || ':' || risk_weight::TEXT, '|' ORDER BY rule_name), ''), 'sha256'), 'hex')
    INTO v_rules_hash
  FROM risk_rules
  WHERE active = TRUE;

  -- Placeholder: replace with real threshold table digest when available.
  SELECT encode(digest('thresholds_v1', 'sha256'), 'hex') INTO v_thresholds_hash;

  -- Placeholder: replace with INFORMATION_SCHEMA-based feature digest when feature tables are finalized.
  SELECT encode(digest('feature_schema_v1', 'sha256'), 'hex') INTO v_feature_schema_hash;

  SELECT encode(digest(COALESCE(string_agg(rule_name || ':' || risk_weight::TEXT, '|' ORDER BY rule_name), ''), 'sha256'), 'hex')
    INTO v_risk_weights_hash
  FROM risk_rules
  WHERE active = TRUE;

  INSERT INTO config_snapshots (rules_hash, thresholds_hash, feature_schema_hash, risk_weights_hash)
  VALUES (v_rules_hash, v_thresholds_hash, v_feature_schema_hash, v_risk_weights_hash)
  RETURNING snapshot_id INTO v_snapshot_id;

  RETURN v_snapshot_id;
END;
$$ LANGUAGE plpgsql;
