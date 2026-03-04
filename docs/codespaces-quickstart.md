# Codespaces Quickstart

## 1) Open a Codespace

1. Go to the repository on GitHub.
2. Click **Code** → **Codespaces**.
3. Click **Create codespace on main**.

## 2) Start PostgreSQL and load CardOpsAI schema

From the Codespaces terminal:

```bash
./scripts/setup_codespaces.sh
```

This script will:
- start (or reuse) a PostgreSQL 16 Docker container,
- wait for readiness,
- apply all SQL files in dependency order.

## 3) Manual bootstrap (optional)

If you prefer manual execution:

```bash
docker run --name cardops-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=cardops \
  -p 5432:5432 \
  -d postgres:16

DB_HOST=localhost DB_PORT=5432 DB_USER=postgres DB_NAME=cardops PGPASSWORD=postgres \
  ./scripts/load_all_sql.sh
```

## 4) Validate

```bash
PGPASSWORD=postgres psql -h localhost -U postgres -d cardops -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name;"
```

## 5) Run sample queries

```sql
-- Policy simulation (threshold numeric + time window)
SELECT *
FROM simulate_policy(
  500.00,
  NOW() - INTERVAL '30 days',
  NOW()
);

-- Replay with deterministic time context
SELECT set_replay_time('2026-01-01 00:00:00+00');
SELECT *
FROM replay_decisions(
  1,
  '00000000-0000-0000-0000-000000000000',
  1,
  NULL,
  NULL
)
LIMIT 50;
SELECT clear_replay_time();

-- Fraud ring detection (function, not table)
SELECT * FROM detect_fraud_rings(1, 3) LIMIT 20;
```

## 6) Optional VS Code GUI

In Codespaces VS Code extensions, install a PostgreSQL client extension and connect:

- Host: `localhost`
- Port: `5432`
- User: `postgres`
- Password: `postgres`
- Database: `cardops`
