-- Document velocity + ML features in feature_registry

INSERT INTO feature_registry (feature_name, domain, owner, description)
VALUES
  ('tx_count_1h', 'velocity', 'velocity_engine', 'Merchant tx count trailing 1h'),
  ('tx_count_24h', 'velocity', 'velocity_engine', 'Merchant tx count trailing 24h'),
  ('tx_count_7d', 'velocity', 'velocity_engine', 'Merchant tx count trailing 7d'),
  ('amount_spike_ratio', 'velocity', 'velocity_engine', 'Max vs 7d avg ticket ratio'),
  ('ml_anomaly_score', 'scoring', 'ml_challenger', 'Statistical anomaly score 0-100'),
  ('hybrid_score', 'scoring', 'ml_challenger', '65% rules + 35% ML blend')
ON CONFLICT (feature_name) DO UPDATE SET
  description = EXCLUDED.description,
  owner = EXCLUDED.owner;
