"""Generate adverse action PDF letters from CardOps decision explainability."""

from __future__ import annotations

import json
from io import BytesIO
from typing import Any

from fpdf import FPDF
from fpdf.enums import XPos, YPos


def _safe_text(value: Any, max_len: int = 240) -> str:
    text = str(value if value is not None else "N/A")
    text = text.encode("latin-1", "replace").decode("latin-1")
    if len(text) > max_len:
        return text[: max_len - 3] + "..."
    return text


def _content_width(pdf: FPDF) -> float:
    return pdf.w - pdf.l_margin - pdf.r_margin


def _heading(pdf: FPDF, text: str, size: int = 12) -> None:
    pdf.set_font("Helvetica", "B", size)
    pdf.cell(
        _content_width(pdf),
        8,
        _safe_text(text, 120),
        new_x=XPos.LMARGIN,
        new_y=YPos.NEXT,
    )


def _body_line(pdf: FPDF, text: str, h: float = 6) -> None:
    pdf.set_font("Helvetica", "", 10)
    pdf.multi_cell(_content_width(pdf), h, _safe_text(text))


def build_adverse_action_pdf(explanation: dict[str, Any], tenant_name: str = "CardOps Tenant") -> bytes:
    pdf = FPDF()
    pdf.set_auto_page_break(auto=True, margin=15)
    pdf.set_margins(15, 15, 15)
    pdf.add_page()

    pdf.set_font("Helvetica", "B", 16)
    pdf.cell(
        _content_width(pdf),
        10,
        "Adverse Action Notice",
        new_x=XPos.LMARGIN,
        new_y=YPos.NEXT,
    )

    pdf.set_font("Helvetica", "", 10)
    _body_line(pdf, f"Tenant: {tenant_name}")
    _body_line(pdf, f"Transaction ID: {explanation.get('transaction_id', 'N/A')}")
    pdf.ln(4)

    _heading(pdf, "Decision Summary")
    _body_line(
        pdf,
        f"Action: {explanation.get('action', 'N/A')}\n"
        f"Risk Score: {explanation.get('score', 'N/A')}\n"
        f"Expected Loss: {explanation.get('expected_loss', 'N/A')}",
    )
    pdf.ln(4)

    _heading(pdf, "Principal Reasons (Regulatory Codes)")
    codes = explanation.get("adverse_action_codes", [])
    if isinstance(codes, str):
        codes = json.loads(codes)
    if not codes:
        _body_line(pdf, "No adverse codes recorded.")
    else:
        for code in codes:
            _body_line(pdf, f"- {code}")

    pdf.ln(4)
    _heading(pdf, "Factor Contributions")
    pdf.set_font("Helvetica", "", 9)
    for factor in explanation.get("factors", []):
        if isinstance(factor, str):
            factor = json.loads(factor)
        name = _safe_text(factor.get("factor", "unknown"), 80)
        fired = _safe_text(factor.get("fired", ""), 10)
        weight = _safe_text(factor.get("weight", ""), 20)
        pdf.multi_cell(
            _content_width(pdf),
            5,
            f"* {name}: fired={fired} weight={weight}",
        )

    pdf.ln(6)
    pdf.set_font("Helvetica", "I", 9)
    pdf.multi_cell(
        _content_width(pdf),
        5,
        "This notice is generated from CardOpsAI tamper-evident decision ledger. "
        "You have the right to dispute this decision and request a human review.",
    )

    out = BytesIO()
    pdf.output(out)
    return out.getvalue()
