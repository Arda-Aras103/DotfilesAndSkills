#!/usr/bin/env python3
"""Antigravity PreInvocation hook that surfaces PostToolUse validation errors."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from hook_common import emit_json, load_state, read_hook_payload, save_state, state_file_for


def build_preinvocation_response(payload: dict[str, Any], state_dir: str | Path = "/tmp") -> dict[str, Any]:
    """Consume pending validation errors and inject them as a systemMessage."""
    state_path = state_file_for(payload, state_dir)
    state = load_state(state_path)
    errors = state.get("errors") or {}
    if not errors:
        return {}

    lines = ["[PostToolUse Validator] Son dosya düzenlemelerinde doğrulama hatası tespit edildi:"]
    for file_path, errs in errors.items():
        for err in errs:
            lines.append(f"- {file_path}: {err}")

    state["errors"] = {}
    save_state(state_path, state)
    return {"injectSteps": [{"systemMessage": {"systemMessage": "\n".join(lines)}}]}


def main() -> int:
    """Read stdin JSON and emit injectSteps when PostToolUse recorded errors."""
    payload, exc = read_hook_payload()
    if exc is not None:
        emit_json({})
        return 0
    emit_json(build_preinvocation_response(payload))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
