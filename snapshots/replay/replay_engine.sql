-- Deterministic replay helper using snapshot/model versions

CREATE OR REPLACE FUNCTION replay_decisions(
  p_tenant_id BIGINT,
  p_snapshot_id UUID,
  p_model_version_id BIGINT,
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ
)
RETURNS TABLE(
  decision_id BIGINT,
  merchant_id BIGINT,
  original_score NUMERIC,
  original_action TEXT,
  snapshot_id UUID,
  model_version_id BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.id,
    d.merchant_id,
    d.decision_score,
    d.action_taken,
    d.snapshot_id,
    d.model_version_id
  FROM decision_audit_log d
  WHERE d.tenant_id = p_tenant_id
    AND d.snapshot_id = p_snapshot_id
    AND d.model_version_id = p_model_version_id
    AND d.created_at BETWEEN COALESCE(p_from, cardops_now()-INTERVAL '30 days') AND COALESCE(p_to, cardops_now())
  ORDER BY d.created_at;
END;
$$ LANGUAGE plpgsql;
