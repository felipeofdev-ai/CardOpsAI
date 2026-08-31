#!/usr/bin/env bash
set -euo pipefail
export SKIP_SEED="${SKIP_SEED:-0}"
bash /sql/scripts/load_all_sql.sh --inside-docker
