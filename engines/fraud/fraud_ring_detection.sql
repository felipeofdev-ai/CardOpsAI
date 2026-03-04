-- Fraud ring detection via connected components approximation

CREATE OR REPLACE FUNCTION detect_fraud_rings(
  p_tenant_id BIGINT,
  p_min_size INT DEFAULT 3
)
RETURNS TABLE(cluster_id BIGINT, member_merchant BIGINT, cluster_size BIGINT) AS $$
BEGIN
  RETURN QUERY
  WITH RECURSIVE cc AS (
    SELECT
      source_merchant AS root,
      related_merchant AS member,
      1 AS depth
    FROM merchant_risk_graph
    WHERE tenant_id = p_tenant_id

    UNION

    SELECT
      cc.root,
      g.related_merchant,
      cc.depth + 1
    FROM cc
    JOIN merchant_risk_graph g
      ON g.source_merchant = cc.member
     AND g.tenant_id = p_tenant_id
    WHERE cc.depth < 10
  ), normalized AS (
    SELECT LEAST(root, member) AS cluster_id, member AS merchant_id
    FROM cc
  ), counted AS (
    SELECT cluster_id, merchant_id, COUNT(*) OVER (PARTITION BY cluster_id) AS size
    FROM normalized
  )
  SELECT DISTINCT cluster_id, merchant_id, size
  FROM counted
  WHERE size >= p_min_size
  ORDER BY size DESC, cluster_id, merchant_id;
END;
$$ LANGUAGE plpgsql;
