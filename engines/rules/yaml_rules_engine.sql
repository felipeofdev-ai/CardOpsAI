-- YAML policy import + evaluation bridge (human-editable rules)

CREATE OR REPLACE FUNCTION import_yaml_policy(
  p_tenant_id BIGINT,
  p_policy_name TEXT,
  p_yaml_body TEXT
) RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  UPDATE policy_documents
     SET is_active = FALSE
   WHERE tenant_id = p_tenant_id AND policy_name = p_policy_name;

  INSERT INTO policy_documents (tenant_id, policy_name, policy_format, policy_body, is_active)
  VALUES (p_tenant_id, p_policy_name, 'yaml', p_yaml_body, TRUE)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION apply_yaml_policy_to_rules(
  p_tenant_id BIGINT,
  p_policy_name TEXT DEFAULT 'default'
) RETURNS INT AS $$
DECLARE
  v_body TEXT;
  v_line TEXT;
  v_count INT := 0;
  v_name TEXT;
  v_expr TEXT;
  v_weight NUMERIC;
  v_threshold NUMERIC;
BEGIN
  SELECT policy_body INTO v_body
  FROM policy_documents
  WHERE tenant_id = p_tenant_id
    AND policy_name = p_policy_name
    AND is_active = TRUE
  ORDER BY version DESC
  LIMIT 1;

  IF v_body IS NULL THEN
    RAISE EXCEPTION 'no active yaml policy % for tenant %', p_policy_name, p_tenant_id;
  END IF;

  -- Minimal YAML DSL parser: lines like "rule_name: expression | weight:1.2 | threshold:40"
  FOR v_line IN
    SELECT trim(x) FROM unnest(string_to_array(v_body, E'\n')) AS x
    WHERE trim(x) <> '' AND trim(x) NOT LIKE '#%'
  LOOP
    v_name := split_part(v_line, ':', 1);
    v_expr := trim(split_part(split_part(v_line, ':', 2), '|', 1));
    v_weight := COALESCE(NULLIF(trim(split_part(split_part(v_line, '|', 2), ':', 2)), '')::numeric, 1.0);
    v_threshold := COALESCE(NULLIF(trim(split_part(split_part(v_line, '|', 3), ':', 2)), '')::numeric, 50);

    INSERT INTO risk_rules (
      rule_name, sql_condition, risk_weight, active,
      tenant_id, rule_expression, threshold, is_active, version
    ) VALUES (
      p_policy_name || '_' || v_name || '_' || p_tenant_id,
      v_expr, v_weight, TRUE,
      p_tenant_id, v_expr, v_threshold, TRUE, 1
    )
    ON CONFLICT (rule_name) DO UPDATE SET
      rule_expression = EXCLUDED.rule_expression,
      risk_weight = EXCLUDED.risk_weight,
      threshold = EXCLUDED.threshold,
      is_active = TRUE;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION import_yaml_policy IS 'Store human-editable YAML policy document';
COMMENT ON FUNCTION apply_yaml_policy_to_rules IS 'Parse YAML DSL into risk_rules rows';
