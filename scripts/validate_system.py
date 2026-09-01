#!/usr/bin/env python3
"""Full CardOpsAI validation: files, SQL load order, DB connectivity, CLI, tests."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DSN = os.environ.get(
    "CARDOPS_DSN",
    "postgresql://cardops:cardops_secret@localhost:5432/cardops_db",
)

REQUIRED_FILES = [
    "cardops_cli.py",
    "cardops_api.py",
    "api/server.py",
    "docker-compose.yml",
    "Makefile",
    "requirements.txt",
    "scripts/load_all_sql.sh",
    "database/schema/00_extensions_and_clock.sql",
    "database/schema/01_core_entities.sql",
    "database/schema/02_integrity_and_scale.sql",
    "database/schema/04_partition_stubs.sql",
    "database/seeds/synthetic_seed.sql",
    "database/functions/hash_chain.sql",
    "engines/scoring/risk_score_engine.sql",
    "engines/decision/decision_processor.sql",
    "engines/features/velocity_engine.sql",
    "engines/decision/explainability_and_triage.sql",
    "engines/decision/cost_sensitive_triage.sql",
    "engines/decision/champion_challenger.sql",
    "engines/decision/shadow_backtest.sql",
    "engines/scoring/ml_challenger.sql",
    "engines/fraud/geo_velocity.sql",
    "compliance/regulatory_export.sql",
    "stress/box_muller_monte_carlo.sql",
    "docs/dashboard.html",
    "tests/test_tier1_platform.py",
    "tests/test_ops_intelligence.py",
    "tests/test_tier0_enterprise.py",
    "tests/test_api_smoke.py",
]

REQUIRED_FUNCTIONS = [
    "cardops_now",
    "set_tenant",
    "compute_risk_score",
    "process_decision_queue",
    "verify_decision_ledger_integrity",
    "run_monte_carlo_stress",
    "detect_fraud_rings",
    "create_config_snapshot",
    "explain_transaction_risk",
    "refresh_velocity_features",
    "run_shadow_score",
]


def ok(msg: str) -> None:
    print(f"  OK  {msg}")


def fail(msg: str) -> None:
    print(f"  FAIL {msg}")


def warn(msg: str) -> None:
    print(f"  WARN {msg}")


def check_files() -> list[str]:
    errors = []
    print("\n== File inventory ==")
    for rel in REQUIRED_FILES:
        p = ROOT / rel
        if p.is_file():
            ok(rel)
        else:
            fail(f"missing: {rel}")
            errors.append(rel)
    sql_count = len(list(ROOT.rglob("*.sql")))
    ok(f"total SQL files: {sql_count}")
    return errors


def check_python() -> list[str]:
    errors = []
    print("\n== Python syntax ==")
    for path in [ROOT / "cardops_cli.py", ROOT / "cardops_api.py", ROOT / "api", ROOT / "tests"]:
        r = subprocess.run(
            [sys.executable, "-m", "compileall", "-q", str(path)],
            capture_output=True,
            text=True,
        )
        if r.returncode == 0:
            ok(str(path.relative_to(ROOT)))
        else:
            fail(str(path))
            errors.append(str(path))
    return errors


def check_db() -> tuple[list[str], bool]:
    errors = []
    print("\n== Database connectivity ==")
    try:
        import psycopg2
    except ImportError:
        fail("psycopg2 not installed (pip install -r requirements.txt)")
        return ["psycopg2"], False

    try:
        conn = psycopg2.connect(DSN)
        conn.close()
        ok(f"connected: {DSN.split('@')[-1]}")
    except Exception as exc:
        fail(f"cannot connect: {exc}")
        warn("Install Docker Desktop and run: docker compose up -d")
        return ["db_connection"], False

    return errors, True


def check_schema_and_functions() -> list[str]:
    errors = []
    print("\n== Schema & functions ==")
    import psycopg2

    conn = psycopg2.connect(DSN)
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT table_name FROM information_schema.tables
             WHERE table_schema = 'public'
               AND table_name IN (
                 'tenants','merchants','cards','transactions',
                 'decision_audit_log','decision_queue','risk_rules'
               )
            """
        )
        tables = {r[0] for r in cur.fetchall()}
        for t in ["tenants", "merchants", "cards", "transactions", "decision_audit_log"]:
            if t in tables:
                ok(f"table {t}")
            else:
                fail(f"table missing: {t}")
                errors.append(t)

        cur.execute(
            """
            SELECT p.proname FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = 'public' AND p.proname = ANY(%s)
            """,
            (REQUIRED_FUNCTIONS,),
        )
        funcs = {r[0] for r in cur.fetchall()}
        for fn in REQUIRED_FUNCTIONS:
            if fn in funcs:
                ok(f"function {fn}")
            else:
                fail(f"function missing: {fn}")
                errors.append(fn)

        cur.execute("SELECT verify_decision_ledger_integrity()")
        ledger = cur.fetchone()[0]
        if isinstance(ledger, str):
            ledger = json.loads(ledger)
        if ledger.get("ok"):
            ok(f"ledger integrity ({ledger.get('checked', 0)} blocks)")
        else:
            warn(f"ledger issue: {ledger}")

        cur.execute("SELECT * FROM system_health_panel")
        health = cur.fetchone()
        if health:
            ok("system_health_panel")
        else:
            fail("system_health_panel empty")
            errors.append("system_health_panel")

    conn.close()
    return errors


def check_cli() -> list[str]:
    errors = []
    print("\n== CLI smoke ==")
    cmds = [
        [sys.executable, str(ROOT / "cardops_cli.py"), "status"],
        [sys.executable, str(ROOT / "cardops_cli.py"), "health"],
        [sys.executable, str(ROOT / "cardops_cli.py"), "audit"],
    ]
    for cmd in cmds:
        r = subprocess.run(cmd, capture_output=True, text=True, cwd=str(ROOT))
        label = " ".join(cmd[-1:])
        if r.returncode in (0, 2):  # audit returns 2 on tamper
            ok(label)
        else:
            fail(f"{label}: {r.stderr.strip() or r.stdout.strip()}")
            errors.append(label)
    return errors


def check_api_smoke() -> list[str]:
    errors = []
    print("\n== API smoke (TestClient) ==")
    r = subprocess.run(
        [sys.executable, "-m", "pytest", "-q", "tests/test_api_smoke.py"],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
    )
    print(r.stdout)
    if r.returncode == 0:
        ok("api endpoints")
    else:
        fail("api smoke failed")
        if r.stderr:
            print(r.stderr[:2000])
        errors.append("api_smoke")
    return errors


def check_pytest() -> list[str]:
    errors = []
    print("\n== Pytest ==")
    r = subprocess.run(
        [sys.executable, "-m", "pytest", "-q", "tests"],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
    )
    print(r.stdout)
    if r.returncode == 0:
        ok("all tests passed")
    else:
        fail("pytest failed")
        if r.stderr:
            print(r.stderr[:2000])
        errors.append("pytest")
    return errors


def main() -> int:
    print("CardOpsAI system validation")
    print("=" * 40)
    all_errors: list[str] = []
    all_errors.extend(check_files())
    all_errors.extend(check_python())
    db_errors, db_ok = check_db()
    all_errors.extend(db_errors)
    if db_ok:
        all_errors.extend(check_schema_and_functions())
        all_errors.extend(check_cli())
        all_errors.extend(check_pytest())

    print("\n" + "=" * 40)
    if all_errors:
        print(f"RESULT: {len(all_errors)} issue(s) — see above")
        return 1
    print("RESULT: ALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
