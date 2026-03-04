# Architecture

CardOpsAI is SQL-operational by design: ingestion, decisioning, replay, governance, and analytics execute in PostgreSQL.

## Tier-1 Layers

1. **Ingestion Layer**: `event_inbox` with idempotency/validation lifecycle
2. **Streaming Layer**: transaction/merchant/fraud/risk/decision event tables
3. **Queue/Resilience Layer**: decision queue, retry policies, DLQ, backpressure views
4. **Feature Layer**: registry/version/materialization/lineage + drift
5. **Scoring Layer**: feature extraction -> risk scoring -> decision policy
6. **Economic Layer**: objective optimization + guardrails + counterfactual lab
7. **Ledger Layer**: snapshot/model/hash-chained decisions + explainability
8. **State Layer**: formal state machines for transaction/merchant/risk entities
9. **Replay/Stress Layer**: deterministic replay time + simulation/backtesting
10. **Executive Layer**: capacity, capital forecast, regulatory outputs

## Runtime Primitives

- `LISTEN/NOTIFY`
- `pg_cron`
- recursive CTEs and window functions
- partitioning + BRIN + partial indexes
- advisory locks for queue workers

## Guarantee

Core risk operation remains functional without external backend services.
