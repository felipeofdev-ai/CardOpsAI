-- Velocity / behavioral features (leakage-safe: looking only at prior txs)
-- Patterns inspired by production fraud engines: rolling counts, spikes, dormancy.

CREATE OR REPLACE FUNCTION refresh_velocity_features(p_tenant_id BIGINT DEFAULT NULL)
RETURNS INT AS $$
DECLARE
  v_count INT := 0;
  v_total INT := 0;
BEGIN
  CREATE TABLE IF NOT EXISTS velocity_features (
    tenant_id BIGINT NOT NULL,
    entity_type TEXT NOT NULL CHECK (entity_type IN ('card', 'merchant')),
    entity_id TEXT NOT NULL,
    tx_count_1h INT NOT NULL DEFAULT 0,
    tx_count_24h INT NOT NULL DEFAULT 0,
    tx_count_7d INT NOT NULL DEFAULT 0,
    amount_sum_24h NUMERIC(18,2) NOT NULL DEFAULT 0,
    amount_avg_7d NUMERIC(18,2) NOT NULL DEFAULT 0,
    amount_max_30d NUMERIC(18,2) NOT NULL DEFAULT 0,
    hours_since_last_tx NUMERIC(12,4),
    amount_spike_ratio NUMERIC(12,4),
    computed_at TIMESTAMPTZ NOT NULL DEFAULT cardops_now(),
    PRIMARY KEY (tenant_id, entity_type, entity_id)
  );

  -- Merchant velocity
  INSERT INTO velocity_features AS vf (
    tenant_id, entity_type, entity_id,
    tx_count_1h, tx_count_24h, tx_count_7d,
    amount_sum_24h, amount_avg_7d, amount_max_30d,
    hours_since_last_tx, amount_spike_ratio, computed_at
  )
  SELECT
    t.tenant_id,
    'merchant',
    t.merchant_id::text,
    COUNT(*) FILTER (WHERE t.created_at >= cardops_now() - INTERVAL '1 hour'),
    COUNT(*) FILTER (WHERE t.created_at >= cardops_now() - INTERVAL '24 hours'),
    COUNT(*) FILTER (WHERE t.created_at >= cardops_now() - INTERVAL '7 days'),
    COALESCE(SUM(t.amount) FILTER (WHERE t.created_at >= cardops_now() - INTERVAL '24 hours'), 0),
    COALESCE(AVG(t.amount) FILTER (WHERE t.created_at >= cardops_now() - INTERVAL '7 days'), 0),
    COALESCE(MAX(t.amount) FILTER (WHERE t.created_at >= cardops_now() - INTERVAL '30 days'), 0),
    EXTRACT(EPOCH FROM (cardops_now() - MAX(t.created_at))) / 3600.0,
    CASE
      WHEN AVG(t.amount) FILTER (WHERE t.created_at >= cardops_now() - INTERVAL '7 days') > 0
      THEN MAX(t.amount) / NULLIF(AVG(t.amount) FILTER (WHERE t.created_at >= cardops_now() - INTERVAL '7 days'), 0)
      ELSE 0
    END,
    cardops_now()
  FROM transactions t
  WHERE (p_tenant_id IS NULL OR t.tenant_id = p_tenant_id)
  GROUP BY t.tenant_id, t.merchant_id
  ON CONFLICT (tenant_id, entity_type, entity_id) DO UPDATE SET
    tx_count_1h = EXCLUDED.tx_count_1h,
    tx_count_24h = EXCLUDED.tx_count_24h,
    tx_count_7d = EXCLUDED.tx_count_7d,
    amount_sum_24h = EXCLUDED.amount_sum_24h,
    amount_avg_7d = EXCLUDED.amount_avg_7d,
    amount_max_30d = EXCLUDED.amount_max_30d,
    hours_since_last_tx = EXCLUDED.hours_since_last_tx,
    amount_spike_ratio = EXCLUDED.amount_spike_ratio,
    computed_at = EXCLUDED.computed_at;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  v_total := v_total + v_count;

  -- Card velocity (when card_id present)
  INSERT INTO velocity_features AS vf (
    tenant_id, entity_type, entity_id,
    tx_count_1h, tx_count_24h, tx_count_7d,
    amount_sum_24h, amount_avg_7d, amount_max_30d,
    hours_since_last_tx, amount_spike_ratio, computed_at
  )
  SELECT
    t.tenant_id,
    'card',
    t.card_id::text,
    COUNT(*) FILTER (WHERE t.created_at >= cardops_now() - INTERVAL '1 hour'),
    COUNT(*) FILTER (WHERE t.created_at >= cardops_now() - INTERVAL '24 hours'),
    COUNT(*) FILTER (WHERE t.created_at >= cardops_now() - INTERVAL '7 days'),
    COALESCE(SUM(t.amount) FILTER (WHERE t.created_at >= cardops_now() - INTERVAL '24 hours'), 0),
    COALESCE(AVG(t.amount) FILTER (WHERE t.created_at >= cardops_now() - INTERVAL '7 days'), 0),
    COALESCE(MAX(t.amount) FILTER (WHERE t.created_at >= cardops_now() - INTERVAL '30 days'), 0),
    EXTRACT(EPOCH FROM (cardops_now() - MAX(t.created_at))) / 3600.0,
    CASE
      WHEN AVG(t.amount) FILTER (WHERE t.created_at >= cardops_now() - INTERVAL '7 days') > 0
      THEN MAX(t.amount) / NULLIF(AVG(t.amount) FILTER (WHERE t.created_at >= cardops_now() - INTERVAL '7 days'), 0)
      ELSE 0
    END,
    cardops_now()
  FROM transactions t
  WHERE t.card_id IS NOT NULL
    AND (p_tenant_id IS NULL OR t.tenant_id = p_tenant_id)
  GROUP BY t.tenant_id, t.card_id
  ON CONFLICT (tenant_id, entity_type, entity_id) DO UPDATE SET
    tx_count_1h = EXCLUDED.tx_count_1h,
    tx_count_24h = EXCLUDED.tx_count_24h,
    tx_count_7d = EXCLUDED.tx_count_7d,
    amount_sum_24h = EXCLUDED.amount_sum_24h,
    amount_avg_7d = EXCLUDED.amount_avg_7d,
    amount_max_30d = EXCLUDED.amount_max_30d,
    hours_since_last_tx = EXCLUDED.hours_since_last_tx,
    amount_spike_ratio = EXCLUDED.amount_spike_ratio,
    computed_at = EXCLUDED.computed_at;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  v_total := v_total + v_count;
  RETURN v_total;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW velocity_burst_alerts AS
SELECT *
FROM velocity_features
WHERE tx_count_1h >= 8
   OR tx_count_24h >= 40
   OR amount_spike_ratio >= 3
   OR COALESCE(hours_since_last_tx, 0) >= 720; -- dormancy wake-up (30d+)

COMMENT ON FUNCTION refresh_velocity_features IS 'Materialize card/merchant rolling velocity features for scoring';
