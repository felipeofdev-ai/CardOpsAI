# Changelog

All notable changes to CardOpsAI are documented here.

## [Unreleased] — Tier-0 Enterprise

### Added
- FastAPI OpenAPI server (`cardops_api.py`, `api/server.py`)
- Fortune 500 Risk Command Center dashboard (live API + demo fallback)
- Cost-sensitive alert triage with daily budget
- ML statistical challenger + hybrid scoring
- YAML policy import engine
- Shadow backtest batch runner
- Regulatory audit packet export
- Adverse action PDF generation
- Prometheus metrics view
- LISTEN/NOTIFY queue wakeup
- FK constraints, partition-ready tables, RLS on risk_rules
- Feature registry entries for velocity signals
- CI: unified Postgres 17, API smoke job

## [2.0.0] — Tier-1 Platform

- Velocity feature engine (`refresh_velocity_features`) for card/merchant rolling windows
- Explainable scoring API (`explain_transaction_risk`, `score_transaction`) with factor contributions
- Adverse action code catalogue for decline explainability
- Expected-loss alert triage (`alert_triage_queue`, `top_alerts_by_expected_loss`)
- Champion/challenger shadow mode (`run_shadow_score`, `shadow_divergence_report`)
- Geo-velocity / device-switch anomaly detector
- `system_health_panel` operator view
- CLI commands: `health`, `triage`, `score`, `shadow`, `velocity`
- Maturity docs: `ROADMAP.md`, `SECURITY.md`, `CONTRIBUTING.md`

### Added — Tier-1 platform layer

- Core entities: tenants, merchants, cards, enriched transactions
- Decision queue processor with `FOR UPDATE SKIP LOCKED`
- Ledger integrity verifier (`verify_decision_ledger_integrity`)
- Box-Muller Monte Carlo VaR/CVaR
- Docker Compose, Makefile, Pytest suite, Cursor agent rules
- Local ops dashboard (`docs/dashboard.html`)
- Professional README rewrite

## [Prior]

- SQL-native Risk OS modules (ingestion, features, state machines, economic lab, drift, contagion)
- Codespaces / CI SQL smoke baseline
