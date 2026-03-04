# SQL-Native Operating Model

## Mandatory Patterns

1. Ingestion inbox (`event_inbox`) with idempotency keys
2. Rule-as-data (`risk_rules`) and threshold versioning
3. Snapshot-as-config (`config_snapshots`)
4. Decision-as-ledger (`decision_audit_log`)
5. Explainability-as-data (feature/value/weight/contribution records)
6. Integrity-as-hash-chain (`previous_hash`, `decision_hash`)
7. Tenancy-by-RLS (`tenant_id` isolation)
8. Formal state machine transitions for critical entities
9. DLQ and retry policies for failed processing paths

## Operating Cycle

1. Receive and validate events in inbox.
2. Materialize domain events and enqueue decision tasks.
3. Extract features and compute risk score.
4. Apply policy, guardrails and economic objective selection.
5. Persist decision with snapshot/model/hash references.
6. Record metrics, drift, anomaly and state transitions.
7. Support deterministic replay/backtesting for audit.

## Deterministic Replay Contract

Replay requests must include:

- `tenant_id`
- time range
- `snapshot_id`
- `model_version_id`
- threshold set version
- replay time context (`set_replay_time(...)`)

Outputs are expected to be identical under unchanged source data and configuration snapshot.
