# /verify-ledger-integrity

## Purpose
Audit the SHA-256 decision hash chain for tampering.

## Inputs
- `tenant_id` (BIGINT, optional — all tenants if omitted)
- `limit` (optional sample size)

## Steps
1. Call `verify_decision_ledger_integrity()` (and/or per-tenant variant).
2. Recompute each `current_hash` from `previous_hash` + canonical transaction/decision payload.
3. On mismatch, stop and report broken position.
4. Surface results through CLI `audit` with green/red indicators.

## Expected Output
```json
{
  "ok": false,
  "checked": 200,
  "first_broken_id": 142,
  "expected_hash": "...",
  "actual_hash": "..."
}
```
