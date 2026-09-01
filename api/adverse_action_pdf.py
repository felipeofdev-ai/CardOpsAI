"""Generate adverse action PDF letters from CardOps decision explainability."""

from __future__ import annotations

import json
from io import BytesIO
from typing import Any

from fpdf import FPDF


def build_adverse_action_pdf(explanation: dict[str, Any], tenant_name: str = "CardOps Tenant") -> bytes:
    pdf = FPDF()
    pdf.set_auto_page_break(auto=True, margin=15)
    pdf.add_page()
    pdf.set_font("Helvetica", "B", 16)
    pdf.cell(0, 10, "Adverse Action Notice", ln=True)
    pdf.set_font("Helvetica", "", 10)
    pdf.cell(0, 8, f"Tenant: {tenant_name}", ln=True)
    pdf.cell(0, 8, f"Transaction ID: {explanation.get('transaction_id', 'N/A')}", ln=True)
    pdf.ln(4)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "Decision Summary", ln=True)
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(
        0,
        6,
        f"Action: {explanation.get('action', 'N/A')}\n"
        f"Risk Score: {explanation.get('score', 'N/A')}\n"
        f"Expected Loss: {explanation.get('expected_loss', 'N/A')}",
    )
    pdf.ln(4)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "Principal Reasons (Regulatory Codes)", ln=True)
    pdf.set_font("Helvetica", "", 10)
    codes = explanation.get("adverse_action_codes", [])
    if isinstance(codes, str):
        codes = json.loads(codes)
    if not codes:
        pdf.cell(0, 6, "No adverse codes recorded.", ln=True)
    else:
        for code in codes:
            pdf.cell(0, 6, f"- {code}", ln=True)
    pdf.ln(4)
    pdf.set_font("Helvetica", "B", 12)
    pdf.cell(0, 8, "Factor Contributions", ln=True)
    pdf.set_font("Helvetica", "", 9)
    for factor in explanation.get("factors", []):
        if isinstance(factor, str):
            factor = json.loads(factor)
        pdf.multi_cell(
            0,
            5,
            f"* {factor.get('factor')}: fired={factor.get('fired')} weight={factor.get('weight')}",
        )
    pdf.ln(6)
    pdf.set_font("Helvetica", "I", 9)
    pdf.multi_cell(
        0,
        5,
        "This notice is generated from CardOpsAI tamper-evident decision ledger. "
        "You have the right to dispute this decision and request a human review.",
    )
    out = BytesIO()
    pdf.output(out)
    return out.getvalue()
