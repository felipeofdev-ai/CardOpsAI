-- CardOpsAI interview practice

-- 1) Tenant queue pressure
SELECT * FROM queue_backpressure ORDER BY pending_count DESC LIMIT 10;

-- 2) Drift breaches
SELECT * FROM drift_breaches ORDER BY recorded_at DESC LIMIT 20;

-- 3) Counterfactual ranking
SELECT * FROM counterfactual_ranking LIMIT 20;

-- 4) Network influence
SELECT * FROM merchant_network_centrality LIMIT 20;

-- 5) 12-month capital forecast
SELECT * FROM risk_capital_forecast_12m;
