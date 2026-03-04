-- Backpressure, retry policy and dead-letter queue

CREATE TABLE IF NOT EXISTS retry_policy (
  policy_name TEXT PRIMARY KEY,
  max_retries INT NOT NULL DEFAULT 5,
  backoff_base_seconds INT NOT NULL DEFAULT 5,
  backoff_multiplier NUMERIC(8,2) NOT NULL DEFAULT 2.0,
  jitter_pct NUMERIC(5,2) NOT NULL DEFAULT 0.15,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS processing_failures (
  id BIGSERIAL PRIMARY KEY,
  queue_id BIGINT,
  event_id UUID,
  tenant_id BIGINT,
  failure_stage TEXT NOT NULL,
  error_message TEXT,
  retries INT NOT NULL DEFAULT 0,
  next_retry_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS dead_letter_queue (
  dlq_id BIGSERIAL PRIMARY KEY,
  event_id UUID,
  tenant_id BIGINT,
  queue_id BIGINT,
  reason TEXT NOT NULL,
  payload JSONB,
  moved_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE VIEW queue_backpressure AS
SELECT
  tenant_id,
  COUNT(*) FILTER (WHERE status='PENDING') AS pending_count,
  COUNT(*) FILTER (WHERE status='PROCESSING') AS processing_count,
  COUNT(*) FILTER (WHERE status='FAILED') AS failed_count,
  AVG(EXTRACT(EPOCH FROM (NOW()-queued_at))) FILTER (WHERE status='PENDING') AS avg_pending_seconds
FROM decision_queue
GROUP BY tenant_id;
