# /run-counterfactual-simulation

## Purpose
Clone production config, mutate specified parameters, and measure decision/loss deltas.

## Inputs
- `tenant_id` (BIGINT)
- `base_snapshot_id` (UUID, optional — default latest)
- `mutated_params` (JSONB), e.g. `{"rule_id": 12, "new_threshold": 40}`
- `start_date` / `end_date` (TIMESTAMPTZ)

## Steps
1. Resolve base snapshot (`create_config_snapshot` if none).
2. Insert `counterfactual_scenarios` row with `mutated_params`.
3. Run `replay_decisions` under mutated thresholds/rules.
4. Persist `result_metrics`: `{total, unchanged, changed, approved_delta, declined_delta, estimated_loss_delta}`.
5. Print human-readable diff via CLI `simulate`.

## Expected Output
- Scenario UUID
- Metrics JSON
- Top N transactions whose decision flipped, with reasons
