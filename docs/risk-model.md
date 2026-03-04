# Risk Model Governance

## Replay and Reproducibility

Every decision must be reproducible from:

- `tenant_id`
- `snapshot_id`
- `model_version_id`
- threshold set version
- feature lineage/version
- deterministic replay time (`cardops.replay_time`)

## Model Lifecycle Objects

- `model_registry`
- `model_versions`
- `model_deployments`

## Explainability Contract

For each decision, keep:

- feature value
- feature weight
- feature contribution

This enables score reconstruction and audit defense.

## Statistical Validation

- PSI for population stability
- KS proxy from score distributions
- ROC recalculation view
- feature drift tracking

## Governance Gates

- Accuracy >= 0.85
- F1 >= 0.80
- Drift score <= configured threshold
- Guardrail constraints satisfied
- Replay equivalence validation must pass before activation
