"""
CardOpsAI Tier-0 Enterprise API
OpenAPI at /docs — live PostgreSQL risk operations surface.
"""

from __future__ import annotations

import json
import os
from contextlib import contextmanager
from typing import Any, Generator

import psycopg2
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse, Response
from pydantic import BaseModel, Field

from api.adverse_action_pdf import build_adverse_action_pdf

DSN = os.environ.get(
    "CARDOPS_DSN",
    "postgresql://cardops:cardops_secret@localhost:5432/cardops_db",
)

app = FastAPI(
    title="CardOpsAI Risk OS API",
    description="Tier-0 Fortune 500 SQL-native payment risk operating system",
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@contextmanager
def db() -> Generator[Any, None, None]:
    conn = psycopg2.connect(DSN)
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def set_tenant(cur, tenant_id: int) -> None:
    cur.execute("SELECT set_tenant(%s)", (tenant_id,))


class YamlPolicyIn(BaseModel):
    tenant_id: int
    policy_name: str = "default"
    yaml_body: str = Field(..., description="YAML DSL lines: rule_name: expression | weight:1.2 | threshold:40")


class ShadowBacktestIn(BaseModel):
    tenant_id: int
    days: int = 30
    challenger_threshold: float = 35.0
    sample_limit: int = 500


@app.get("/health")
def health():
    return {"status": "ok", "service": "cardops-api", "tier": "0"}


@app.get("/api/v1/system/health")
def system_health(tenant_id: int | None = None):
    with db() as conn, conn.cursor() as cur:
        if tenant_id:
            set_tenant(cur, tenant_id)
        cur.execute("SELECT row_to_json(h) FROM system_health_panel h")
        row = cur.fetchone()
    return row[0] if row else {}


@app.get("/api/v1/metrics/prometheus", response_class=PlainTextResponse)
def prometheus_metrics():
    lines = []
    with db() as conn, conn.cursor() as cur:
        cur.execute("SELECT metric, value FROM prometheus_cardops_metrics")
        for name, value in cur.fetchall():
            lines.append(f"{name} {value}")
    return "\n".join(lines) + "\n"


@app.get("/api/v1/triage")
def triage(tenant_id: int, limit: int = 25):
    with db() as conn, conn.cursor() as cur:
        set_tenant(cur, tenant_id)
        cur.execute("SELECT * FROM triage_within_budget(%s, %s)", (tenant_id, limit))
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
    return {"tenant_id": tenant_id, "alerts": rows}


@app.get("/api/v1/budget")
def budget_status(tenant_id: int):
    with db() as conn, conn.cursor() as cur:
        set_tenant(cur, tenant_id)
        cur.execute(
            "SELECT row_to_json(b) FROM alert_budget_status b WHERE tenant_id = %s",
            (tenant_id,),
        )
        row = cur.fetchone()
    return row[0] if row else {"tenant_id": tenant_id, "remaining_budget": 100}


@app.post("/api/v1/score/{transaction_id}")
def score_transaction_api(transaction_id: int, tenant_id: int, hybrid: bool = False):
    with db() as conn, conn.cursor() as cur:
        set_tenant(cur, tenant_id)
        if hybrid:
            cur.execute("SELECT compute_hybrid_score(%s)", (transaction_id,))
        else:
            cur.execute("SELECT score_transaction(%s)", (transaction_id,))
        raw = cur.fetchone()[0]
    return raw if isinstance(raw, dict) else json.loads(raw)


@app.get("/api/v1/explain/{transaction_id}")
def explain(transaction_id: int, tenant_id: int):
    with db() as conn, conn.cursor() as cur:
        set_tenant(cur, tenant_id)
        cur.execute("SELECT explain_transaction_risk(%s)", (transaction_id,))
        raw = cur.fetchone()[0]
    return raw if isinstance(raw, dict) else json.loads(raw)


@app.get("/api/v1/audit")
def audit(tenant_id: int | None = None):
    with db() as conn, conn.cursor() as cur:
        if tenant_id:
            set_tenant(cur, tenant_id)
        cur.execute("SELECT verify_decision_ledger_integrity(%s)", (tenant_id,))
        raw = cur.fetchone()[0]
    return raw if isinstance(raw, dict) else json.loads(raw)


@app.post("/api/v1/shadow/backtest")
def shadow_backtest(body: ShadowBacktestIn):
    with db() as conn, conn.cursor() as cur:
        set_tenant(cur, body.tenant_id)
        cur.execute(
            "SELECT run_shadow_backtest(%s, %s, %s, %s)",
            (body.tenant_id, body.days, body.challenger_threshold, body.sample_limit),
        )
        run_id = cur.fetchone()[0]
        cur.execute(
            "SELECT row_to_json(r) FROM shadow_backtest_runs r WHERE id = %s",
            (run_id,),
        )
        row = cur.fetchone()
    return row[0] if row else {"run_id": str(run_id)}


@app.post("/api/v1/policies/yaml")
def import_yaml(body: YamlPolicyIn):
    with db() as conn, conn.cursor() as cur:
        set_tenant(cur, body.tenant_id)
        cur.execute(
            "SELECT import_yaml_policy(%s, %s, %s)",
            (body.tenant_id, body.policy_name, body.yaml_body),
        )
        policy_id = cur.fetchone()[0]
        cur.execute(
            "SELECT apply_yaml_policy_to_rules(%s, %s)",
            (body.tenant_id, body.policy_name),
        )
        applied = cur.fetchone()[0]
    return {"policy_id": str(policy_id), "rules_applied": applied}


@app.get("/api/v1/compliance/export/{tenant_id}")
def compliance_export(tenant_id: int):
    with db() as conn, conn.cursor() as cur:
        set_tenant(cur, tenant_id)
        cur.execute("SELECT export_regulatory_packet(%s)", (tenant_id,))
        raw = cur.fetchone()[0]
    return raw if isinstance(raw, dict) else json.loads(raw)


@app.get("/api/v1/compliance/adverse-action/{transaction_id}")
def adverse_action_pdf(transaction_id: int, tenant_id: int):
    with db() as conn, conn.cursor() as cur:
        set_tenant(cur, tenant_id)
        cur.execute("SELECT explain_transaction_risk(%s)", (transaction_id,))
        raw = cur.fetchone()[0]
        explanation = raw if isinstance(raw, dict) else json.loads(raw)
        cur.execute("SELECT name FROM tenants WHERE id = %s", (tenant_id,))
        trow = cur.fetchone()
    tenant_name = trow[0] if trow else f"Tenant {tenant_id}"
    pdf_bytes = build_adverse_action_pdf(explanation, tenant_name)
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="adverse-action-{transaction_id}.pdf"'
        },
    )


@app.get("/api/v1/stress")
def stress(iterations: int = 1000, horizon: int = 30, tenant_id: int | None = None):
    with db() as conn, conn.cursor() as cur:
        if tenant_id:
            set_tenant(cur, tenant_id)
        cur.execute(
            "SELECT run_monte_carlo_stress(%s, %s, %s, %s)",
            (iterations, horizon, 0.95, tenant_id),
        )
        raw = cur.fetchone()[0]
    return raw if isinstance(raw, dict) else json.loads(raw)


@app.get("/api/v1/rings")
def fraud_rings(tenant_id: int, min_size: int = 3):
    with db() as conn, conn.cursor() as cur:
        set_tenant(cur, tenant_id)
        cur.execute(
            "SELECT cluster_id, member_merchant, cluster_size FROM detect_fraud_rings(%s, %s)",
            (tenant_id, min_size),
        )
        rows = [
            {"cluster_id": r[0], "merchant": r[1], "size": r[2]}
            for r in cur.fetchall()
        ]
    return {"tenant_id": tenant_id, "rings": rows}
