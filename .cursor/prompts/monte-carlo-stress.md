# /monte-carlo-stress

## Purpose
Run Box-Muller Monte Carlo loss simulation and report VaR/CVaR capital metrics.

## Inputs
- `iterations` (INT, default 1000)
- `horizon_days` (INT, default 30)
- `confidence` (NUMERIC, default 0.95)
- `tenant_id` (optional)

## Steps
1. Ensure historical transactions exist for loss baseline.
2. Call `run_monte_carlo_stress(iterations, horizon_days, confidence)`.
3. Validate invariants: VaR99 > VaR95, CVaR95 >= VaR95, finite positives.
4. Display via CLI `stress` and dashboard histogram.

## Expected Output
```json
{
  "iterations": 5000,
  "horizon_days": 30,
  "var_95": 12345.67,
  "var_99": 23456.78,
  "cvar_95": 25678.90,
  "recommended_capital_reserve": 30814.68,
  "mean_loss": 8000.0,
  "std_loss": 1500.0
}
```
