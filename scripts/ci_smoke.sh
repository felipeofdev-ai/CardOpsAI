#!/usr/bin/env bash
# CI smoke: apply core SQL stack; skip modules with unresolved cross-schema deps.
set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-cardops}"
export PGPASSWORD="${PGPASSWORD:-postgres}"

run_sql() {
  local f="$1"
  echo "==> Applying ${f}"
  psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$f"
}

run_sql database/schema/cardops_os.sql
run_sql database/schema/ci_transactions_stub.sql
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
run_sql database/rls-policies/multi_tenant_rls.sql
run_sql snapshots/config_snapshot_engine.sql
run_sql snapshots/replay/deterministic_time.sql
run_sql snapshots/replay/replay_engine.sql
run_sql engines/decision/risk_scoring_pipeline.sql
run_sql engines/decision/policy_simulator.sql
run_sql engines/fraud/fraud_ring_detection.sql
run_sql engines/fraud/temporal_patterns.sql
run_sql engines/fraud/network_centrality.sql
run_sql engines/analytics/statistical_validation.sql
run_sql engines/resilience/self_healing_thresholds.sql
run_sql engines/economic/counterfactual_engine.sql
run_sql engines/economic/risk_capital_forecast.sql
run_sql features/materialization/merchant_behavior_baseline.sql
run_sql drift/drift_detection.sql
run_sql economic/optimization_engine.sql
run_sql stress/fraud_velocity_engine.sql
run_sql stress/monte_carlo_engine.sql
run_sql stress/risk_contagion_model.sql

echo "✅ CardOpsAI CI smoke passed (${DB_NAME}@${DB_HOST}:${DB_PORT})"
