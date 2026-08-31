# /create-risk-rule

## Purpose
Generate a new tenant-scoped risk rule with SQL expression, scoring weight, and Pytest coverage.

## Inputs
- `tenant_id` (BIGINT)
- `rule_name` (TEXT)
- `rule_expression` (TEXT) — boolean SQL predicate over transaction/feature context
- `threshold` (NUMERIC)
- `weight` (NUMERIC)
- `description` (optional)

## Steps
1. Insert into `risk_rules` with `is_active = true`, increment `version` if name exists.
2. Ensure expression only references allowed columns/features (no DDL, no cross-tenant).
3. Call `create_config_snapshot(tenant_id)` and record new Merkle root.
4. Add/extend `tests/test_engines.py` asserting the rule contributes to `compute_risk_score`.
5. Optionally enqueue sample transactions and run `process_decision_queue`.

## Expected Output
- SQL insert statement (or migration snippet)
- New snapshot UUID + `snapshot_hash`
- Test name and assertion summary
- Example decision explanation JSON showing the rule fired
