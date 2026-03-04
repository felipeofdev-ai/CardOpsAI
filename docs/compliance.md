# Compliance & Security

## Regulatory Posture

- LGPD minimization + anonymization workflows
- PCI-DSS segmentation and tokenization-first handling
- Immutable decision/incident evidence for audits

## Multi-Tenant Controls

- RLS by `tenant_id` on sensitive operational ledgers
- `app.current_tenant` session scoping
- Optional schema-level isolation for high-risk clusters

## Integrity & Forensics

- Tamper-evident hash chaining for decisions
- Append-only incident ledger
- WORM-compatible retention strategy
