<div align="center">

# CardOpsAI

### PostgreSQL-native Risk Operating System for payment infrastructure

[![CI](https://img.shields.io/github/actions/workflow/status/felipeofdev-ai/CardOpsAI/ci.yml?branch=main&style=for-the-badge&label=CI)](https://github.com/felipeofdev-ai/CardOpsAI/actions)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue?style=for-the-badge)](LICENSE)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16%2F17-336791?style=for-the-badge&logo=postgresql&logoColor=white)](docker-compose.yml)
[![SQL-first](https://img.shields.io/badge/Architecture-SQL--first-C9A86A?style=for-the-badge)](docs/architecture.md)
[![Live Demo](https://img.shields.io/badge/Live_Demo-Labs-5EC8C0?style=for-the-badge)](https://felipeofdev-ai.github.io/labs/cardopsai/)

**Deterministic replay · Tamper-evident ledger · Multi-tenant RLS · Economic counterfactuals · Monte Carlo capital stress**

[Quick Start](#quick-start) · [Architecture](#architecture) · [Capabilities](#what-makes-this-real) · [CLI](#operational-cli) · [Docs](#documentation)

</div>

---

## Why CardOpsAI

Most “risk demos” are notebooks, mocks, or API wrappers around logic that disappears the moment the container stops.

**CardOpsAI is different:** the risk operating system *is* the database.

Scoring, queue processing, fraud-ring detection, config snapshots, counterfactual replay, hash-chained audit, and Monte Carlo stress all run as **real PostgreSQL functions and tables** — idempotent, testable, and operable from a CLI without an application server.

| What teams usually ship | What CardOpsAI ships |
|-------------------------|----------------------|
| Python scripts that *call* a DB | SQL engines that *are* the control plane |
| Screenshots of dashboards | Runnable ledger + integrity verifier |
| “TODO: add tenancy” | RLS policies on tenant-scoped tables |
| Fake stress charts | Box-Muller VaR 95/99 + CVaR in SQL |
| Irreproducible decisions | Snapshot-bound, clock-controllable replay |

Built for engineers who evaluate systems by **artifacts that execute**, not by slide decks.

---

## What makes this real

### 1. SQL-native decision path
Inbound work lands in `event_inbox` / `decision_queue`, is claimed with `FOR UPDATE SKIP LOCKED`, scored by weighted rules, written to `transactions`, and sealed into `decision_audit_log`.

```text
event_inbox → decision_queue → compute_risk_score()
           → process_decision_queue()
           → append_tamper_evident_decision()
           → SHA-256 hash chain
```

### 2. Tamper-evident decision ledger
Every sealed decision stores `previous_hash`, `decision_hash`, and the canonical `payload`.  
`verify_decision_ledger_integrity()` walks the chain per tenant and reports the first broken block — the same class of control auditors expect from financial ledgers.

### 3. Multi-tenant isolation
Tenant context flows through `set_tenant()` / `app.current_tenant`. Core tables carry `tenant_id` and RLS policies. The audit ledger can run under **FORCE ROW LEVEL SECURITY** so isolation is not optional for the most sensitive trail.

### 4. Deterministic time & replay
`cardops_now()` honors `cardops.replay_time` and `cardops.mock_now`, enabling reproducible backtests. Config fingerprints are captured by `create_config_snapshot()`; policy what-ifs run through the counterfactual lab.

### 5. Fraud network intelligence
`detect_fraud_rings()` explores `merchant_risk_graph` with recursive CTEs to surface connected merchant clusters — not a hardcoded demo list.

### 6. Capital stress that is mathematically honest
`run_monte_carlo_stress()` implements the **Box-Muller** transform in pure SQL and returns VaR 95%, VaR 99%, CVaR (expected shortfall), and a recommended capital reserve. Liquidity shock views remain available alongside it.

### 7. Operable surface area
Not just SQL files in a folder:

- **Docker Compose** — Postgres 17 + Adminer
- **CLI** — status, audit, stress, rings, process, snapshot, simulate, **health, triage, score, shadow, velocity**
- **Pytest** — ledger integrity, RLS, Monte Carlo, engines, ops intelligence
- **CI** — SQL smoke + pytest pipeline
- **Local ops dashboard** — `docs/dashboard.html`
- **Cursor agent rules** — `.cursor/rules` + prompts for safe schema/risk workflows

### 8. Ops intelligence (industry-aligned)
Features commonly found in mature fraud platforms — implemented SQL-native:

| Capability | Inspiration | CardOpsAI artifact |
|------------|-------------|--------------------|
| Rolling velocity / spikes | FraudShield, Fraud-Detection-Engine | `refresh_velocity_features()` |
| Expected-loss triage | [transaction-fraud-scoring](https://github.com/gbadedata/transaction-fraud-scoring) | `alert_triage_queue` |
| Explainability + adverse codes | [SentryFlow](https://github.com/joewynn/sentryflow-risk-policy-engine) | `score_transaction()` |
| Champion / challenger | Policy engines / shadow deploys | `run_shadow_score()` |
| Geo / device velocity | BankShield-style geo-risk | `detect_geo_velocity_anomalies()` |
| Drift gates | PSI/KS analytics already in-repo | `compute_psi`, `drift_breaches` |

See [`ROADMAP.md`](ROADMAP.md) for what is done vs next.

---

## Architecture

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                         CardOpsAI Risk OS                               │
├──────────────┬──────────────┬──────────────┬────────────────────────────┤
│  Ingestion   │  Decisioning │  Governance  │  Stress & Economics        │
│  event_inbox │  scoring     │  snapshots   │  Monte Carlo VaR/CVaR      │
│  streams     │  queue       │  hash ledger │  liquidity / contagion     │
│  idempotency │  policy      │  RLS / audit │  counterfactual lab        │
├──────────────┴──────────────┴──────────────┴────────────────────────────┤
│                     PostgreSQL 16/17 (system of record)                 │
│         cardops_now() · set_tenant() · SKIP LOCKED · pgcrypto           │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    cardops_cli.py  │  docs/dashboard.html  │  CI
```

**Tier-1 layers** (see [`docs/architecture.md`](docs/architecture.md)):

1. Ingestion & idempotency  
2. Domain event streams  
3. Queue / retries / resilience  
4. Feature registry & materialization  
5. Risk scoring & policy  
6. Economic objectives & guardrails  
7. Hash-chained ledger & explainability  
8. Entity state machines  
9. Deterministic replay & stress  
10. Executive / capital / capacity views  

**Design targets** (engineering goals for capacity planning — not marketing SLAs):

| Metric | Target |
|--------|--------|
| Sustained throughput | ≥ 5k TPS (design) |
| Decision latency | p95 < 200 ms (design) |
| Fraud path latency | p99 < 300 ms (design) |
| 30-day replay window | < 4 h (design) |

---

## Quick start

### Prerequisites
- Docker Desktop (or compatible engine)
- Python 3.11+
- Git

### Three commands to a live Risk OS

```bash
git clone https://github.com/felipeofdev-ai/CardOpsAI.git
cd CardOpsAI
docker compose up -d
```

First boot applies the full SQL stack and synthetic seed via `scripts/docker-init.sh`.

```bash
pip install -r requirements.txt
python cardops_cli.py status
pytest -q
```

| Surface | URL / path |
|---------|------------|
| Adminer | http://localhost:8080 |
| Local ops dashboard | [`docs/dashboard.html`](docs/dashboard.html) |
| Live lab (no clone) | [felipeofdev-ai.github.io/labs/cardopsai](https://felipeofdev-ai.github.io/labs/cardopsai/) |

Default local DSN:

```text
postgresql://cardops:cardops_secret@localhost:5432/cardops_db
```

Reload schema + seed anytime:

```bash
make db-seed
# or
bash scripts/load_all_sql.sh
```

---

## Operational CLI

```bash
python cardops_cli.py status                                  # health, queue, active rules, snapshot
python cardops_cli.py health                                  # single-pane system health panel
python cardops_cli.py audit                                   # verify SHA-256 ledger integrity
python cardops_cli.py process --batch-size 100                # drain decision queue
python cardops_cli.py rings --min-size 3                      # merchant fraud clusters
python cardops_cli.py stress --iterations 5000 --horizon 30   # VaR / CVaR capital metrics
python cardops_cli.py snapshot                                # fingerprint active risk config
python cardops_cli.py simulate --rule-id 1 --new-threshold 40 # counterfactual policy run
python cardops_cli.py velocity                                # refresh rolling velocity features
python cardops_cli.py triage --limit 25                       # alerts ranked by expected loss
python cardops_cli.py score --tx-id 123                       # explainable score + adverse codes
python cardops_cli.py shadow --tx-id 123 --challenger-threshold 35
```

All commands talk directly to PostgreSQL. No hidden microservice. No mock server.

---

## Repository map

```text
CardOpsAI/
├── database/
│   ├── schema/           # Core entities + OS modules (ingestion, features, state, …)
│   ├── functions/        # set_tenant, ledger verify
│   ├── rls-policies/     # Multi-tenant isolation
│   └── seeds/            # Synthetic multi-merchant demo data
├── engines/
│   ├── scoring/          # compute_risk_score
│   ├── decision/         # queue processor + policy simulator
│   ├── fraud/            # rings, temporal, centrality
│   ├── economic/         # counterfactual + capital forecast
│   └── …
├── snapshots/            # Config Merkle-style fingerprints + replay clock
├── stress/               # Box-Muller Monte Carlo + liquidity + contagion
├── tests/                # Pytest: ledger, RLS, engines, VaR invariants
├── docs/                 # Architecture, models, local dashboard
├── .cursor/              # Agent rules & risk-ops prompts
├── cardops_cli.py        # Operator CLI
└── docker-compose.yml    # Postgres 17 + Adminer
```

---

## Security & integrity model

| Control | Implementation |
|---------|----------------|
| Tenant isolation | `tenant_id` + RLS (`set_tenant` / `get_current_tenant`) |
| Sensitive card data | `card_hash` only (SHA-256) — raw PAN never stored |
| Decision auditability | Hash-chained `decision_audit_log` with stored payload |
| Tamper detection | `verify_decision_ledger_integrity()` |
| Deterministic replay | `cardops_now()` + config snapshots |
| Idempotent DDL | `IF NOT EXISTS` / `OR REPLACE` across the stack |

This is the posture of a system meant to be **reviewed**, not merely demoed.

---

## Testing & CI

```bash
make test          # pytest
make audit         # ledger check via CLI
make stress        # Monte Carlo smoke
make cli-status    # operator health view
```

GitHub Actions runs:

1. **SQL smoke** — full stack apply on PostgreSQL  
2. **Pytest** — integrity, tenancy, engines, Monte Carlo invariants  

---

## Documentation

| Document | Purpose |
|----------|---------|
| [`docs/architecture.md`](docs/architecture.md) | Layered OS design |
| [`docs/risk-model.md`](docs/risk-model.md) | Risk semantics |
| [`docs/economic-model.md`](docs/economic-model.md) | Revenue / fraud / capital / churn |
| [`docs/capacity-model.md`](docs/capacity-model.md) | Throughput & capacity thinking |
| [`docs/compliance.md`](docs/compliance.md) | Control narrative |
| [`docs/dashboard.html`](docs/dashboard.html) | Local interactive ops UI |
| [`ROADMAP.md`](ROADMAP.md) | What shipped vs what’s next |
| [`SECURITY.md`](SECURITY.md) | Vulnerability reporting & model |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | How to contribute safely |
| [`CHANGELOG.md`](CHANGELOG.md) | Release notes |

---

## Design principles

1. **Database is the runtime** — core risk logic does not depend on a custom app server.  
2. **Every decision must be reconstructible** — snapshot + features + rules + clock.  
3. **Integrity over theater** — hash chains you can break and detect in tests.  
4. **Economics are first-class** — approve/decline is not enough; capital and counterfactuals matter.  
5. **Multi-tenancy is a schema concern** — not a middleware afterthought.  
6. **CLI first, UI second** — operators should be productive in a terminal before opening a browser.

---

## Constellation

Part of the [Orbit](https://felipeofdev-ai.github.io/) systems portfolio:

| Project | Focus | Demo |
|---------|-------|------|
| **[CardOpsAI](https://github.com/felipeofdev-ai/CardOpsAI)** | SQL-first card risk OS | [lab](https://felipeofdev-ai.github.io/labs/cardopsai/) |
| [BridgeTrace-AI](https://github.com/felipeofdev-ai/BridgeTrace-AI) | Traceability | [lab](https://felipeofdev-ai.github.io/labs/bridgetrace/) |
| [Meridian](https://github.com/felipeofdev-ai/Meridian) | Systems design | [lab](https://felipeofdev-ai.github.io/labs/meridian/) |
| [TrustHire](https://github.com/felipeofdev-ai/trusthire) | Hiring integrity | [lab](https://felipeofdev-ai.github.io/labs/trusthire/) |
| [secure-ship-kit](https://github.com/felipeofdev-ai/secure-ship-kit) | Secure delivery | [lab](https://felipeofdev-ai.github.io/labs/secure-ship-kit/) |
| [agentic-rag-cite](https://github.com/felipeofdev-ai/agentic-rag-cite) | Cited RAG | [lab](https://felipeofdev-ai.github.io/labs/agentic-rag-cite/) |
| [hitl-langgraph-kit](https://github.com/felipeofdev-ai/hitl-langgraph-kit) | Human-in-the-loop agents | [lab](https://felipeofdev-ai.github.io/labs/hitl-langgraph-kit/) |
| [forge-mcp-server](https://github.com/felipeofdev-ai/forge-mcp-server) | MCP tooling | [lab](https://felipeofdev-ai.github.io/labs/forge-mcp-server/) |
| [agent-eval-harness](https://github.com/felipeofdev-ai/agent-eval-harness) | Agent evaluation | [lab](https://felipeofdev-ai.github.io/labs/agent-eval-harness/) |
| [lgpd-checklist-agent](https://github.com/felipeofdev-ai/lgpd-checklist-agent) | LGPD controls | [lab](https://felipeofdev-ai.github.io/labs/lgpd-checklist-agent/) |
| [hiring-packet](https://github.com/felipeofdev-ai/hiring-packet) | Hiring packets | [lab](https://felipeofdev-ai.github.io/labs/hiring-packet/) |
| [philo-ai-os](https://github.com/felipeofdev-ai/philo-ai-os) | Philosophical OS | [lab](https://felipeofdev-ai.github.io/labs/philo-ai-os/) |
| [balcaoia-local](https://github.com/felipeofdev-ai/balcaoia-local) | Local AI studio | [studio](https://balcaoia-studio.vercel.app) |

---

## Author

**Felipe Fernandes** · [Orbit](https://felipeofdev-ai.github.io/)  
GitHub: [@felipeofdev-ai](https://github.com/felipeofdev-ai) · `felipe.of.dev@gmail.com`

---

## License

Licensed under the [Apache License 2.0](LICENSE).

---

<div align="center">

If CardOpsAI helps you reason about real payment risk systems — **star the repo**.  
Organic interest only. No bots. No paid stars.

</div>
