-- Multi-tenant isolation baseline

ALTER TABLE decision_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS decision_tenant_isolation ON decision_audit_log;
CREATE POLICY decision_tenant_isolation
ON decision_audit_log
USING (tenant_id = current_setting('app.current_tenant', true)::BIGINT);

-- Optional hardening:
-- ALTER TABLE decision_audit_log FORCE ROW LEVEL SECURITY;
