-- Tenant session helpers

CREATE OR REPLACE FUNCTION set_tenant(p_tenant_id BIGINT) RETURNS VOID AS $$
  SELECT set_config('app.current_tenant', p_tenant_id::text, true);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION get_current_tenant() RETURNS BIGINT AS $$
  SELECT NULLIF(current_setting('app.current_tenant', true), '')::BIGINT;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION clear_tenant() RETURNS VOID AS $$
  SELECT set_config('app.current_tenant', '', true);
$$ LANGUAGE sql;
