# Security Policy

## Supported versions

| Branch | Supported |
|--------|-----------|
| `main` | Yes |

## Reporting a vulnerability

Email `felipe.of.dev@gmail.com` with:

1. Description of the issue
2. Steps to reproduce
3. Impact assessment (data exposure, integrity, availability)

Please **do not** open public issues for sensitive disclosures.

## Security model (as designed)

- **No raw PAN storage** — only `card_hash` (SHA-256)
- **Tenant isolation** via `app.current_tenant` + RLS
- **Tamper-evident decisions** via hash-chained `decision_audit_log`
- **Secrets** — local Docker defaults are for development only; rotate for any shared environment
- **Dynamic SQL from rule text is not executed** — named expression evaluation only

## Development defaults

`docker-compose.yml` ships with known credentials for local demos. Never reuse them in production.
