# Capacity Model

## Hardware Assumptions

- PostgreSQL 16+
- 16 vCPU / 64 GB RAM baseline node
- NVMe SSD with high write IOPS
- WAL on dedicated fast storage class

## Throughput and Replay Targets

- Sustained ingest/decision target: **>= 5k TPS**
- p95 decision latency target: **< 200ms**
- p99 fraud decision target: **< 300ms**
- Replay benchmark: **30 days < 4h**

## Partition Strategy

- Monthly partitioning for large fact tables (`transactions`, `decision_audit_log`)
- Time-range pruning for replay and stress workloads

## Resource Isolation

- Tenant quotas from `tenant_limits`
- Breach monitoring via `tenant_limit_breaches`
- Queue backpressure monitoring via `queue_backpressure`

## I/O Profile

- Write-heavy from ingestion, queue and ledgers
- Read-heavy from replay, stress and analytics windows
- Burst-heavy from backtesting, counterfactual and forecast workloads
