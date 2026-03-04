#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-cardops-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-cardops}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ docker not found. In Codespaces, enable Docker-in-Docker or use the devcontainer service config." >&2
  exit 1
fi

if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  echo "ℹ️ Container $CONTAINER_NAME already exists. Starting it..."
  docker start "$CONTAINER_NAME" >/dev/null
else
  echo "ℹ️ Creating PostgreSQL container: $CONTAINER_NAME"
  docker run --name "$CONTAINER_NAME" \
    -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    -e POSTGRES_DB="$POSTGRES_DB" \
    -e POSTGRES_USER="$POSTGRES_USER" \
    -p "$POSTGRES_PORT":5432 \
    -d postgres:16 >/dev/null
fi

echo "ℹ️ Waiting for PostgreSQL to be ready..."
for _ in $(seq 1 30); do
  if docker exec "$CONTAINER_NAME" pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

export DB_HOST="localhost"
export DB_PORT="$POSTGRES_PORT"
export DB_USER="$POSTGRES_USER"
export DB_NAME="$POSTGRES_DB"
export PGPASSWORD="$POSTGRES_PASSWORD"

./scripts/load_all_sql.sh

echo "✅ Codespaces local setup complete"
