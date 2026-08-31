-- Champion / challenger (shadow) policy mode
-- Deploy challenger rules without affecting live decisions; compare lift offline.

CREATE TABLE IF NOT EXISTS policy_modes (
  policy_name TEXT PRIMARY KEY,
  mode TEXT NOT NULL CHECK (mode IN ('champion', 'challenger', 'shadow', 'disabled')),
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT cardops_now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT cardops_now()
);

ALTER TABLE risk_rules ADD COLUMN IF NOT EXISTS policy_lane TEXT DEFAULT 'champion';

CREATE TABLE IF NOT EXISTS shadow_decision_log (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL,
  transaction_id BIGINT NOT NULL,
  champion_action TEXT,
  challenger_action TEXT,
  champion_score NUMERIC(8,4),
  challenger_score NUMERIC(8,4),
  diverged BOOLEAN GENERATED ALWAYS AS (champion_action IS DISTINCT FROM challenger_action) STORED,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT cardops_now()
);

CREATE INDEX IF NOT EXISTS idx_shadow_decision_tenant_time
  ON shadow_decision_log (tenant_id, created_at DESC);

CREATE OR REPLACE FUNCTION run_shadow_score(
  p_transaction_id BIGINT,
  p_challenger_threshold NUMERIC DEFAULT 35
)
RETURNS JSONB AS $$
DECLARE
  v_txn RECORD;
  v_champion JSONB;
  v_score NUMERIC;
  v_challenger_action TEXT;
BEGIN
  SELECT * INTO v_txn FROM transactions WHERE id = p_transaction_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'transaction % not found', p_transaction_id;
  END IF;

  v_champion := explain_transaction_risk(p_transaction_id);
  v_score := (v_champion->>'score')::numeric;

  IF v_score < p_challenger_threshold THEN
    v_challenger_action := 'APPROVE';
  ELSIF v_score > (p_challenger_threshold * 2) THEN
    v_challenger_action := 'BLOCK';
  ELSE
    v_challenger_action := 'REVIEW';
  END IF;

  INSERT INTO shadow_decision_log (
    tenant_id, transaction_id,
    champion_action, challenger_action,
    champion_score, challenger_score, payload
  ) VALUES (
    v_txn.tenant_id,
    p_transaction_id,
    v_champion->>'action',
    v_challenger_action,
    v_score,
    v_score,
    jsonb_build_object(
      'challenger_threshold', p_challenger_threshold,
      'champion', v_champion
    )
  );

  RETURN jsonb_build_object(
    'transaction_id', p_transaction_id,
    'champion_action', v_champion->>'action',
    'challenger_action', v_challenger_action,
    'diverged', (v_champion->>'action') IS DISTINCT FROM v_challenger_action,
    'score', v_score
  );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW shadow_divergence_report AS
SELECT
  tenant_id,
  COUNT(*) AS compared,
  COUNT(*) FILTER (WHERE diverged) AS diverged,
  ROUND(COUNT(*) FILTER (WHERE diverged)::NUMERIC / NULLIF(COUNT(*), 0), 4) AS divergence_rate,
  COUNT(*) FILTER (WHERE champion_action = 'APPROVE' AND challenger_action = 'BLOCK') AS would_block_more,
  COUNT(*) FILTER (WHERE champion_action = 'BLOCK' AND challenger_action = 'APPROVE') AS would_approve_more
FROM shadow_decision_log
GROUP BY tenant_id;

COMMENT ON FUNCTION run_shadow_score IS 'Compare champion vs challenger threshold without changing live outcome';
