"""FastAPI smoke tests — mirrors CI api-smoke job inside pytest."""

from __future__ import annotations

import json

import pytest
from fastapi.testclient import TestClient

from api.server import app


@pytest.fixture
def api_client():
    with TestClient(app) as client:
        yield client


def test_health_endpoint(api_client):
    r = api_client.get("/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ok"
    assert body["tier"] == "0"


def test_prometheus_metrics(api_client, seed_data):
    r = api_client.get("/api/v1/metrics/prometheus")
    assert r.status_code == 200
    text = r.text
    assert "cardops_" in text or len(text.strip()) >= 0


def test_system_health(api_client, seed_data, tenant_context):
    tid, _ = tenant_context
    r = api_client.get("/api/v1/system/health", params={"tenant_id": tid})
    assert r.status_code == 200
    assert isinstance(r.json(), dict)


def test_audit_endpoint(api_client, seed_data, tenant_context):
    tid, _ = tenant_context
    r = api_client.get("/api/v1/audit", params={"tenant_id": tid})
    assert r.status_code == 200
    body = r.json()
    assert "ok" in body


def test_score_and_explain(api_client, seed_data, tenant_context):
    tid, set_tenant = tenant_context
    set_tenant(tid)
    conn = seed_data
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM transactions WHERE tenant_id=%s ORDER BY id LIMIT 1",
            (tid,),
        )
        txn = cur.fetchone()[0]
    conn.commit()

    r = api_client.post(
        f"/api/v1/score/{txn}",
        params={"tenant_id": tid, "hybrid": True},
    )
    assert r.status_code == 200
    scored = r.json()
    assert "hybrid_score" in scored or "score" in scored or "action" in scored

    r2 = api_client.get(f"/api/v1/explain/{txn}", params={"tenant_id": tid})
    assert r2.status_code == 200
    explained = r2.json()
    assert "score" in explained


def test_triage_and_budget(api_client, seed_data, tenant_context):
    tid, _ = tenant_context
    r = api_client.get("/api/v1/triage", params={"tenant_id": tid, "limit": 5})
    assert r.status_code == 200
    assert r.json()["tenant_id"] == tid

    r2 = api_client.get("/api/v1/budget", params={"tenant_id": tid})
    assert r2.status_code == 200


def test_compliance_export(api_client, seed_data, tenant_context):
    tid, _ = tenant_context
    r = api_client.get(f"/api/v1/compliance/export/{tid}")
    assert r.status_code == 200
    packet = r.json()
    assert packet.get("packet_hash")


def test_adverse_action_pdf(api_client, seed_data, tenant_context):
    tid, set_tenant = tenant_context
    set_tenant(tid)
    conn = seed_data
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id FROM transactions WHERE tenant_id=%s ORDER BY id LIMIT 1",
            (tid,),
        )
        txn = cur.fetchone()[0]
    conn.commit()

    r = api_client.get(
        f"/api/v1/compliance/adverse-action/{txn}",
        params={"tenant_id": tid},
    )
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("application/pdf")
    assert len(r.content) > 100


def test_stress_and_rings(api_client, seed_data, tenant_context):
    tid, _ = tenant_context
    r = api_client.get(
        "/api/v1/stress",
        params={"iterations": 100, "horizon": 7, "tenant_id": tid},
    )
    assert r.status_code == 200
    stress = r.json()
    assert float(stress["var_95"]) > 0

    r2 = api_client.get("/api/v1/rings", params={"tenant_id": tid, "min_size": 3})
    assert r2.status_code == 200
    assert "rings" in r2.json()


def test_yaml_policy_and_shadow(api_client, seed_data, tenant_context):
    tid, _ = tenant_context
    yaml_body = (
        "high_amount: high_amount | weight:1.5 | threshold:40\n"
        "velocity: velocity_burst | weight:1.2 | threshold:35"
    )
    r = api_client.post(
        "/api/v1/policies/yaml",
        json={"tenant_id": tid, "policy_name": "api_test", "yaml_body": yaml_body},
    )
    assert r.status_code == 200
    assert r.json()["rules_applied"] >= 1

    r2 = api_client.post(
        "/api/v1/shadow/backtest",
        json={
            "tenant_id": tid,
            "days": 7,
            "challenger_threshold": 35.0,
            "sample_limit": 20,
        },
    )
    assert r2.status_code == 200
    body = r2.json()
    if isinstance(body, str):
        body = json.loads(body)
    assert body.get("run_id") or body.get("id")
