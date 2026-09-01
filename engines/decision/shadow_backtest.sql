-- Batch shadow backtest over historical window

CREATE TABLE IF NOT EXISTS shadow_backtest_runs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id BIGINT NOT NULL REFERENCES tenants(id),
  window_start TIMESTAMPTZ NOT NULL,
  window_end TIMESTAMPTZ NOT NULL,
  challenger_threshold NUMERIC NOT NULL,
  compared INT NOT NULL DEFAULT 0,
  diverged INT NOT NULL DEFAULT 0,
  would_block_more INT NOT NULL DEFAULT 0,
  would_approve_more INT NOT NULL DEFAULT 0,
  metrics JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT cardops_now()
);

CREATE OR REPLACE FUNCTION run_shadow_backtest(
  p_tenant_id BIGINT,
  p_days INT DEFAULT 30,
  p_challenger_threshold NUMERIC DEFAULT 35,
  p_sample_limit INT DEFAULT 500
)
RETURNS UUID AS $$
DECLARE
  v_start TIMESTAMPTZ;
  v_end TIMESTAMPTZ;
  v_txn RECORD;
  v_result JSONB;
  v_compared INT := 0;
  v_diverged INT := 0;
  v_block_more INT := 0;
  v_approve_more INT := 0;
  v_id UUID;
BEGIN
  v_end := cardops_now();
  v_start := v_end - (p_days || ' days')::interval;

  FOR v_txn IN
    SELECT id FROM transactions
    WHERE tenant_id = p_tenant_id
      AND created_at BETWEEN v_start AND v_end
    ORDER BY created_at DESC
    LIMIT p_sample_limit
  LOOP
    v_result := run_shadow_score(v_txn.id, p_challenger_threshold);
    v_compared := v_compared + 1;
    IF (v_result->>'diverged')::boolean THEN
      v_diverged := v_diverged + 1;
    END IF;
    IF v_result->>'champion_action' = 'APPROVE' AND v_result->>'challenger_action' = 'BLOCK' THEN
      v_block_more := v_block_more + 1;
    END IF;
    IF v_result->>'champion_action' = 'BLOCK' AND v_result->>'challenger_action' = 'APPROVE' THEN
      v_approve_more := v_approve_more + 1;
    END IF;
  END LOOP;

  INSERT INTO shadow_backtest_runs (
    tenant_id, window_start, window_end, challenger_threshold,
    compared, diverged, would_block_more, would_approve_more, metrics
  ) VALUES (
    p_tenant_id, v_start, v_end, p_challenger_threshold,
    v_compared, v_diverged, v_block_more, v_approve_more,
    jsonb_build_object(
      'divergence_rate', CASE WHEN v_compared > 0 THEN round(v_diverged::numeric / v_compared, 4) ELSE 0 END,
      'sample_limit', p_sample_limit,
      'days', p_days
    )
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION run_shadow_backtest IS 'Champion vs challenger batch over historical transactions';
