"""Tier-0 enterprise feature tests."""

from __future__ import annotations

import json

from conftest import _exec_file


def test_tier0_modules(seed_data, tenant_context):
    conn = seed_data
    tid, set_tenant = tenant_context
    set_tenant(tid)

    modules = [
        "engines/decision/cost_sensitive_triage.sql",
        "engines/decision/shadow_backtest.sql",
        "engines/scoring/ml_challenger.sql",
        "engines/rules/yaml_rules_engine.sql",
        "compliance/regulatory_export.sql",
    ]
    for m in modules:
        _exec_file(conn, m)

    with conn.cursor() as cur:
        cur.execute("SELECT refresh_velocity_features(%s)", (tid,))
        assert cur.fetchone()[0] >= 1

        cur.execute(
            "SELECT id FROM transactions WHERE tenant_id=%s ORDER BY id LIMIT 1",
            (tid,),
        )
        txn = cur.fetchone()[0]

        cur.execute("SELECT compute_ml_anomaly_score(%s)", (txn,))
        ml = float(cur.fetchone()[0])
        assert 0 <= ml <= 100

        cur.execute("SELECT compute_hybrid_score(%s)", (txn,))
        hybrid = cur.fetchone()[0]
        if isinstance(hybrid, str):
            hybrid = json.loads(hybrid)
        assert "hybrid_score" in hybrid

        yaml_body = "high_amount: high_amount | weight:1.5 | threshold:40\nvelocity: velocity_burst | weight:1.2 | threshold:35"
        cur.execute(
            "SELECT import_yaml_policy(%s, %s, %s)",
            (tid, "tier0_test", yaml_body),
        )
        cur.execute(
            "SELECT apply_yaml_policy_to_rules(%s, %s)",
            (tid, "tier0_test"),
        )
        assert cur.fetchone()[0] >= 1

        cur.execute("SELECT run_shadow_backtest(%s, 7, 35, 20)", (tid,))
        run_id = cur.fetchone()[0]
        assert run_id is not None

        cur.execute("SELECT export_regulatory_packet(%s)", (tid,))
        packet = cur.fetchone()[0]
        if isinstance(packet, str):
            packet = json.loads(packet)
        assert packet.get("packet_hash")

        cur.execute("SELECT count(*) FROM prometheus_cardops_metrics")
        assert cur.fetchone()[0] >= 3

        conn.commit()
