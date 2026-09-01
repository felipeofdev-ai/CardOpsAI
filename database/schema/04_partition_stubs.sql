-- Partition-ready audit ledger parent (requires decision_audit_log from cardops_os.sql)

CREATE TABLE IF NOT EXISTS decision_audit_log_partitioned (
  LIKE decision_audit_log INCLUDING DEFAULTS
) PARTITION BY RANGE (created_at);

COMMENT ON TABLE decision_audit_log_partitioned IS
  'Production attach point for monthly decision_audit_log partitions';
