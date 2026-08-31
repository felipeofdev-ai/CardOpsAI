-- Ledger integrity: requires decision_audit_log.payload (added in schema enhancements)

CREATE OR REPLACE FUNCTION verify_decision_ledger_integrity(
  p_tenant_id BIGINT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
  r RECORD;
  v_expected TEXT;
  v_prev TEXT := NULL;
  v_checked INT := 0;
  v_first_broken BIGINT := NULL;
  v_expected_hash TEXT := NULL;
  v_actual_hash TEXT := NULL;
  v_last_tenant BIGINT := NULL;
BEGIN
  FOR r IN
    SELECT id, tenant_id, previous_hash, decision_hash, payload
      FROM decision_audit_log dal
     WHERE (p_tenant_id IS NULL OR dal.tenant_id = p_tenant_id)
       AND dal.decision_hash IS NOT NULL
     ORDER BY dal.tenant_id NULLS LAST, dal.id
  LOOP
    IF v_last_tenant IS DISTINCT FROM r.tenant_id THEN
      v_prev := NULL;
      v_last_tenant := r.tenant_id;
    END IF;

    IF COALESCE(r.previous_hash, 'GENESIS') IS DISTINCT FROM COALESCE(v_prev, 'GENESIS') THEN
      v_first_broken := r.id;
      v_expected_hash := COALESCE(v_prev, 'GENESIS');
      v_actual_hash := COALESCE(r.previous_hash, 'GENESIS');
      EXIT;
    END IF;

    IF r.payload IS NULL THEN
      v_first_broken := r.id;
      v_expected_hash := '<missing payload>';
      v_actual_hash := r.decision_hash;
      EXIT;
    END IF;

    v_expected := compute_decision_hash(r.previous_hash, r.payload);
    v_checked := v_checked + 1;

    IF r.decision_hash IS DISTINCT FROM v_expected THEN
      v_first_broken := r.id;
      v_expected_hash := v_expected;
      v_actual_hash := r.decision_hash;
      EXIT;
    END IF;

    v_prev := r.decision_hash;
  END LOOP;

  IF v_first_broken IS NULL THEN
    RETURN jsonb_build_object(
      'ok', true,
      'checked', v_checked,
      'first_broken_id', NULL,
      'expected_hash', NULL,
      'actual_hash', NULL
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', false,
    'checked', v_checked,
    'first_broken_id', v_first_broken,
    'expected_hash', v_expected_hash,
    'actual_hash', v_actual_hash
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

COMMENT ON FUNCTION verify_decision_ledger_integrity(BIGINT)
  IS 'Walks tenant hash chains using stored payload + decision_hash';
