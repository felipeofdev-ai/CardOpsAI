-- Resource isolation and quota controls per tenant

CREATE TABLE IF NOT EXISTS tenant_limits (
  tenant_id BIGINT PRIMARY KEY,
  max_tps INT NOT NULL DEFAULT 500,
  max_queue_depth INT NOT NULL DEFAULT 50000,
  max_mv_refresh_per_hour INT NOT NULL DEFAULT 60,
  max_parallel_replay_jobs INT NOT NULL DEFAULT 2,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tenant_usage_metrics (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL,
  observed_tps NUMERIC(12,3),
  queue_depth BIGINT,
  mv_refresh_count_hour INT,
  replay_jobs_running INT,
  measured_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE VIEW tenant_limit_breaches AS
SELECT
  u.tenant_id,
  u.measured_at,
  (u.observed_tps > l.max_tps) AS tps_breach,
  (u.queue_depth > l.max_queue_depth) AS queue_breach,
  (u.mv_refresh_count_hour > l.max_mv_refresh_per_hour) AS mv_breach,
  (u.replay_jobs_running > l.max_parallel_replay_jobs) AS replay_breach
FROM tenant_usage_metrics u
JOIN tenant_limits l ON l.tenant_id = u.tenant_id
WHERE (u.observed_tps > l.max_tps)
   OR (u.queue_depth > l.max_queue_depth)
   OR (u.mv_refresh_count_hour > l.max_mv_refresh_per_hour)
   OR (u.replay_jobs_running > l.max_parallel_replay_jobs);
