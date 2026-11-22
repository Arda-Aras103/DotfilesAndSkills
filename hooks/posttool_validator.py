#!/usr/bin/env python3
"""Antigravity PostToolUse deterministic validator.

Runs fast (<0.5s) syntax and format checks on edited files and tracks unverified
Rust edits per conversation, persisting errors for PreInvocation/Stop hooks
while always emitting `{}` per the PostToolUse contract.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any

from hook_common import (
    WRITE_FILE_TOOLS,
    emit_json,
    extract_command_line,
    extract_file_path,
    load_state,
    read_hook_payload,
    save_state,
    state_file_for,
)

_SKILL_NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
_DICT_FILENAMES = {"kelimeler.md", "vocabulary.md", "dictionary.md", "words.md"}
_CARGO_VERIFY_RE = re.compile(r"\bcargo\s+(?:check|test|clippy|build)\b")
_ZEN_MANIFEST_RE = re.compile(r"/projects/zen-[^/]+/manifest\.json$")


def _resolve_path(raw_path: str, cwd: str | None) -> Path:
    """Resolve raw path against cwd when relative."""
    p = Path(raw_path)
    if not p.is_absolute() and cwd:
        return Path(cwd) / p
    return p


def _sync_workspace_ownership(path: Path, workspace_root: Path | None = None) -> None:
    """Match host UID/GID of newly created/edited workspace files when running as root."""
    if os.geteuid() != 0 or not path.exists():
        return
    root = (workspace_root or Path(__file__).resolve().parent.parent).resolve()
    try:
        root_stat = root.stat()
    except OSError:
        return
    if root_stat.st_uid == 0:
        return
    try:
        resolved = path.resolve()
        resolved.relative_to(root)
    except (OSError, ValueError):
        return
    cur = resolved
    while cur != root:
        try:
            if cur.stat().st_uid == 0:
                os.chown(cur, root_stat.st_uid, root_stat.st_gid)
        except OSError:
            break
        if cur.parent == cur:
            break
        cur = cur.parent


def _validate_skill_md(path: Path) -> list[str]:
    """Verify SKILL.md frontmatter satisfies workspace skill-workshop YAML rules."""
    text = path.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---(?:\n|$)", text, re.S)
    if not m:
        return ["Missing YAML frontmatter block (`--- ... ---`)."]

    errors: list[str] = []
    fm = m.group(1)
    lines = fm.splitlines()

    name_lines = [l for l in lines if l.startswith("name:")]
    if not name_lines:
        errors.append("Missing required `name:` field in frontmatter.")
    else:
        name_val = name_lines[0].split(":", 1)[1].strip()
        if not _SKILL_NAME_RE.match(name_val):
            errors.append(f"Invalid skill `name` ({name_val!r}); must be lowercase-hyphen.")

    desc_idx = next((i for i, l in enumerate(lines) if l.startswith("description:")), None)
    if desc_idx is None:
        errors.append("Missing required `description:` field in frontmatter.")
    else:
        desc_val = lines[desc_idx].split(":", 1)[1].strip()
        if not desc_val or desc_val in {">", ">-", "|", "|-"}:
            errors.append("`description:` must be a single non-empty line (no block scalars).")
        if desc_idx + 1 < len(lines) and lines[desc_idx + 1].startswith(" "):
            errors.append("`description:` must not span multiple lines.")
        if '"' in desc_val or "'" in desc_val:
            errors.append("`description:` must not contain quotes (`\"` or `'`).")
        if ": " in desc_val:
            errors.append("`description:` must not contain `: `.")
        if "<" in desc_val or ">" in desc_val:
            errors.append("`description:` must not contain `<` or `>`.")
    return errors


def _validate_json_file(path: Path) -> list[str]:
    """Parse JSON file and enforce Zen WebExtension gecko.id when applicable."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return [f"Invalid JSON ({exc.msg} at line {exc.lineno}, col {exc.colno})."]
    if _ZEN_MANIFEST_RE.search(path.as_posix()):
        gecko_id = (
            data.get("browser_specific_settings", {}).get("gecko", {}).get("id")
            if isinstance(data, dict)
            else None
        )
        if not isinstance(gecko_id, str) or not gecko_id.strip():
            return ["Zen WebExtension manifest.json must preserve non-empty `browser_specific_settings.gecko.id`."]
    return []


def _validate_shell_file(path: Path) -> list[str]:
    """Syntax-check Bash scripts via `bash -n` without executing them."""
    res = subprocess.run(
        ["bash", "-n", str(path)],
        text=True,
        capture_output=True,
        timeout=2,
        check=False,
    )
    if res.returncode != 0:
        detail = (res.stderr or res.stdout or "bash -n failed").strip().splitlines()[-1]
        return [f"Shell syntax error: {detail}"]
    return []


def _validate_python_file(path: Path) -> list[str]:
    """Syntax-check Python source in memory without creating __pycache__ artifacts."""
    try:
        src = path.read_text(encoding="utf-8")
        compile(src, str(path), "exec")
        return []
    except SyntaxError as exc:
        return [f"Python SyntaxError at line {exc.lineno}: {exc.msg}."]


def _validate_vocabulary_file(path: Path) -> list[str]:
    """Run vocabulary validate_dict.py when a dictionary markdown file changes."""
    script = Path(__file__).resolve().parent.parent / ".agents" / "skills" / "vocabulary" / "scripts" / "validate_dict.py"
    if not script.exists():
        return []
    res = subprocess.run(
        ["python3", str(script), str(path)],
        text=True,
        capture_output=True,
        timeout=3,
        check=False,
    )
    if res.returncode != 0:
        detail = (res.stderr or res.stdout or "validate_dict.py failed").strip().splitlines()[-1]
        return [f"Dictionary validation failed: {detail}"]
    if "Tekrar Eden Kelimeler" in res.stdout:
        return ["Duplicate vocabulary entries detected by validate_dict.py."]
    return []


def validate_edited_file(path: Path) -> tuple[list[str], bool]:
    """Run deterministic checks for path; return (errors, needs_cargo_check)."""
    if not path.exists() or not path.is_file():
        return [], False

    norm = path.as_posix()
    name = path.name
    if norm.endswith("/SKILL.md") and "/.agents/skills/" in norm:
        return _validate_skill_md(path), False
    if path.suffix == ".json":
        return _validate_json_file(path), False
    if path.suffix == ".py":
        return _validate_python_file(path), False
    if path.suffix == ".sh":
        return _validate_shell_file(path), False
    if name in _DICT_FILENAMES:
        return _validate_vocabulary_file(path), False
    if path.suffix == ".rs":
        return [], True
    return [], False


def process_posttool_payload(payload: dict[str, Any], state_dir: str | Path = "/tmp") -> None:
    """Update per-conversation validation state based on a PostToolUse payload."""
    if payload.get("error"):
        return

    tool_call = payload.get("toolCall")
    if not isinstance(tool_call, dict):
        return
    tool_name = str(tool_call.get("name", ""))
    args = tool_call.get("args")
    if not isinstance(args, dict):
        args = {}

    state_path = state_file_for(payload, state_dir)
    state = load_state(state_path)

    if tool_name in WRITE_FILE_TOOLS:
        raw_path = extract_file_path(args)
        if not raw_path:
            return
        target = _resolve_path(raw_path, payload.get("cwd"))
        _sync_workspace_ownership(target)
        key = str(target)
        errors, needs_cargo = validate_edited_file(target)
        if errors:
            state["errors"][key] = errors
        else:
            state["errors"].pop(key, None)
        if needs_cargo and key not in state["pending_cargo"]:
            state["pending_cargo"].append(key)
        save_state(state_path, state)
    elif tool_name == "run_command":
        cmd = extract_command_line(args)
        if _CARGO_VERIFY_RE.search(cmd) and state["pending_cargo"]:
            state["pending_cargo"] = []
            save_state(state_path, state)


def main() -> int:
    """Read stdin JSON, update validation state, and emit `{}` per PostToolUse contract."""
    payload, exc = read_hook_payload()
    if exc is None:
        try:
            process_posttool_payload(payload)
        except Exception:
            pass
    emit_json({})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
