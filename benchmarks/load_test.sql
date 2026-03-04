-- Load test baseline targets
-- Tier-1 performance targets:
-- 1) >= 5,000 TPS sustained
-- 2) decision latency p95 < 200ms
-- 3) fraud decision p99 < 300ms

EXPLAIN (ANALYZE, BUFFERS)
SELECT merchant_id, COUNT(*) AS declines_1h
FROM transactions
WHERE status = 'DECLINED'
  AND created_at >= NOW() - INTERVAL '1 hour'
GROUP BY merchant_id
ORDER BY declines_1h DESC
LIMIT 100;
