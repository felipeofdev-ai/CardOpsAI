-- Referential integrity + scale primitives (Tier-0)

-- FK constraints (idempotent via DO blocks)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'transactions_merchant_fk') THEN
    ALTER TABLE transactions
      ADD CONSTRAINT transactions_merchant_fk
      FOREIGN KEY (merchant_id) REFERENCES merchants(id);
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'transactions_card_fk') THEN
    ALTER TABLE transactions
      ADD CONSTRAINT transactions_card_fk
      FOREIGN KEY (card_id) REFERENCES cards(id);
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'transactions_tenant_fk') THEN
    ALTER TABLE transactions
      ADD CONSTRAINT transactions_tenant_fk
      FOREIGN KEY (tenant_id) REFERENCES tenants(id);
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Daily alert budget (cost-sensitive ops)
CREATE TABLE IF NOT EXISTS alert_budget_config (
  tenant_id BIGINT PRIMARY KEY REFERENCES tenants(id),
  daily_alert_budget INT NOT NULL DEFAULT 100 CHECK (daily_alert_budget > 0),
  false_decline_cost_cents BIGINT NOT NULL DEFAULT 500,
  fraud_loss_multiplier NUMERIC(8,4) NOT NULL DEFAULT 1.0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT cardops_now()
);

CREATE TABLE IF NOT EXISTS alert_budget_usage (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES tenants(id),
  usage_date DATE NOT NULL DEFAULT (cardops_now()::date),
  alerts_consumed INT NOT NULL DEFAULT 0,
  expected_loss_total NUMERIC(18,4) NOT NULL DEFAULT 0,
  UNIQUE (tenant_id, usage_date)
);

-- YAML / JsonLogic policy store
CREATE TABLE IF NOT EXISTS policy_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id BIGINT NOT NULL REFERENCES tenants(id),
  policy_name TEXT NOT NULL,
  policy_format TEXT NOT NULL DEFAULT 'yaml' CHECK (policy_format IN ('yaml', 'jsonlogic')),
  policy_body TEXT NOT NULL,
  version INT NOT NULL DEFAULT 1,
  is_active BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT cardops_now(),
  UNIQUE (tenant_id, policy_name, version)
);

CREATE INDEX IF NOT EXISTS idx_policy_documents_active
  ON policy_documents (tenant_id, is_active) WHERE is_active = TRUE;

-- Regulatory export log
CREATE TABLE IF NOT EXISTS regulatory_exports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id BIGINT NOT NULL REFERENCES tenants(id),
  export_type TEXT NOT NULL DEFAULT 'nacha_audit_packet',
  packet_hash TEXT NOT NULL,
  payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT cardops_now()
);

-- Partition-ready parent tables (attach partitions in production)
CREATE TABLE IF NOT EXISTS transactions_partitioned (
  LIKE transactions INCLUDING DEFAULTS INCLUDING CONSTRAINTS
) PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS decision_audit_log_partitioned (
  LIKE decision_audit_log INCLUDING DEFAULTS
) PARTITION BY RANGE (created_at);

COMMENT ON TABLE alert_budget_config IS 'Daily investigator capacity — cost-sensitive triage';
COMMENT ON TABLE policy_documents IS 'Human-editable YAML/JsonLogic policies';
