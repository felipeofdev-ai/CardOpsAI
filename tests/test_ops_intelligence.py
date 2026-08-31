"""Tests for velocity, explainability, triage, and shadow mode."""

from __future__ import annotations

import json

from conftest import _exec_file


def test_velocity_and_explainability(seed_data, tenant_context):
    conn = seed_data
    tid, set_tenant = tenant_context
    set_tenant(tid)

    _exec_file(conn, "engines/features/velocity_engine.sql")
    _exec_file(conn, "engines/decision/explainability_and_triage.sql")
    _exec_file(conn, "engines/decision/champion_challenger.sql")
    _exec_file(conn, "drift/drift_detection.sql")
    _exec_file(conn, "engines/fraud/geo_velocity.sql")

    with conn.cursor() as cur:
        cur.execute("SELECT refresh_velocity_features(%s)", (tid,))
        n = cur.fetchone()[0]
        assert n >= 1

        cur.execute(
            "SELECT id FROM transactions WHERE tenant_id=%s ORDER BY id DESC LIMIT 1",
            (tid,),
        )
        txn = cur.fetchone()[0]

        cur.execute("SELECT explain_transaction_risk(%s)", (txn,))
        explained = cur.fetchone()[0]
        if isinstance(explained, str):
            explained = json.loads(explained)
        assert "score" in explained
        assert "expected_loss" in explained
        assert "factors" in explained
        assert "adverse_action_codes" in explained

        cur.execute("SELECT score_transaction(%s)", (txn,))
        scored = cur.fetchone()[0]
        if isinstance(scored, str):
            scored = json.loads(scored)
        assert scored["action"] in ("APPROVE", "REVIEW", "BLOCK")

        cur.execute("SELECT * FROM top_alerts_by_expected_loss(%s, %s)", (tid, 10))
        cur.fetchall()

        cur.execute("SELECT run_shadow_score(%s, %s)", (txn, 35))
        shadow = cur.fetchone()[0]
        if isinstance(shadow, str):
            shadow = json.loads(shadow)
        assert "champion_action" in shadow
        assert "challenger_action" in shadow

        cur.execute("SELECT * FROM system_health_panel")
        health = cur.fetchone()
        assert health is not None
        conn.commit()
