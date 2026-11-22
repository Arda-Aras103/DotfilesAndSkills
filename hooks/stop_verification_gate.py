#!/usr/bin/env python3
"""Antigravity Stop verification gate for unverified code edits."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from hook_common import emit_json, load_state, read_hook_payload, save_state, state_file_for


def evaluate_stop_payload(payload: dict[str, Any], state_dir: str | Path = "/tmp") -> dict[str, str]:
    """Request one continuation pass if validation errors or unverified Rust edits remain."""
    if payload.get("continuationActive"):
        return {}
    if payload.get("terminationReason") != "NO_TOOL_CALL":
        return {}

    state_path = state_file_for(payload, state_dir)
    state = load_state(state_path)
    errors = state.get("errors") or {}
    pending_cargo = state.get("pending_cargo") or []
    if not errors and not pending_cargo:
        return {}

    reasons: list[str] = []
    if errors:
        reasons.append(f"Doğrulama hatası kalan dosyalar: {', '.join(errors.keys())}")
    if pending_cargo:
        reasons.append(f"Henüz cargo check/test çalıştırılmamış Rust dosyaları: {', '.join(pending_cargo)}")

    # Clear pending state after nagging once; continuationActive also guards against loops.
    state["errors"] = {}
    state["pending_cargo"] = []
    save_state(state_path, state)
    return {
        "decision": "continue",
        "reason": "Durmadan önce kontrol et: " + " | ".join(reasons),
    }


def main() -> int:
    """Read stdin JSON and emit Stop decision."""
    payload, exc = read_hook_payload()
    if exc is not None:
        emit_json({})
        return 0
    emit_json(evaluate_stop_payload(payload))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
