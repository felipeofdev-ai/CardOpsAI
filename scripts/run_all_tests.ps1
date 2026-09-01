# CardOpsAI — full local test runner (mirrors CI: lint-sql, test, api-smoke, validate)
param(
    [switch]$SkipSqlLint,
    [switch]$SkipDb
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$env:CARDOPS_DSN = if ($env:CARDOPS_DSN) { $env:CARDOPS_DSN } else {
    "postgresql://cardops:cardops_secret@localhost:5432/cardops_db"
}

Write-Host "`n=== CardOpsAI full test suite ===" -ForegroundColor Cyan
$failed = @()

function Step($name, [scriptblock]$block) {
    Write-Host "`n>> $name" -ForegroundColor Yellow
    try {
        & $block
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "exit $LASTEXITCODE" }
        Write-Host "   PASS" -ForegroundColor Green
    } catch {
        Write-Host "   FAIL: $_" -ForegroundColor Red
        $script:failed += $name
    }
}

Step "Python compile (CLI + API + tests)" {
    python -m compileall -q cardops_cli.py cardops_api.py api tests
}

Step "SQLFluff lint (non-blocking style)" {
    if (-not $SkipSqlLint) {
        python -m sqlfluff lint database engines snapshots stress compliance --dialect postgres 2>&1 | Out-Null
        # CI treats sqlfluff as advisory (|| true)
    }
}

$dbUp = $false
if (-not $SkipDb) {
    Step "Database connectivity" {
        python -c @"
import os, psycopg2
dsn = os.environ['CARDOPS_DSN']
c = psycopg2.connect(dsn)
c.close()
print('connected')
"@
        $script:dbUp = $true
    }
}

if ($dbUp) {
    $env:CARDOPS_SCHEMA_LOADED = "1"
    Step "Load SQL schema" {
        bash scripts/load_all_sql.sh
    }
    Step "Pytest (platform + ops + tier0 + API)" {
        python -m pytest -q tests
    }
    Step "CLI smoke" {
        python cardops_cli.py status
        python cardops_cli.py health
    }
    Step "validate_system.py" {
        python scripts/validate_system.py
    }
} else {
    Write-Host "`nWARN: Postgres not reachable — skipping DB/pytest/API tests." -ForegroundColor DarkYellow
    Write-Host "      Install Docker Desktop and run: docker compose up -d" -ForegroundColor DarkYellow
    Write-Host "      Or set CARDOPS_DSN to a running Postgres instance." -ForegroundColor DarkYellow
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
if ($failed.Count -eq 0) {
    if ($dbUp) {
        Write-Host "ALL TESTS PASSED (local + DB)" -ForegroundColor Green
    } else {
        Write-Host "STATIC CHECKS PASSED — DB tests skipped (no Postgres)" -ForegroundColor Yellow
    }
    exit 0
} else {
    Write-Host "FAILED: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
