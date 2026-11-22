#!/usr/bin/env python3
"""Shared helpers for Antigravity lifecycle hook scripts."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

WRITE_FILE_TOOLS = frozenset(
    {
        "write_file",
        "edit_file",
        "write_to_file",
        "replace_file_content",
        "multi_replace_file_content",
    }
)

ALL_FILE_TOOLS = WRITE_FILE_TOOLS | frozenset({"read_file", "view_file"})


def read_hook_payload() -> tuple[dict[str, Any], Exception | None]:
    """Read and validate the stdin JSON object passed by Antigravity."""
    raw = sys.stdin.read()
    try:
        payload = json.loads(raw) if raw.strip() else {}
        if not isinstance(payload, dict):
            raise ValueError("Payload must be a JSON object.")
        return payload, None
    except Exception as exc:
        return {}, exc


def emit_json(data: dict[str, Any]) -> None:
    """Write compact JSON response to stdout."""
    sys.stdout.write(json.dumps(data, ensure_ascii=False) + "\n")


def extract_file_path(args: dict[str, Any]) -> str:
    """Extract target file path across CLI and IDE file tool schemas."""
    for key in ("Path", "TargetFile", "AbsolutePath", "path"):
        val = args.get(key)
        if isinstance(val, str) and val.strip():
            return val.strip()
    return ""


def extract_command_line(args: dict[str, Any]) -> str:
    """Extract shell command line across tool argument schemas."""
    for key in ("CommandLine", "command"):
        val = args.get(key)
        if isinstance(val, str) and val.strip():
            return val
    return ""


def state_file_for(payload: dict[str, Any], base_dir: str | Path = "/tmp") -> Path:
    """Return the per-conversation hook state JSON path under base_dir."""
    conv = str(payload.get("conversationId") or "default")
    safe_conv = re.sub(r"[^a-zA-Z0-9_.-]+", "_", conv)[:80] or "default"
    return Path(base_dir) / f"agy-hook-state-{safe_conv}.json"


def load_state(state_path: Path) -> dict[str, Any]:
    """Load persisted hook state safely, returning an empty structure if absent/corrupt."""
    default: dict[str, Any] = {"errors": {}, "pending_cargo": []}
    if not state_path.exists():
        return default
    try:
        data = json.loads(state_path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            return default
        errors = data.get("errors")
        pending = data.get("pending_cargo")
        return {
            "errors": errors if isinstance(errors, dict) else {},
            "pending_cargo": pending if isinstance(pending, list) else [],
        }
    except Exception:
        return default


def save_state(state_path: Path, state: dict[str, Any]) -> None:
    """Persist hook state or remove the file when completely clean."""
    errors = state.get("errors") or {}
    pending = state.get("pending_cargo") or []
    if not errors and not pending:
        try:
            state_path.unlink(missing_ok=True)
        except OSError:
            pass
        return
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(
        json.dumps({"errors": errors, "pending_cargo": pending}, ensure_ascii=False),
        encoding="utf-8",
    )
