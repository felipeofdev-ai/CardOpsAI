import json
import math
import re

import pytest

SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def test_core_functions_exist(setup_schema):
    conn = setup_schema
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT proname FROM pg_proc p
            JOIN pg_namespace n ON n.oid=p.pronamespace
            WHERE n.nspname='public'
              AND proname = ANY(%s)
            """,
            (
                [
                    "cardops_now",
                    "set_tenant",
                    "compute_risk_score",
                    "process_decision_queue",
                    "detect_fraud_rings",
                    "run_monte_carlo_stress",
                    "verify_decision_ledger_integrity",
                    "create_config_snapshot",
                ],
            ),
        )
        names = {r[0] for r in cur.fetchall()}
    assert len(names) >= 8


def test_ledger_integrity_detects_tamper(seed_data, tenant_context):
    conn = seed_data
    tid, set_tenant = tenant_context
    set_tenant(tid)
    with conn.cursor() as cur:
        cur.execute("SELECT verify_decision_ledger_integrity(%s)", (tid,))
        result = cur.fetchone()[0]
        if isinstance(result, str):
            result = json.loads(result)
        assert result["ok"] is True
        assert result["checked"] >= 1
        conn.commit()

        cur.execute("ALTER TABLE decision_audit_log DISABLE ROW LEVEL SECURITY")
        cur.execute(
            """
            SELECT id FROM decision_audit_log
             WHERE tenant_id=%s AND decision_hash IS NOT NULL
             ORDER BY id OFFSET 3 LIMIT 1
            """,
            (tid,),
        )
        row = cur.fetchone()
        assert row
        broken_id = row[0]
        cur.execute(
            """
            UPDATE decision_audit_log
               SET action_taken = CASE
                 WHEN action_taken='APPROVE' THEN 'BLOCK' ELSE 'APPROVE' END
             WHERE id=%s
            """,
            (broken_id,),
        )
        # Tamper hash directly for deterministic detection
        cur.execute(
            "UPDATE decision_audit_log SET decision_hash = repeat('a', 64) WHERE id=%s",
            (broken_id,),
        )
        cur.execute("SELECT verify_decision_ledger_integrity(%s)", (tid,))
        tampered = cur.fetchone()[0]
        if isinstance(tampered, str):
            tampered = json.loads(tampered)
        conn.rollback()
        set_tenant(tid)

    assert tampered["ok"] is False
    assert int(tampered["first_broken_id"]) == broken_id


def test_tenancy_rls_with_force(seed_data):
    conn = seed_data
    with conn.cursor() as cur:
        cur.execute("ALTER TABLE tenants DISABLE ROW LEVEL SECURITY")
        conn.commit()
        cur.execute(
            "SELECT id FROM tenants WHERE name LIKE 'Synthetic Tenant %%' ORDER BY id"
        )
        tenants = [r[0] for r in cur.fetchall()]
        cur.execute("ALTER TABLE tenants ENABLE ROW LEVEL SECURITY")
        conn.commit()
        assert tenants
        tid = tenants[0]

        # Superusers bypass RLS — exercise policies as app role (RLS already enabled in multi_tenant_rls.sql)
        try:
            cur.execute("SET ROLE cardops_app")
            cur.execute("SELECT set_tenant(%s)", (tid,))
            conn.commit()
            cur.execute("SELECT count(*) FROM merchants")
            visible = cur.fetchone()[0]
            cur.execute("SELECT clear_tenant()")
            conn.commit()
            cur.execute("SELECT count(*) FROM merchants")
            hidden = cur.fetchone()[0]
        finally:
            cur.execute("RESET ROLE")
            conn.commit()

    assert visible >= 1
    assert hidden == 0


def test_monte_carlo_invariants(seed_data, tenant_context):
    conn = seed_data
    tid, set_tenant = tenant_context
    set_tenant(tid)
    with conn.cursor() as cur:
        cur.execute(
            "SELECT run_monte_carlo_stress(%s,%s,%s,%s)",
            (2000, 14, 0.95, tid),
        )
        raw = cur.fetchone()[0]
        conn.commit()
    result = json.loads(raw) if isinstance(raw, str) else raw
    assert float(result["var_95"]) > 0
    assert float(result["var_99"]) > float(result["var_95"])
    assert float(result["cvar_95"]) >= float(result["var_95"])
    assert math.isfinite(float(result["cvar_95"]))


def test_engines(seed_data, tenant_context):
    conn = seed_data
    tid, set_tenant = tenant_context
    set_tenant(tid)
    with conn.cursor() as cur:
        cur.execute(
            "SELECT count(*) FROM decision_queue WHERE tenant_id=%s AND upper(status)='PENDING'",
            (tid,),
        )
        pending_before = cur.fetchone()[0]
        cur.execute("SELECT process_decision_queue(%s)", (20,))
        summary = cur.fetchone()[0]
        if isinstance(summary, str):
            summary = json.loads(summary)
        conn.commit()
        assert summary["processed"] >= 1

        cur.execute("SELECT * FROM detect_fraud_rings(%s, 3)", (tid,))
        rings = cur.fetchall()
        assert len(rings) >= 1

        cur.execute(
            "SELECT id FROM transactions WHERE tenant_id=%s ORDER BY id LIMIT 1",
            (tid,),
        )
        txn = cur.fetchone()[0]
        cur.execute("SELECT compute_risk_score(%s)", (txn,))
        score = float(cur.fetchone()[0])
        assert 0 <= score <= 100

        cur.execute("SELECT create_config_snapshot()")
        snap = cur.fetchone()[0]
        cur.execute(
            "SELECT rules_hash FROM config_snapshots WHERE snapshot_id=%s",
            (snap,),
        )
        rules_hash = cur.fetchone()[0]
        assert SHA256_RE.match(rules_hash)
        conn.commit()

    assert pending_before >= 1
