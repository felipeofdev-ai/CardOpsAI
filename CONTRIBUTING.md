# Contributing to CardOpsAI

Thanks for helping harden a SQL-first Risk OS.

## Ground rules

1. Keep core risk logic in PostgreSQL when possible (CLI / tests / docs around it).
2. Prefer idempotent DDL (`IF NOT EXISTS`, `OR REPLACE`).
3. Use `cardops_now()` instead of bare `NOW()` in engine SQL.
4. Every new public SQL function should have at least one Pytest assertion.
5. Do not store raw PAN, CVV, or secrets in the repo.

## Workflow

```bash
git checkout -b feat/your-change
# edit SQL / Python / docs
bash scripts/load_all_sql.sh   # or make db-seed
pytest -q
python cardops_cli.py health
```

## Pull requests

- Describe **why** the change matters for risk ops
- Link any related issue
- Include test plan (commands you ran)
- Keep PRs focused; split large refactors

## Code style

- SQL: readable CTEs, comments on public functions
- Python: stdlib + `psycopg2` / `pytest` only unless justified
- Docs: clear English, no broken encoding

## License

Contributions are accepted under the Apache License 2.0.
