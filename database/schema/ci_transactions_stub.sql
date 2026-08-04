-- CI/dev fixture: minimal transactions table referenced by engines (not production data).
CREATE TABLE IF NOT EXISTS transactions (
  id BIGSERIAL PRIMARY KEY,
  tenant_id BIGINT NOT NULL DEFAULT 1,
  merchant_id BIGINT NOT NULL DEFAULT 1,
  amount NUMERIC(18,2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'APPROVED',
  geolocation TEXT,
  device_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
