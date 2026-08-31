-- Geo-velocity / impossible-travel heuristic (device + geolocation fields)

CREATE OR REPLACE FUNCTION detect_geo_velocity_anomalies(
  p_tenant_id BIGINT,
  p_max_hours NUMERIC DEFAULT 2
)
RETURNS TABLE (
  transaction_id BIGINT,
  card_id UUID,
  prev_transaction_id BIGINT,
  prev_geo TEXT,
  curr_geo TEXT,
  hours_between NUMERIC,
  device_changed BOOLEAN,
  anomaly_reason TEXT
) AS $$
BEGIN
  RETURN QUERY
  WITH ordered AS (
    SELECT
      t.id,
      t.tenant_id,
      t.card_id,
      t.geolocation,
      t.device_id,
      t.created_at,
      LAG(t.id) OVER (PARTITION BY t.tenant_id, t.card_id ORDER BY t.created_at, t.id) AS prev_id,
      LAG(t.geolocation) OVER (PARTITION BY t.tenant_id, t.card_id ORDER BY t.created_at, t.id) AS prev_geo,
      LAG(t.device_id) OVER (PARTITION BY t.tenant_id, t.card_id ORDER BY t.created_at, t.id) AS prev_device,
      LAG(t.created_at) OVER (PARTITION BY t.tenant_id, t.card_id ORDER BY t.created_at, t.id) AS prev_ts
    FROM transactions t
    WHERE t.tenant_id = p_tenant_id
      AND t.card_id IS NOT NULL
  )
  SELECT
    o.id,
    o.card_id,
    o.prev_id,
    o.prev_geo,
    o.geolocation,
    ROUND(EXTRACT(EPOCH FROM (o.created_at - o.prev_ts)) / 3600.0, 4),
    (o.device_id IS DISTINCT FROM o.prev_device),
    CASE
      WHEN o.geolocation IS DISTINCT FROM o.prev_geo
           AND EXTRACT(EPOCH FROM (o.created_at - o.prev_ts)) / 3600.0 <= p_max_hours
        THEN 'geo_change_within_window'
      WHEN o.device_id IS DISTINCT FROM o.prev_device
           AND o.geolocation IS DISTINCT FROM o.prev_geo
        THEN 'device_and_geo_change'
      ELSE 'device_change_fast'
    END
  FROM ordered o
  WHERE o.prev_id IS NOT NULL
    AND (
      (o.geolocation IS DISTINCT FROM o.prev_geo
        AND EXTRACT(EPOCH FROM (o.created_at - o.prev_ts)) / 3600.0 <= p_max_hours)
      OR (o.device_id IS DISTINCT FROM o.prev_device
        AND EXTRACT(EPOCH FROM (o.created_at - o.prev_ts)) / 3600.0 <= p_max_hours)
    );
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE VIEW system_health_panel AS
SELECT
  (SELECT COUNT(*) FROM decision_queue WHERE upper(status) = 'PENDING') AS pending_queue,
  (SELECT COUNT(*) FROM decision_queue WHERE upper(status) = 'DEAD') AS dead_letter,
  (SELECT COUNT(*) FROM risk_rules WHERE COALESCE(is_active, active, TRUE)) AS active_rules,
  (SELECT COUNT(*) FROM drift_breaches) AS open_drift_breaches,
  (SELECT COUNT(*) FROM shadow_decision_log WHERE diverged AND created_at >= cardops_now() - INTERVAL '24 hours') AS shadow_divergences_24h,
  (SELECT COUNT(*) FROM alert_triage_queue WHERE priority_band = 'P1') AS p1_alerts,
  (SELECT verify_decision_ledger_integrity()->>'ok') AS ledger_ok,
  cardops_now() AS as_of;

COMMENT ON FUNCTION detect_geo_velocity_anomalies IS 'Heuristic impossible-travel / device switch signals';
COMMENT ON VIEW system_health_panel IS 'Single-pane operator health metrics';
