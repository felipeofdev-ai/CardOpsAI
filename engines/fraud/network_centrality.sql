-- Merchant network centrality and influence scoring

CREATE OR REPLACE VIEW merchant_network_centrality AS
WITH degree_centrality AS (
  SELECT
    tenant_id,
    source_merchant AS merchant_id,
    COUNT(*)::NUMERIC AS out_degree,
    SUM(risk_link_score)::NUMERIC AS weighted_out_degree
  FROM merchant_risk_graph
  GROUP BY tenant_id, source_merchant
), in_degree AS (
  SELECT
    tenant_id,
    related_merchant AS merchant_id,
    COUNT(*)::NUMERIC AS in_degree
  FROM merchant_risk_graph
  GROUP BY tenant_id, related_merchant
)
SELECT
  d.tenant_id,
  d.merchant_id,
  d.out_degree,
  COALESCE(i.in_degree,0) AS in_degree,
  d.weighted_out_degree,
  ROUND((d.out_degree + COALESCE(i.in_degree,0)) * (1 + d.weighted_out_degree/100), 6) AS influence_score
FROM degree_centrality d
LEFT JOIN in_degree i
  ON i.tenant_id = d.tenant_id
 AND i.merchant_id = d.merchant_id
ORDER BY influence_score DESC;
