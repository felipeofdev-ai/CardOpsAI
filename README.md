<div align="center">

# CardOpsAI

### PostgreSQL-native Risk OS for payment infrastructure

[![SQL](https://img.shields.io/badge/SQL--first-Risk_OS-C9A86A?style=for-the-badge)](https://github.com/felipeofdev-ai/CardOpsAI)
[![Orbit](https://img.shields.io/badge/Portfolio-Orbit-5EC8C0?style=for-the-badge)](https://felipeofdev-ai.github.io/)

Deterministic replay · tamper-evident decision logs · multi-tenant RLS · economic optimization.

</div>

## Principles

- Deterministic replay (snapshot + model version bound decisions)  
- SQL-first core logic in PostgreSQL  
- SHA256 hash-chained decision ledger  
- Economic objective (revenue / fraud / capital / churn)  
- Multi-tenant isolation (RLS)

## Targets (design)

| Metric | Target |
|--------|--------|
| Throughput | ≥ 5k TPS sustained |
| Decision latency | p95 < 200ms |
| Fraud latency | p99 < 300ms |
| Replay | 30 days in < 4h |

## Architecture

```text
Event inbox → validation/idempotency → domain streams
→ features → risk score → policy → economic eval
→ decision ledger (hash chain)
→ observability / replay / stress
```

Author: [Felipe Fernandes](https://github.com/felipeofdev-ai) · [Orbit](https://felipeofdev-ai.github.io/)
