#!/usr/bin/env python3
"""CardOpsAI operational CLI (works with upstream SQL-native OS)."""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any

import psycopg2
from psycopg2.extras import RealDictCursor

DSN = os.environ.get(
    "CARDOPS_DSN",
    "postgresql://cardops:cardops_secret@localhost:5432/cardops_db",
)

GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
RESET = "\033[0m"


def connect():
    return psycopg2.connect(DSN)


def ok(msg: str) -> None:
    print(f"{GREEN}✅ {msg}{RESET}")


def err(msg: str) -> None:
    print(f"{RED}❌ {msg}{RESET}", file=sys.stderr)


def warn(msg: str) -> None:
    print(f"{YELLOW}⚠️  {msg}{RESET}")


def table(headers: list[str], rows: list[list[Any]]) -> None:
    widths = [len(h) for h in headers]
    str_rows = []
    for row in rows:
        cells = ["" if c is None else str(c) for c in row]
        str_rows.append(cells)
        for i, c in enumerate(cells):
            widths[i] = max(widths[i], len(c))
    print(" | ".join(h.ljust(widths[i]) for i, h in enumerate(headers)))
    print("-+-".join("-" * w for w in widths))
    for cells in str_rows:
        print(" | ".join(cells[i].ljust(widths[i]) for i in range(len(headers))))


def resolve_tenant(cur, tenant_id: int | None) -> int:
    if tenant_id is not None:
        cur.execute("SELECT set_tenant(%s)", (tenant_id,))
        return tenant_id
    cur.execute("ALTER TABLE tenants DISABLE ROW LEVEL SECURITY")
    cur.execute(
        "SELECT id FROM tenants WHERE status = 'active' ORDER BY id LIMIT 1"
    )
    row = cur.fetchone()
    cur.execute("ALTER TABLE tenants ENABLE ROW LEVEL SECURITY")
    if not row:
        raise RuntimeError("No active tenant found. Run seed first.")
    tid = row[0] if not isinstance(row, dict) else row["id"]
    cur.execute("SELECT set_tenant(%s)", (tid,))
    return tid


def cmd_status(args: argparse.Namespace) -> int:
    with connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        tid = resolve_tenant(cur, args.tenant_id)
        conn.commit()
        cur.execute(
            "SELECT count(*) AS n FROM decision_queue WHERE upper(status)='PENDING'"
        )
        queue_depth = cur.fetchone()["n"]
        cur.execute(
            "SELECT count(*) AS n FROM risk_rules WHERE COALESCE(is_active, active, TRUE)"
        )
        active_rules = cur.fetchone()["n"]
        cur.execute(
            """
            SELECT snapshot_id::text AS id, rules_hash, created_at
              FROM config_snapshots
             ORDER BY created_at DESC LIMIT 1
            """
        )
        snap = cur.fetchone()
        cur.execute("SELECT count(*) AS n FROM transactions")
        txn_count = cur.fetchone()["n"]
        conn.commit()

    ok(f"CardOpsAI healthy — tenant {tid}")
    table(
        ["metric", "value"],
        [
            ["tenant_id", tid],
            ["queue_depth", queue_depth],
            ["active_rules", active_rules],
            ["transactions", txn_count],
            ["active_snapshot", snap["id"] if snap else "-"],
            ["rules_hash", (snap["rules_hash"][:16] + "…") if snap else "-"],
        ],
    )
    return 0


def cmd_audit(args: argparse.Namespace) -> int:
    with connect() as conn, conn.cursor() as cur:
        if args.tenant_id:
            cur.execute("SELECT set_tenant(%s)", (args.tenant_id,))
        cur.execute(
            "SELECT verify_decision_ledger_integrity(%s)",
            (args.tenant_id,),
        )
        raw = cur.fetchone()[0]
        conn.commit()
    result = raw if isinstance(raw, dict) else json.loads(raw)
    if result.get("ok"):
        ok(f"Ledger intact — checked {result.get('checked')} blocks")
    else:
        err(f"Tamper detected at id={result.get('first_broken_id')}")
    print(json.dumps(result, indent=2))
    return 0 if result.get("ok") else 2


def cmd_stress(args: argparse.Namespace) -> int:
    with connect() as conn, conn.cursor() as cur:
        tid = resolve_tenant(cur, args.tenant_id)
        conn.commit()
        cur.execute(
            "SELECT run_monte_carlo_stress(%s, %s, %s, %s)",
            (args.iterations, args.horizon, 0.95, tid),
        )
        raw = cur.fetchone()[0]
        conn.commit()
    result = raw if isinstance(raw, dict) else json.loads(raw)
    ok("Monte Carlo stress complete")
    table(["metric", "value"], [[k, result[k]] for k in sorted(result.keys())])
    return 0


def cmd_rings(args: argparse.Namespace) -> int:
    with connect() as conn, conn.cursor() as cur:
        tid = resolve_tenant(cur, args.tenant_id)
        conn.commit()
        cur.execute(
            "SELECT cluster_id, member_merchant, cluster_size FROM detect_fraud_rings(%s, %s)",
            (tid, args.min_size),
        )
        rows = cur.fetchall()
        conn.commit()
    if not rows:
        warn("No fraud rings detected")
        return 0
    ok(f"Detected {len(rows)} ring membership row(s)")
    table(
        ["cluster_id", "merchant", "size"],
        [[r[0], r[1], r[2]] for r in rows],
    )
    return 0


def cmd_simulate(args: argparse.Namespace) -> int:
    with connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        resolve_tenant(cur, args.tenant_id)
        conn.commit()
        cur.execute(
            """
            SELECT run_counterfactual(
              %s, %s,
              cardops_now() - INTERVAL '30 days',
              cardops_now()
            )
            """,
            (f"rule-{args.rule_id}", args.new_threshold),
        )
        run_id = cur.fetchone()["run_counterfactual"]
        cur.execute("SELECT * FROM counterfactual_runs WHERE run_id = %s", (run_id,))
        row = dict(cur.fetchone())
        conn.commit()
    ok(f"Counterfactual run {run_id}")
    print(json.dumps(row, indent=2, default=str))
    return 0


def cmd_process(args: argparse.Namespace) -> int:
    with connect() as conn, conn.cursor() as cur:
        resolve_tenant(cur, args.tenant_id)
        conn.commit()
        cur.execute("SELECT process_decision_queue(%s)", (args.batch_size,))
        raw = cur.fetchone()[0]
        conn.commit()
    result = raw if isinstance(raw, dict) else json.loads(raw)
    ok(f"Processed {result.get('processed')} queue item(s)")
    table(["metric", "value"], [[k, v] for k, v in result.items()])
    return 0


def cmd_snapshot(args: argparse.Namespace) -> int:
    with connect() as conn, conn.cursor() as cur:
        resolve_tenant(cur, args.tenant_id)
        conn.commit()
        cur.execute("SELECT create_config_snapshot()")
        snap_id = cur.fetchone()[0]
        cur.execute(
            "SELECT rules_hash FROM config_snapshots WHERE snapshot_id = %s",
            (snap_id,),
        )
        rules_hash = cur.fetchone()[0]
        conn.commit()
    ok(f"Snapshot {snap_id}")
    print(f"{CYAN}rules_hash{RESET}: {rules_hash}")
    return 0


def cmd_triage(args: argparse.Namespace) -> int:
    with connect() as conn, conn.cursor() as cur:
        tid = resolve_tenant(cur, args.tenant_id)
        conn.commit()
        cur.execute(
            "SELECT * FROM top_alerts_by_expected_loss(%s, %s)",
            (tid, args.limit),
        )
        rows = cur.fetchall()
        conn.commit()
    if not rows:
        warn("No triage alerts")
        return 0
    ok(f"Top {len(rows)} alerts by expected loss")
    table(
        ["tx_id", "merchant", "amount", "score", "expected_loss", "band"],
        [[r[0], r[1], r[2], r[3], r[4], r[5]] for r in rows],
    )
    return 0


def cmd_score(args: argparse.Namespace) -> int:
    with connect() as conn, conn.cursor() as cur:
        resolve_tenant(cur, args.tenant_id)
        conn.commit()
        cur.execute("SELECT score_transaction(%s)", (args.tx_id,))
        raw = cur.fetchone()[0]
        conn.commit()
    result = raw if isinstance(raw, dict) else json.loads(raw)
    ok(f"Scored transaction {args.tx_id}")
    print(json.dumps(result, indent=2, default=str))
    return 0


def cmd_shadow(args: argparse.Namespace) -> int:
    with connect() as conn, conn.cursor() as cur:
        resolve_tenant(cur, args.tenant_id)
        conn.commit()
        cur.execute(
            "SELECT run_shadow_score(%s, %s)",
            (args.tx_id, args.challenger_threshold),
        )
        raw = cur.fetchone()[0]
        conn.commit()
    result = raw if isinstance(raw, dict) else json.loads(raw)
    if result.get("diverged"):
        warn("Champion and challenger diverged")
    else:
        ok("Champion and challenger agree")
    print(json.dumps(result, indent=2, default=str))
    return 0


def cmd_health(args: argparse.Namespace) -> int:
    with connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        resolve_tenant(cur, args.tenant_id)
        conn.commit()
        cur.execute("SELECT * FROM system_health_panel")
        row = cur.fetchone()
        conn.commit()
    ok("System health panel")
    table(["metric", "value"], [[k, row[k]] for k in row.keys()])
    return 0


def cmd_velocity(args: argparse.Namespace) -> int:
    with connect() as conn, conn.cursor() as cur:
        tid = resolve_tenant(cur, args.tenant_id)
        conn.commit()
        cur.execute("SELECT refresh_velocity_features(%s)", (tid,))
        n = cur.fetchone()[0]
        cur.execute(
            """
            SELECT entity_type, entity_id, tx_count_1h, tx_count_24h, amount_spike_ratio
              FROM velocity_features
             WHERE tenant_id = %s
             ORDER BY tx_count_24h DESC
             LIMIT %s
            """,
            (tid, args.limit),
        )
        rows = cur.fetchall()
        conn.commit()
    ok(f"Refreshed velocity features ({n} upserts)")
    table(
        ["type", "entity", "1h", "24h", "spike"],
        [[r[0], r[1], r[2], r[3], r[4]] for r in rows],
    )
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="CardOpsAI Risk Operations CLI")
    p.add_argument("--tenant-id", type=int, default=None)
    sub = p.add_subparsers(dest="command", required=True)
    sub.add_parser("status")
    sub.add_parser("audit")
    sub.add_parser("health", help="System health panel")
    sp = sub.add_parser("stress")
    sp.add_argument("--iterations", type=int, default=1000)
    sp.add_argument("--horizon", type=int, default=30)
    rp = sub.add_parser("rings")
    rp.add_argument("--min-size", type=int, default=3)
    sim = sub.add_parser("simulate")
    sim.add_argument("--rule-id", type=int, required=True)
    sim.add_argument("--new-threshold", type=float, required=True)
    proc = sub.add_parser("process")
    proc.add_argument("--batch-size", type=int, default=100)
    sub.add_parser("snapshot")
    tr = sub.add_parser("triage", help="Alerts ranked by expected loss")
    tr.add_argument("--limit", type=int, default=25)
    sc = sub.add_parser("score", help="Explainable transaction score")
    sc.add_argument("--tx-id", type=int, required=True)
    sh = sub.add_parser("shadow", help="Champion/challenger shadow compare")
    sh.add_argument("--tx-id", type=int, required=True)
    sh.add_argument("--challenger-threshold", type=float, default=35)
    vel = sub.add_parser("velocity", help="Refresh velocity features")
    vel.add_argument("--limit", type=int, default=20)
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    handlers = {
        "status": cmd_status,
        "audit": cmd_audit,
        "health": cmd_health,
        "stress": cmd_stress,
        "rings": cmd_rings,
        "simulate": cmd_simulate,
        "process": cmd_process,
        "snapshot": cmd_snapshot,
        "triage": cmd_triage,
        "score": cmd_score,
        "shadow": cmd_shadow,
        "velocity": cmd_velocity,
    }
    try:
        return handlers[args.command](args)
    except Exception as exc:  # noqa: BLE001
        err(str(exc))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
