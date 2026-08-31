# ROADMAP

Prioritized evolution plan for CardOpsAI, informed by patterns in mature open-source
fraud/risk systems (expected-loss triage, velocity features, champion/challenger,
explainability, geo-velocity, drift gates).

## Completed (this release)

- [x] Core tenants / merchants / cards / transactions
- [x] Decision queue with `SKIP LOCKED`
- [x] SHA-256 hash-chained ledger + integrity verifier
- [x] Multi-tenant RLS
- [x] Config snapshots + deterministic clock
- [x] Box-Muller Monte Carlo VaR/CVaR
- [x] Fraud ring detection
- [x] Docker Compose + CLI + Pytest + CI
- [x] Velocity feature materialization (1h / 24h / 7d)
- [x] Expected-loss alert triage
- [x] Explainability factors + adverse action codes
- [x] Champion / challenger shadow scoring
- [x] Geo-velocity / device-switch heuristics
- [x] System health panel

## Next (near-term)

- [ ] Partition `transactions` and `decision_audit_log` by time
- [ ] LISTEN/NOTIFY worker wakeup for queue drain
- [ ] Formal feature registry entries for every velocity signal
- [ ] Cost-sensitive threshold optimizer (false-decline vs fraud loss)
- [ ] Export OpenMetrics / Prometheus endpoint (SQL views + thin exporter)
- [ ] Shadow backtest batch job over N days of history

## Later (portfolio / research)

- [ ] Optional ML challenger lane (Isolation Forest / GBM) behind the same score API
- [ ] Graph embeddings for merchant rings (still SQL-exportable features)
- [ ] Regulatory packet generator (adverse action letter draft from codes)
- [ ] Multi-region read replicas for replay labs
