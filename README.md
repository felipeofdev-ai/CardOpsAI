# CardOpsAI

**PostgreSQL-native Risk Operating System for Payment Infrastructure**

CardOpsAI is a SQL-first platform for risk decisioning, replay, compliance, and economic optimization in payment ecosystems.

## System Principles

- Deterministic replay (snapshot + model version bound decisions)
- SQL-first architecture (core logic in PostgreSQL)
- Tamper-evident decision logs (SHA256 hash chain)
- Economic optimization (revenue/fraud/capital/churn objective)
- Multi-tenant isolation (RLS + tenant-scoped execution)

## Operational Guarantees

- Throughput target: **>= 5k TPS** sustained
- Decision latency target: **p95 < 200ms**
- Fraud latency target: **p99 < 300ms**
- Replay capacity target: **30 days in < 4h**
- Tamper detection: **chained SHA256 hash ledger**

## Architecture (SQL Native)

```text
Event Ingestion (event_inbox)
          |
          v
Validation + Idempotency
          |
          v
Domain Event Streams (transaction/merchant/fraud/risk/decision_events)
          |
          v
Feature Extraction -> Risk Scoring -> Decision Policy -> Economic Evaluation
          |
          v
Decision Ledger (snapshot_id + model_version_id + hash chain)
          |
     +----+-------------------+
     |                        |
     v                        v
Observability/Drift      Replay/Backtesting/Stress
     |                        |
     +-----------+------------+
                 |
                 v
        Executive & Regulatory Outputs
```

## Implemented Tier-1 Components

### Event Stream + Ingestion Layer
- `event_inbox` with idempotency keys and status lifecycle
- Domain streams: `transaction_events`, `merchant_events`, `fraud_events`, `risk_events`, `decision_events`
- Real-time work scheduling via `decision_queue`

### Feature Store Versioning + Lineage
- `feature_registry`
- `feature_versions` with SQL definition/version/owner
- `feature_materializations` snapshot compatibility and checksums
- `feature_drift_scores`

### Threshold + Model Governance
- `risk_thresholds` and `threshold_sets`
- `model_registry`, `model_versions`, `model_deployments`
- `config_snapshots` for deterministic replay boundaries

### Explainability + Integrity
- `decision_explanations` with factors
- `compute_decision_hash()` and `append_tamper_evident_decision()`
- `incident_ledger` append-only operations

### Risk/Economic Engines
- Risk scoring pipeline views (`v_feature_extraction`, `v_risk_scoring`, `v_decision_policy`)
- Policy simulator (`simulate_policy()`)
- Economic objective optimizer (`decision_profit_scores`, `best_decision_candidate`)
- Fraud velocity and temporal pattern engines
- Risk contagion propagation and fraud ring detection
- Liquidity shock + revenue-at-risk projections

### Observability + Capacity
- Latency, approval, chargeback, rule-hit, anomaly metric tables
- Benchmarks for load and replay performance
- Capacity model documentation

## Repository Structure

```text
CardOpsAI/
├── database/
│   ├── schema/
│   │   ├── cardops_os.sql
│   │   ├── tier1_extensions.sql
│   │   ├── event_ingestion.sql
│   │   ├── feature_store.sql
│   │   ├── threshold_registry.sql
│   │   ├── model_registry.sql
│   │   ├── observability.sql
│   │   ├── risk_state_machine.sql
│   │   ├── resilience_controls.sql
│   │   ├── tenant_limits.sql
│   │   └── economic_guardrails.sql
│   └── rls-policies/
│       └── multi_tenant_rls.sql
├── engines/
│   ├── decision/
│   │   ├── risk_scoring_pipeline.sql
│   │   └── policy_simulator.sql
│   ├── analytics/
│   │   └── statistical_validation.sql
│   └── fraud/
│       ├── fraud_ring_detection.sql
│       ├── temporal_patterns.sql
│       └── network_centrality.sql
├── features/
│   ├── registry/
│   └── materialization/
│       └── merchant_behavior_baseline.sql
├── snapshots/
│   ├── config_snapshot_engine.sql
│   └── replay/
│       ├── deterministic_time.sql
│       └── replay_engine.sql
├── drift/
├── economic/
│   ├── optimization_engine.sql
│   ├── counterfactual_engine.sql
│   └── risk_capital_forecast.sql
├── stress/
├── engines/resilience/
│   └── self_healing_thresholds.sql
├── benchmarks/
└── docs/
    ├── architecture.md
    ├── capacity-model.md
    ├── economic-model.md
    ├── compliance.md
    ├── executive-metrics.md
    ├── risk-model.md
    └── sql-native-operating-model.md
```



## 9.9 Excellence Additions

- Formal state machine (`state_definitions`, `state_transitions`, `*_state_log`) with validated transitions.
- Backpressure resilience (`retry_policy`, `processing_failures`, `dead_letter_queue`, `queue_backpressure`).
- Deterministic replay-time controls (`cardops_now()`, `set_replay_time()`, `clear_replay_time()`).
- Per-tenant resource limits (`tenant_limits`, `tenant_usage_metrics`, `tenant_limit_breaches`).
- Continuous statistical validation (PSI, KS, ROC recalculation).
- Economic guardrails (`min_approval_rate`, `max_chargeback_rate`, `max_capital_usage`).
- Counterfactual lab with policy ranking (`run_counterfactual`, `counterfactual_ranking`).
- Self-healing thresholds (`auto_adjust_threshold`) with audit log.
- Network centrality influence scoring for merchant risk concentration.
- 12-month risk capital forecast for CFO planning.

## License

Apache License 2.0 (`LICENSE`).
