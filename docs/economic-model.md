# Economic Model

CardOpsAI optimizes decisions by balancing revenue, fraud loss, capital cost, and churn.

## Objective Function

`profit_score = revenue*w_r - fraud_loss*w_f - capital_cost*w_c - churn_cost*w_ch`

Where weights are defined in `economic_objectives`.

## Economic Guardrails

Every policy can be bounded by:

- `min_approval_rate`
- `max_chargeback_rate`
- `max_capital_usage`

Guardrail violations are surfaced by `guardrail_violations`.

## Counterfactual Lab

`run_counterfactual(...)` stores historical "what-if" outcomes and `counterfactual_ranking` compares policy candidates by profitability and risk.

## 12-Month Risk Capital Forecast

`risk_capital_forecast_12m` projects volume and capital requirements using growth + seasonality assumptions for CFO planning.
