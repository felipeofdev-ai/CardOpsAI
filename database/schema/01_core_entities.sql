-- Core multi-tenant entities (compatible with legacy amount/status consumers)

CREATE TABLE IF NOT EXISTS tenants (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
  risk_tier TEXT NOT NULL DEFAULT 'medium' CHECK (risk_tier IN ('low', 'medium', 'high', 'critical')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT cardops_now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT cardops_now()
);

CREATE TABLE IF NOT EXISTS merchants (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL REFERENCES tenants(id),
  name TEXT NOT NULL,
  mcc_code CHAR(4) NOT NULL DEFAULT '0000',
  risk_score NUMERIC(8, 4) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT cardops_now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT cardops_now(),
  UNIQUE (tenant_id, name)
);

CREATE TABLE IF NOT EXISTS cards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id BIGINT NOT NULL REFERENCES tenants(id),
  card_hash TEXT NOT NULL CHECK (char_length(card_hash) = 64),
  card_type TEXT NOT NULL DEFAULT 'credit',
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT cardops_now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT cardops_now(),
  UNIQUE (tenant_id, card_hash)
);

-- Production-shaped transactions while preserving legacy columns used by OS views
CREATE TABLE IF NOT EXISTS transactions (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL DEFAULT 1,
  merchant_id BIGINT NOT NULL DEFAULT 1,
  card_id UUID,
  amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
  amount_cents BIGINT GENERATED ALWAYS AS (round(amount * 100)::BIGINT) STORED,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  status TEXT NOT NULL DEFAULT 'APPROVED',
  risk_score NUMERIC(8, 4),
  decision TEXT,
  decision_reason JSONB NOT NULL DEFAULT '{}'::jsonb,
  geolocation TEXT,
  device_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT cardops_now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT cardops_now()
);

-- Idempotent upgrades when stub already exists (CI / older DBs)
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS card_id UUID;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS currency CHAR(3);
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS risk_score NUMERIC(8, 4);
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS decision TEXT;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS decision_reason JSONB;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS geolocation TEXT;
ALTER TABLE transactions ADD COLUMN IF NOT EXISTS device_id TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_name = 'transactions' AND column_name = 'amount_cents'
  ) THEN
    ALTER TABLE transactions
      ADD COLUMN amount_cents BIGINT GENERATED ALWAYS AS (round(amount * 100)::BIGINT) STORED;
  END IF;
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

UPDATE transactions SET currency = COALESCE(currency, 'USD');
UPDATE transactions SET decision_reason = COALESCE(decision_reason, '{}'::jsonb);
UPDATE transactions SET updated_at = COALESCE(updated_at, created_at, cardops_now());

CREATE INDEX IF NOT EXISTS idx_transactions_tenant_created
  ON transactions (tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_merchant
  ON transactions (merchant_id);
CREATE INDEX IF NOT EXISTS idx_merchants_tenant
  ON merchants (tenant_id);
CREATE INDEX IF NOT EXISTS idx_cards_tenant
  ON cards (tenant_id);

DROP TRIGGER IF EXISTS trg_tenants_updated_at ON tenants;
CREATE TRIGGER trg_tenants_updated_at
  BEFORE UPDATE ON tenants
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_merchants_updated_at ON merchants;
CREATE TRIGGER trg_merchants_updated_at
  BEFORE UPDATE ON merchants
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_cards_updated_at ON cards;
CREATE TRIGGER trg_cards_updated_at
  BEFORE UPDATE ON cards
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_transactions_updated_at ON transactions;
CREATE TRIGGER trg_transactions_updated_at
  BEFORE UPDATE ON transactions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
