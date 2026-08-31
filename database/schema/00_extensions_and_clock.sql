-- Extensions + deterministic clock (supports both GUCs used across CardOpsAI)
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE OR REPLACE FUNCTION cardops_now()
RETURNS TIMESTAMPTZ AS $$
  SELECT COALESCE(
    NULLIF(current_setting('cardops.mock_now', true), '')::timestamptz,
    NULLIF(current_setting('cardops.replay_time', true), '')::timestamptz,
    now()
  );
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION set_replay_time(p_time TIMESTAMPTZ)
RETURNS VOID AS $$
  SELECT set_config('cardops.replay_time', p_time::TEXT, true);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION clear_replay_time()
RETURNS VOID AS $$
  SELECT set_config('cardops.replay_time', '', true);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = cardops_now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
