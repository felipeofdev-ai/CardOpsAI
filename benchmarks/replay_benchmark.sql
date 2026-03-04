-- Replay benchmark target
-- Reprocess 30 days of decisions in < 4 hours

EXPLAIN (ANALYZE, BUFFERS)
SELECT
  tenant_id,
  COUNT(*) AS decisions_30d,
  MIN(created_at) AS from_ts,
  MAX(created_at) AS to_ts
FROM decision_audit_log
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY tenant_id
ORDER BY decisions_30d DESC;
