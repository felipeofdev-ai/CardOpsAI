-- Allow pytest/CLI to exercise RLS as a non-superuser app role
DO $$ BEGIN
  CREATE ROLE cardops_app WITH LOGIN PASSWORD 'cardops_app' NOINHERIT;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

GRANT USAGE ON SCHEMA public TO cardops_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO cardops_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO cardops_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO cardops_app;
DO $$ BEGIN
  GRANT cardops_app TO cardops;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;

CREATE OR REPLACE FUNCTION get_current_tenant() RETURNS BIGINT AS $$
  SELECT NULLIF(current_setting('app.current_tenant', true), '')::BIGINT;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION cardops_apply_tenant_rls(
  p_table REGCLASS,
  p_force BOOLEAN DEFAULT FALSE
) RETURNS VOID AS $$
DECLARE
  v_policy TEXT := 'tenant_isolation';
BEGIN
  EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY', p_table);
  IF p_force THEN
    EXECUTE format('ALTER TABLE %s FORCE ROW LEVEL SECURITY', p_table);
  END IF;
  EXECUTE format('DROP POLICY IF EXISTS %I ON %s', v_policy, p_table);
  EXECUTE format('DROP POLICY IF EXISTS decision_tenant_isolation ON %s', p_table);
  EXECUTE format(
    'CREATE POLICY %I ON %s FOR ALL USING (tenant_id = get_current_tenant()) WITH CHECK (tenant_id = get_current_tenant())',
    v_policy, p_table
  );
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  IF to_regclass('public.merchants') IS NOT NULL THEN
    PERFORM cardops_apply_tenant_rls('merchants', FALSE);
  END IF;
  IF to_regclass('public.cards') IS NOT NULL THEN
    PERFORM cardops_apply_tenant_rls('cards', FALSE);
  END IF;
  IF to_regclass('public.transactions') IS NOT NULL THEN
    PERFORM cardops_apply_tenant_rls('transactions', FALSE);
  END IF;
  IF to_regclass('public.decision_queue') IS NOT NULL THEN
    PERFORM cardops_apply_tenant_rls('decision_queue', FALSE);
  END IF;
  IF to_regclass('public.event_inbox') IS NOT NULL THEN
    PERFORM cardops_apply_tenant_rls('event_inbox', FALSE);
  END IF;
  IF to_regclass('public.merchant_risk_graph') IS NOT NULL THEN
    PERFORM cardops_apply_tenant_rls('merchant_risk_graph', FALSE);
  END IF;
  IF to_regclass('public.decision_audit_log') IS NOT NULL THEN
    PERFORM cardops_apply_tenant_rls('decision_audit_log', TRUE);
  END IF;
  IF to_regclass('public.risk_rules') IS NOT NULL THEN
    PERFORM cardops_apply_tenant_rls('risk_rules', FALSE);
  END IF;
  IF to_regclass('public.policy_documents') IS NOT NULL THEN
    PERFORM cardops_apply_tenant_rls('policy_documents', FALSE);
  END IF;
  IF to_regclass('public.alert_budget_config') IS NOT NULL THEN
    PERFORM cardops_apply_tenant_rls('alert_budget_config', FALSE);
  END IF;
  IF to_regclass('public.alert_budget_usage') IS NOT NULL THEN
    PERFORM cardops_apply_tenant_rls('alert_budget_usage', FALSE);
  END IF;
  IF to_regclass('public.shadow_backtest_runs') IS NOT NULL THEN
    PERFORM cardops_apply_tenant_rls('shadow_backtest_runs', FALSE);
  END IF;
  IF to_regclass('public.regulatory_exports') IS NOT NULL THEN
    PERFORM cardops_apply_tenant_rls('regulatory_exports', FALSE);
  END IF;
  IF to_regclass('public.shadow_decision_log') IS NOT NULL THEN
    PERFORM cardops_apply_tenant_rls('shadow_decision_log', FALSE);
  END IF;
END $$;

ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON tenants;
CREATE POLICY tenant_isolation ON tenants
  FOR ALL
  USING (id = get_current_tenant())
  WITH CHECK (id = get_current_tenant());
