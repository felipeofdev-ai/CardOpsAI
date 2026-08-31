#!/usr/bin/env bash
set -euo pipefail

# Backward-compatible defaults for existing GitHub smoke job
export DB_HOST="${DB_HOST:-localhost}"
export DB_PORT="${DB_PORT:-5432}"
export DB_USER="${DB_USER:-postgres}"
export DB_NAME="${DB_NAME:-cardops}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export SKIP_SEED="${SKIP_SEED:-0}"

bash scripts/load_all_sql.sh

psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
  -c "SELECT cardops_now();"
psql -v ON_ERROR_STOP=1 -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
  -c "SELECT verify_decision_ledger_integrity();"

echo "✅ CI smoke completed"
