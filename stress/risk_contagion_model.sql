-- Risk contagion propagation with temporal decay

CREATE OR REPLACE FUNCTION run_risk_contagion(
  p_iterations INT DEFAULT 5,
  p_decay_factor NUMERIC DEFAULT 0.85
)
RETURNS TABLE(merchant_id BIGINT, propagated_score NUMERIC) AS $$
BEGIN
  RETURN QUERY
  WITH RECURSIVE propagation AS (
    SELECT
      source_merchant::BIGINT AS merchant_id,
      AVG(risk_link_score)::NUMERIC AS score,
      1 AS iter
    FROM merchant_risk_graph
    GROUP BY source_merchant

    UNION ALL

    SELECT
      g.related_merchant::BIGINT AS merchant_id,
      (p.score + (g.risk_link_score * p_decay_factor))::NUMERIC AS score,
      p.iter + 1
    FROM propagation p
    JOIN merchant_risk_graph g
      ON g.source_merchant = p.merchant_id
    WHERE p.iter < p_iterations
  )
  SELECT merchant_id, ROUND(AVG(score), 4) AS propagated_score
  FROM propagation
  GROUP BY merchant_id
  ORDER BY propagated_score DESC;
END;
$$ LANGUAGE plpgsql;
