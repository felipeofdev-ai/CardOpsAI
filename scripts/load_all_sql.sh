#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-cardops}"
DB_NAME="${DB_NAME:-cardops_db}"
export PGPASSWORD="${PGPASSWORD:-cardops_secret}"

# Prefer CARDOPS_DSN when provided
PSQL=(psql -v ON_ERROR_STOP=1)
if [[ -n "${CARDOPS_DSN:-}" ]]; then
  PSQL=(psql "$CARDOPS_DSN" -v ON_ERROR_STOP=1)
else
  PSQL=(psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME")
fi

if [[ "${1:-}" == "--inside-docker" ]]; then
  ROOT="/sql"
  PSQL=(psql -U cardops -d cardops_db -v ON_ERROR_STOP=1)
fi

run_sql() {
  local f="$1"
  echo "==> Applying ${f}"
  "${PSQL[@]}" -f "$ROOT/$f"
}

# 0) Clock + core entities (before OS modules that assume transactions)
run_sql database/schema/00_extensions_and_clock.sql
run_sql database/schema/01_core_entities.sql
# Keep stub as no-op upgrade path for older docs/CI references
run_sql database/schema/ci_transactions_stub.sql

# 1) Base OS schemas
run_sql database/schema/cardops_os.sql
run_sql database/schema/event_ingestion.sql
run_sql database/schema/feature_store.sql
run_sql database/schema/threshold_registry.sql
run_sql database/schema/model_registry.sql
run_sql database/schema/observability.sql
run_sql database/schema/tier1_extensions.sql
run_sql database/schema/risk_state_machine.sql
run_sql database/schema/resilience_controls.sql
run_sql database/schema/tenant_limits.sql
run_sql database/schema/economic_guardrails.sql

# 2) Functions
run_sql database/functions/set_tenant.sql
run_sql database/functions/hash_chain.sql

# 3) Snapshots / replay
run_sql snapshots/config_snapshot_engine.sql
run_sql snapshots/replay/deterministic_time.sql
run_sql snapshots/replay/replay_engine.sql

# 4) Engines (original + Tier-1 operational)
run_sql engines/scoring/risk_score_engine.sql
run_sql engines/decision/decision_processor.sql
run_sql engines/decision/risk_scoring_pipeline.sql
run_sql engines/decision/policy_simulator.sql
run_sql engines/fraud/fraud_ring_detection.sql
run_sql engines/fraud/temporal_patterns.sql
run_sql engines/fraud/network_centrality.sql
run_sql engines/analytics/statistical_validation.sql
run_sql engines/resilience/self_healing_thresholds.sql
run_sql engines/economic/counterfactual_engine.sql
run_sql engines/economic/risk_capital_forecast.sql

# 5) Supporting modules
run_sql features/materialization/merchant_behavior_baseline.sql
run_sql engines/features/velocity_engine.sql
run_sql engines/decision/explainability_and_triage.sql
run_sql engines/decision/champion_challenger.sql
run_sql drift/drift_detection.sql
run_sql engines/fraud/geo_velocity.sql
run_sql economic/optimization_engine.sql
run_sql stress/fraud_velocity_engine.sql
run_sql stress/monte_carlo_engine.sql
run_sql stress/box_muller_monte_carlo.sql
run_sql stress/risk_contagion_model.sql

# 6) Seed then security (seed disables RLS temporarily)
if [[ "${SKIP_SEED:-0}" != "1" ]]; then
  run_sql database/seeds/synthetic_seed.sql
fi
run_sql database/rls-policies/multi_tenant_rls.sql

echo "✅ CardOpsAI SQL stack applied successfully"
