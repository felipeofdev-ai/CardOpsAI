-- Event ingestion + stream primitives (SQL-native)

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS event_inbox (
  event_id UUID PRIMARY KEY,
  tenant_id BIGINT NOT NULL,
  event_type TEXT NOT NULL,
  source_system TEXT,
  payload JSONB NOT NULL,
  idempotency_key TEXT,
  status TEXT NOT NULL DEFAULT 'RECEIVED',
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  validated_at TIMESTAMPTZ,
  processed_at TIMESTAMPTZ,
  error_message TEXT,
  UNIQUE (tenant_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_event_inbox_status_time
  ON event_inbox (status, received_at);

CREATE TABLE IF NOT EXISTS transaction_events (
  event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id BIGINT NOT NULL,
  tx_id BIGINT,
  event_name TEXT NOT NULL,
  payload JSONB NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS merchant_events (
  event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id BIGINT NOT NULL,
  merchant_id BIGINT NOT NULL,
  event_name TEXT NOT NULL,
  payload JSONB NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fraud_events (
  event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id BIGINT NOT NULL,
  merchant_id BIGINT,
  tx_id BIGINT,
  event_name TEXT NOT NULL,
  risk_score NUMERIC(10,4),
  payload JSONB NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS risk_events (
  event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id BIGINT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id BIGINT NOT NULL,
  event_name TEXT NOT NULL,
  payload JSONB NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS decision_events (
  event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id BIGINT NOT NULL,
  decision_id BIGINT,
  event_name TEXT NOT NULL,
  payload JSONB NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS decision_queue (
  queue_id BIGSERIAL PRIMARY KEY,
  event_id UUID,
  tenant_id BIGINT NOT NULL,
  tx_id BIGINT,
  priority INT NOT NULL DEFAULT 100,
  status TEXT NOT NULL DEFAULT 'PENDING',
  retries INT NOT NULL DEFAULT 0,
  max_retries INT NOT NULL DEFAULT 5,
  queued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  started_at TIMESTAMPTZ,
  finished_at TIMESTAMPTZ,
  last_error TEXT
);

CREATE INDEX IF NOT EXISTS idx_decision_queue_status_priority
  ON decision_queue (status, priority, queued_at);
