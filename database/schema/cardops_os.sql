-- CardOpsAI SQL-native Operating System baseline schema

CREATE TABLE IF NOT EXISTS system_flags (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS risk_rules (
  id BIGSERIAL PRIMARY KEY,
  rule_name TEXT NOT NULL UNIQUE,
  sql_condition TEXT NOT NULL,
  risk_weight NUMERIC(8,2) NOT NULL,
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS decision_audit_log (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL,
  merchant_id BIGINT NOT NULL,
  problem_id TEXT NOT NULL,
  decision_score NUMERIC(8,4),
  action_taken TEXT NOT NULL,
  model_version_id BIGINT,
  outcome TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_decision_tenant_created
  ON decision_audit_log (tenant_id, created_at DESC);

CREATE TABLE IF NOT EXISTS decision_explanations (
  decision_id BIGINT NOT NULL REFERENCES decision_audit_log(id),
  factor TEXT NOT NULL,
  feature_value NUMERIC(18,6),
  weight NUMERIC(8,4) NOT NULL,
  contribution NUMERIC(10,4) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS incident_ledger (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS merchant_risk_graph (
  tenant_id BIGINT NOT NULL,
  source_merchant BIGINT NOT NULL,
  related_merchant BIGINT NOT NULL,
  shared_device BOOLEAN DEFAULT FALSE,
  shared_ip BOOLEAN DEFAULT FALSE,
  shared_card_token BOOLEAN DEFAULT FALSE,
  risk_link_score NUMERIC(8,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (tenant_id, source_merchant, related_merchant)
);

-- Optional feature store (requires transactions table in same database)
-- CREATE MATERIALIZED VIEW merchant_features AS
-- SELECT
--   merchant_id,
--   AVG(amount) AS avg_ticket,
--   STDDEV(amount) AS ticket_volatility,
--   COUNT(*) FILTER (WHERE status='DECLINED')::FLOAT / NULLIF(COUNT(*),0) AS decline_rate_30d
-- FROM transactions
-- WHERE created_at >= NOW() - INTERVAL '30 days'
-- GROUP BY merchant_id;
