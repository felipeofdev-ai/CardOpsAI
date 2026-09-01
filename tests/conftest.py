"""Pytest fixtures for CardOpsAI."""

from __future__ import annotations

import os
import time
from pathlib import Path

import psycopg2
import pytest

ROOT = Path(__file__).resolve().parents[1]
DSN = os.environ.get(
    "CARDOPS_DSN",
    "postgresql://cardops:cardops_secret@localhost:5432/cardops_db",
)


def _wait_for_db(timeout: float = 90.0) -> None:
    deadline = time.time() + timeout
    last_err = None
    while time.time() < deadline:
        try:
            conn = psycopg2.connect(DSN)
            conn.close()
            return
        except Exception as exc:  # noqa: BLE001
            last_err = exc
            time.sleep(1)
    raise RuntimeError(f"Postgres not reachable: {last_err}")


def _exec_file(conn, relpath: str) -> None:
    sql = (ROOT / relpath).read_text(encoding="utf-8")
    with conn.cursor() as cur:
        cur.execute(sql)
    conn.commit()


def _rollback(conn) -> None:
    conn.rollback()


@pytest.fixture(scope="session")
def db_connection():
    _wait_for_db()
    conn = psycopg2.connect(DSN)
    yield conn
    conn.close()


@pytest.fixture(scope="session")
def setup_schema(db_connection):
    """Load full stack once via bash or Python fallback."""
    import os
    import subprocess

    if os.environ.get("CARDOPS_SCHEMA_LOADED") == "1":
        return db_connection

    env = os.environ.copy()
    env["CARDOPS_DSN"] = DSN
    env["SKIP_SEED"] = "1"
    script = ROOT / "scripts" / "load_all_sql.sh"
    try:
        subprocess.run(["bash", str(script)], cwd=str(ROOT), env=env, check=True)
    except (FileNotFoundError, subprocess.CalledProcessError):
        critical = [
            "database/schema/00_extensions_and_clock.sql",
            "database/schema/01_core_entities.sql",
            "database/schema/02_integrity_and_scale.sql",
            "database/schema/cardops_os.sql",
            "database/schema/04_partition_stubs.sql",
            "database/schema/event_ingestion.sql",
            "database/schema/03_queue_notify.sql",
            "database/schema/tier1_extensions.sql",
            "database/functions/set_tenant.sql",
            "database/functions/hash_chain.sql",
            "snapshots/config_snapshot_engine.sql",
            "snapshots/replay/deterministic_time.sql",
            "engines/scoring/risk_score_engine.sql",
            "engines/decision/decision_processor.sql",
            "engines/features/velocity_engine.sql",
            "engines/decision/explainability_and_triage.sql",
            "engines/decision/cost_sensitive_triage.sql",
            "engines/decision/champion_challenger.sql",
            "engines/decision/shadow_backtest.sql",
            "engines/scoring/ml_challenger.sql",
            "engines/fraud/fraud_ring_detection.sql",
            "stress/box_muller_monte_carlo.sql",
            "compliance/regulatory_export.sql",
            "database/rls-policies/multi_tenant_rls.sql",
        ]
        for rel in critical:
            _exec_file(db_connection, rel)
    return db_connection


@pytest.fixture(scope="session")
def seed_data(setup_schema):
    _exec_file(setup_schema, "database/seeds/synthetic_seed.sql")
    return setup_schema


@pytest.fixture
def tenant_context(seed_data):
    conn = seed_data

    def _set(tenant_id: int | None):
        with conn.cursor() as cur:
            if tenant_id is None:
                cur.execute("SELECT clear_tenant()")
            else:
                cur.execute("SELECT set_tenant(%s)", (tenant_id,))
        conn.commit()

    with conn.cursor() as cur:
        cur.execute("ALTER TABLE tenants DISABLE ROW LEVEL SECURITY")
        conn.commit()
        cur.execute(
            "SELECT id FROM tenants WHERE name=%s",
            ("Synthetic Tenant 1",),
        )
        row = cur.fetchone()
        cur.execute("ALTER TABLE tenants ENABLE ROW LEVEL SECURITY")
        conn.commit()
    assert row
    tid = row[0]
    _set(tid)
    yield tid, _set
    _set(None)
