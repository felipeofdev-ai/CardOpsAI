<div align="center">

# CardOpsAI

### PostgreSQL-native Risk OS for payment infrastructure

[![SQL](https://img.shields.io/badge/SQL--first-Risk_OS-C9A86A?style=for-the-badge)](https://github.com/felipeofdev-ai/CardOpsAI)
[![Orbit](https://img.shields.io/badge/Portfolio-Orbit-5EC8C0?style=for-the-badge)](https://felipeofdev-ai.github.io/)
[![Live Demo](https://img.shields.io/badge/Live_Demo-Labs-5EC8C0?style=for-the-badge)](https://felipeofdev-ai.github.io/labs/cardopsai/)


Deterministic replay Â· tamper-evident decision logs Â· multi-tenant RLS Â· economic optimization.

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
| Throughput | â‰¥ 5k TPS sustained |
| Decision latency | p95 < 200ms |
| Fraud latency | p99 < 300ms |
| Replay | 30 days in < 4h |

## Architecture

```text
Event inbox â†’ validation/idempotency â†’ domain streams
â†’ features â†’ risk score â†’ policy â†’ economic eval
â†’ decision ledger (hash chain)
â†’ observability / replay / stress
```

Author: [Felipe Fernandes](https://github.com/felipeofdev-ai) Â· [Orbit](https://felipeofdev-ai.github.io/)

---

## Live demo

**Try it in the browser (no clone):** see badge / homepage above, or the [Labs hub](https://felipeofdev-ai.github.io/labs/).

## Constellation

| Project | Demo |
|---------|------|
| [CardOpsAI](https://github.com/felipeofdev-ai/CardOpsAI) | [lab](https://felipeofdev-ai.github.io/labs/cardopsai/) |
| [BridgeTrace-AI](https://github.com/felipeofdev-ai/BridgeTrace-AI) | [lab](https://felipeofdev-ai.github.io/labs/bridgetrace/) |
| [Meridian](https://github.com/felipeofdev-ai/Meridian) | [lab](https://felipeofdev-ai.github.io/labs/meridian/) |
| [TrustHire](https://github.com/felipeofdev-ai/trusthire) | [lab](https://felipeofdev-ai.github.io/labs/trusthire/) |
| [secure-ship-kit](https://github.com/felipeofdev-ai/secure-ship-kit) | [lab](https://felipeofdev-ai.github.io/labs/secure-ship-kit/) |
| [agentic-rag-cite](https://github.com/felipeofdev-ai/agentic-rag-cite) | [lab](https://felipeofdev-ai.github.io/labs/agentic-rag-cite/) |
| [hitl-langgraph-kit](https://github.com/felipeofdev-ai/hitl-langgraph-kit) | [lab](https://felipeofdev-ai.github.io/labs/hitl-langgraph-kit/) |
| [forge-mcp-server](https://github.com/felipeofdev-ai/forge-mcp-server) | [lab](https://felipeofdev-ai.github.io/labs/forge-mcp-server/) |
| [agent-eval-harness](https://github.com/felipeofdev-ai/agent-eval-harness) | [lab](https://felipeofdev-ai.github.io/labs/agent-eval-harness/) |
| [lgpd-checklist-agent](https://github.com/felipeofdev-ai/lgpd-checklist-agent) | [lab](https://felipeofdev-ai.github.io/labs/lgpd-checklist-agent/) |
| [hiring-packet](https://github.com/felipeofdev-ai/hiring-packet) | [lab](https://felipeofdev-ai.github.io/labs/hiring-packet/) |
| [philo-ai-os](https://github.com/felipeofdev-ai/philo-ai-os) | [lab](https://felipeofdev-ai.github.io/labs/philo-ai-os/) |
| [balcaoia-local](https://github.com/felipeofdev-ai/balcaoia-local) | [studio](https://balcaoia-studio.vercel.app) |

Portfolio: [felipeofdev-ai.github.io](https://felipeofdev-ai.github.io/) · Author: Felipe Fernandes · `felipe.of.dev@gmail.com`

> If this helped you, **star this repo** — organic only. No bots, no paid stars.