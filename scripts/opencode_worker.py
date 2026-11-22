#!/usr/bin/env python3
"""Headless OpenCode worker wrapper and zero-dependency Stdio MCP server."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, TextIO

DEFAULT_WORKSPACE_ROOT = Path("/workspace")
ALLOWED_AGENTS = ("build", "explore", "plan")
DEFAULT_TIMEOUT_SEC = 120
MAX_TIMEOUT_SEC = 600
MCP_PROTOCOL_VERSION = "2025-03-26"

DEFAULT_MODEL_CHAIN = (
    "opencode/deepseek-v4.1-flash-free",
    "opencode/glm-5.3-flash-free",
    "opencode/minimax-m3.1-flash-free",
    "opencode/mimo-v2.6-flash-free",
)

COPILOT_MODEL_CHAIN = (
    "github-copilot/gpt-4.1",
    "github-copilot/claude-sonnet-4",
    "github-copilot/gpt-4o",
    "github-copilot/o3-mini",
)

ENV_FALLBACK_MODELS: tuple[tuple[tuple[str, ...], tuple[str, ...]], ...] = (
    (
        ("OPENROUTER_API_KEY",),
        (
            "openrouter/cohere/north-mini-code:free",
            "openrouter/nvidia/nemotron-3-ultra-550b-a55b:free",
        ),
    ),
    (("NVIDIA_API_KEY",), ("nvidia/deepseek-ai/deepseek-v4.1-flash",)),
    (("GROQ_API_KEY",), ("groq/openai/gpt-oss-120b",)),
    (
        ("GEMINI_API_KEY", "GOOGLE_GENERATIVE_AI_API_KEY"),
        ("google/gemini-2.5-flash", "google/gemini-2.5-flash-lite"),
    ),
)

_SAFE_ENV_SUFFIXES = (".example", ".sample", ".template", ".dist")
_BLOCKED_BASENAMES = {
    "profile.md",
    "ArdaArasCavdur_CV.pdf",
    "epfl-summer-2027-motivation-letter.pdf",
}
_BLOCKED_REL_ROOTS = {"reports", "documents", "context", ".handoffs"}
_BLOCKED_DIR_PARTS = {".ssh", ".gnupg", ".aws", ".gemini"}


def load_model_chain(
    explicit_model: str | None = None,
    env: dict[str, str] | None = None,
) -> list[str]:
    """Return ordered model candidates for a delegated worker run."""
    if explicit_model and explicit_model.strip().lower() not in {"", "auto"}:
        normalized = explicit_model.strip()
        if normalized.lower() in {"copilot", "github-copilot"}:
            return list(COPILOT_MODEL_CHAIN)
        return [normalized]

    source_env = env if env is not None else os.environ
    custom = source_env.get("OPENCODE_WORKER_MODELS", "").strip()
    if custom:
        models = [item.strip() for item in custom.split(",") if item.strip()]
        if models:
            return models

    env_models: list[str] = []
    for env_names, candidates in ENV_FALLBACK_MODELS:
        if any(source_env.get(name, "").strip() for name in env_names):
            for candidate in candidates:
                if candidate not in env_models:
                    env_models.append(candidate)

    # Prefer configured free-tier API providers over Zen's tight anonymous bucket.
    chain = list(env_models)
    for fallback in DEFAULT_MODEL_CHAIN:
        if fallback not in chain:
            chain.append(fallback)
    return chain


def is_sensitive_path(path: Path, allowed_root: Path = DEFAULT_WORKSPACE_ROOT) -> bool:
    """Return True if path points to credentials, personal PII, or protected config."""
    resolved = path.resolve()
    name = resolved.name

    if name == ".env" or (name.startswith(".env.") and not name.endswith(_SAFE_ENV_SUFFIXES)):
        return True
    if name in _BLOCKED_BASENAMES or name.endswith("-motivation-letter.pdf"):
        return True
    if any(part in _BLOCKED_DIR_PARTS for part in resolved.parts):
        return True

    try:
        rel_parts = resolved.relative_to(allowed_root.resolve()).parts
    except ValueError:
        return False
    return bool(rel_parts and rel_parts[0] in _BLOCKED_REL_ROOTS)


def resolve_workdir(
    raw_dir: str | None,
    allowed_root: Path = DEFAULT_WORKSPACE_ROOT,
) -> Path:
    """Resolve and validate working directory inside allowed_root."""
    root_resolved = allowed_root.resolve()
    target = root_resolved if not raw_dir else Path(raw_dir).expanduser().resolve()

    try:
        target.relative_to(root_resolved)
    except ValueError as exc:
        raise ValueError(f"workdir must stay inside {root_resolved}: {target}") from exc

    if not target.is_dir():
        raise ValueError(f"workdir does not exist or is not a directory: {target}")
    if is_sensitive_path(target, root_resolved):
        raise ValueError(f"workdir points to protected directory: {target}")
    return target


def resolve_attach_files(
    files: list[str] | None,
    workdir: Path,
    allowed_root: Path = DEFAULT_WORKSPACE_ROOT,
) -> list[Path]:
    """Validate optional file attachments inside allowed_root and non-sensitive."""
    if not files:
        return []

    root_resolved = allowed_root.resolve()
    resolved_files: list[Path] = []
    for raw in files:
        candidate = Path(raw).expanduser()
        if not candidate.is_absolute():
            candidate = workdir / candidate
        resolved = candidate.resolve()
        try:
            resolved.relative_to(root_resolved)
        except ValueError as exc:
            raise ValueError(f"file must stay inside {root_resolved}: {resolved}") from exc
        if is_sensitive_path(resolved, root_resolved):
            raise ValueError(f"access to protected file is denied: {resolved.name}")
        if not resolved.is_file():
            raise ValueError(f"attached file not found: {resolved}")
        resolved_files.append(resolved)
    return resolved_files


def parse_opencode_ndjson(raw_stdout: str) -> dict[str, Any]:
    """Parse OpenCode `--format json` NDJSON output into structured fields."""
    session_id: str | None = None
    text_chunks: list[str] = []
    tool_events = 0
    tokens = {"input": 0, "output": 0, "reasoning": 0, "cache_read": 0, "cache_write": 0}
    cost = 0.0
    error_obj: dict[str, Any] | None = None
    last_retry_error: dict[str, Any] | None = None
    non_json_lines: list[str] = []

    for line in raw_stdout.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        try:
            event = json.loads(stripped)
        except json.JSONDecodeError:
            non_json_lines.append(stripped)
            continue

        if not isinstance(event, dict):
            continue

        if not session_id and isinstance(event.get("sessionID"), str):
            session_id = event["sessionID"]

        etype = event.get("type")
        part = event.get("part") if isinstance(event.get("part"), dict) else {}

        if etype == "text":
            chunk = part.get("text") if isinstance(part.get("text"), str) else event.get("text")
            if isinstance(chunk, str):
                text_chunks.append(chunk)
        elif etype in {"tool_use", "tool_result", "tool", "tool-invocation"} or str(
            part.get("type", "")
        ).startswith("tool"):
            tool_events += 1
        elif etype == "step_finish":
            if isinstance(part.get("cost"), (int, float)):
                cost += float(part["cost"])
            tok = part.get("tokens")
            if isinstance(tok, dict):
                tokens["input"] += int(tok.get("input", 0) or 0)
                tokens["output"] += int(tok.get("output", 0) or 0)
                tokens["reasoning"] += int(tok.get("reasoning", 0) or 0)
                cache = tok.get("cache")
                if isinstance(cache, dict):
                    tokens["cache_read"] += int(cache.get("read", 0) or 0)
                    tokens["cache_write"] += int(cache.get("write", 0) or 0)
        elif etype == "error":
            err = event.get("error")
            error_obj = err if isinstance(err, dict) else {"message": str(err)}
        elif etype == "retry":
            err = event.get("error")
            last_retry_error = err if isinstance(err, dict) else {"message": str(err)}

    response_text = "".join(text_chunks).strip()
    if not response_text and non_json_lines and error_obj is None:
        response_text = "\n".join(non_json_lines).strip()
    effective_error = error_obj or (last_retry_error if not response_text else None)

    return {
        "session_id": session_id,
        "response_text": response_text,
        "tool_events": tool_events,
        "tokens": tokens,
        "cost": cost,
        "error": effective_error,
        "retry_error": last_retry_error,
        "non_json_lines": non_json_lines,
    }


def is_transient_limit_error(parsed: dict[str, Any], stderr: str, returncode: int) -> bool:
    """Return True when the failure is a rate limit, free cap, or transient outage."""
    err = parsed.get("error")
    if isinstance(err, dict):
        status = err.get("status")
        if status in {429, 502, 503, 504}:
            return True
        err_type = str(err.get("type", "")).lower()
        err_msg = str(err.get("message", "")).lower()
        if "free-limit" in err_type or "rate" in err_type or "limit reached" in err_msg:
            return True

    combined = f"{parsed.get('response_text', '')}\n{stderr}".lower()
    markers = (
        "free usage limit",
        "rate limit",
        "too many requests",
        "429",
        "temporarily unavailable",
        "503",
    )
    return (returncode != 0 or err is not None) and any(marker in combined for marker in markers)


CommandRunner = Callable[[list[str], Path, int], subprocess.CompletedProcess[str]]


def resolve_opencode_bin() -> str | None:
    """Return the OpenCode CLI path from PATH or standard container locations."""
    found = shutil.which("opencode")
    if found:
        return found
    for cand in (
        Path("/root/.opencode/bin/opencode"),
        Path("/root/.local/bin/opencode"),
        Path.home() / ".opencode" / "bin" / "opencode",
        Path.home() / ".local" / "bin" / "opencode",
    ):
        if cand.is_file() and os.access(cand, os.X_OK):
            return str(cand)
    return None


def _default_subprocess_runner(
    cmd: list[str],
    workdir: Path,
    timeout_sec: int,
) -> subprocess.CompletedProcess[str]:
    """Execute opencode subprocess safely without inheriting MCP stdio stdin."""
    env = os.environ.copy()
    cfg_path = DEFAULT_WORKSPACE_ROOT / "configs" / "opencode" / "opencode.json"
    if not env.get("OPENCODE_CONFIG") and cfg_path.is_file():
        env["OPENCODE_CONFIG"] = str(cfg_path)
    return subprocess.run(
        cmd,
        cwd=str(workdir),
        env=env,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout_sec,
        check=False,
    )


def _clamp_timeout(timeout_sec: int | None) -> int:
    """Normalize execution timeout within [10, MAX_TIMEOUT_SEC]."""
    if timeout_sec is None:
        return DEFAULT_TIMEOUT_SEC
    return max(10, min(int(timeout_sec), MAX_TIMEOUT_SEC))


def _default_ledger_path() -> Path:
    state_dir = os.environ.get("AI_QUOTA_STATE_DIR", "").strip()
    base = Path(state_dir) if state_dir else Path.home() / ".gemini" / "ai-quota"
    return base / "ledger.jsonl"


def record_usage_ledger(
    *,
    model: str,
    agent: str,
    ok: bool,
    tokens: dict[str, Any] | None = None,
    cost: float = 0.0,
    error: dict[str, Any] | None = None,
    ledger_path: Path | None = None,
) -> None:
    """Append non-sensitive usage and rate-limit metadata to persistent ledger."""
    if os.environ.get("AI_QUOTA_DISABLE_LEDGER", "").strip() == "1":
        return
    target = ledger_path or _default_ledger_path()
    provider_id = model.split("/", 1)[0] if "/" in model else "unknown"
    err = error if isinstance(error, dict) else {}
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "provider": provider_id,
        "model": model,
        "agent": agent,
        "ok": ok,
        "status": err.get("status"),
        "error_type": err.get("type"),
        "retry_after_ms": err.get("retryAfterMs"),
        "tokens": tokens or {},
        "cost": cost,
    }
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(entry, ensure_ascii=False, separators=(",", ":")) + "\n")
    except OSError:
        pass


def run_opencode_task(
    prompt: str,
    model: str | None = None,
    agent: str = "build",
    workdir: str | None = None,
    files: list[str] | None = None,
    timeout_sec: int | None = None,
    allowed_root: Path = DEFAULT_WORKSPACE_ROOT,
    runner: CommandRunner | None = None,
    ledger_path: Path | None = None,
) -> dict[str, Any]:
    """Run a delegated OpenCode task with automatic fallback on rate limits."""
    clean_prompt = prompt.strip()
    if not clean_prompt:
        raise ValueError("prompt must not be empty")
    if agent not in ALLOWED_AGENTS:
        raise ValueError(f"agent must be one of {ALLOWED_AGENTS}, got {agent!r}")

    bin_path = "opencode" if runner is not None else resolve_opencode_bin()
    if not bin_path:
        return {
            "ok": False,
            "error": {"message": "opencode binary not found on PATH; run scripts/copilot-subagent-setup.sh"},
            "attempts": [],
        }

    resolved_dir = resolve_workdir(workdir, allowed_root=allowed_root)
    attached = resolve_attach_files(files, resolved_dir, allowed_root=allowed_root)
    timeout = _clamp_timeout(timeout_sec)
    models = load_model_chain(model)
    exec_fn = runner or _default_subprocess_runner

    attempts: list[dict[str, Any]] = []
    exhausted_providers: set[str] = set()
    last_result: dict[str, Any] | None = None
    should_log = ledger_path is not None or runner is None

    for candidate_model in models:
        provider_id = candidate_model.split("/", 1)[0]
        if provider_id in exhausted_providers:
            continue

        cmd = [
            bin_path,
            "run",
            "--standalone",
            "--auto",
            "--archived",
            "--format",
            "json",
            "-m",
            candidate_model,
            "--agent",
            agent,
        ]
        for file_path in attached:
            cmd.extend(["--file", str(file_path)])
        cmd.append(clean_prompt)

        try:
            proc = exec_fn(cmd, resolved_dir, timeout)
        except subprocess.TimeoutExpired as exc:
            partial_out = exc.stdout.decode("utf-8", errors="replace") if isinstance(exc.stdout, bytes) else (exc.stdout or "")
            partial_err = exc.stderr.decode("utf-8", errors="replace") if isinstance(exc.stderr, bytes) else (exc.stderr or "")
            parsed = parse_opencode_ndjson(partial_out)
            err_detail = parsed["error"] or {"message": f"opencode timed out after {timeout}s"}
            attempts.append({"model": candidate_model, "error": err_detail})
            if should_log:
                record_usage_ledger(
                    model=candidate_model,
                    agent=agent,
                    ok=False,
                    tokens=parsed["tokens"],
                    cost=parsed["cost"],
                    error=err_detail,
                    ledger_path=ledger_path,
                )
            last_result = {
                "ok": False,
                "model_used": candidate_model,
                "agent": agent,
                "workdir": str(resolved_dir),
                "attempts": attempts,
                "session_id": parsed["session_id"],
                "response_text": parsed["response_text"],
                "error": err_detail,
            }
            if parsed["error"] and is_transient_limit_error(parsed, partial_err, 1):
                continue
            return last_result

        parsed = parse_opencode_ndjson(proc.stdout)
        failed = proc.returncode != 0 or parsed["error"] is not None
        attempts.append(
            {
                "model": candidate_model,
                "returncode": proc.returncode,
                "error": parsed["error"],
            }
        )
        if should_log:
            record_usage_ledger(
                model=candidate_model,
                agent=agent,
                ok=not failed,
                tokens=parsed["tokens"],
                cost=parsed["cost"],
                error=parsed["error"],
                ledger_path=ledger_path,
            )

        if not failed:
            return {
                "ok": True,
                "model_used": candidate_model,
                "agent": agent,
                "workdir": str(resolved_dir),
                "attempts": attempts,
                "session_id": parsed["session_id"],
                "response_text": parsed["response_text"],
                "tool_events": parsed["tool_events"],
                "tokens": parsed["tokens"],
                "cost": parsed["cost"],
            }

        last_result = {
            "ok": False,
            "model_used": candidate_model,
            "agent": agent,
            "workdir": str(resolved_dir),
            "attempts": attempts,
            "session_id": parsed["session_id"],
            "response_text": parsed["response_text"],
            "error": parsed["error"] or {"message": proc.stderr.strip() or f"exit code {proc.returncode}"},
        }

        if not is_transient_limit_error(parsed, proc.stderr, proc.returncode):
            return last_result

        err_type = str((parsed.get("error") or {}).get("type", "")).lower()
        if err_type == "provider.free-limit":
            exhausted_providers.add(provider_id)

    return last_result or {"ok": False, "attempts": attempts, "error": {"message": "no models attempted"}}


def list_opencode_models(
    timeout_sec: int = 20,
    runner: CommandRunner | None = None,
) -> dict[str, Any]:
    """List models currently available to OpenCode."""
    bin_path = "opencode" if runner is not None else resolve_opencode_bin()
    if not bin_path:
        return {"ok": False, "models": [], "error": "opencode binary not found on PATH"}

    exec_fn = runner or _default_subprocess_runner
    proc = exec_fn([bin_path, "--standalone", "models"], Path.cwd(), timeout_sec)
    if proc.returncode != 0:
        return {"ok": False, "models": [], "error": proc.stderr.strip() or f"exit {proc.returncode}"}

    models = [line.strip() for line in proc.stdout.splitlines() if "/" in line.strip()]
    return {"ok": True, "models": models, "default_chain": list(DEFAULT_MODEL_CHAIN)}


def _run_tool_input_schema(default_model: str) -> dict[str, Any]:
    """Build shared JSON Schema for opencode_run and copilot_subagent tools."""
    model_desc = (
        "Optional github-copilot/<model> ID, or 'copilot' for Copilot fallback chain."
        if default_model == "copilot"
        else "Optional provider/model ID, or 'auto' for the free fallback chain."
    )
    return {
        "type": "object",
        "properties": {
            "prompt": {
                "type": "string",
                "description": "Clear, self-contained task description and Definition of Done.",
            },
            "model": {
                "type": "string",
                "description": model_desc,
                "default": default_model,
            },
            "agent": {
                "type": "string",
                "enum": list(ALLOWED_AGENTS),
                "description": "OpenCode agent mode: build (read/write), explore (read-only), or plan.",
                "default": "build",
            },
            "workdir": {
                "type": "string",
                "description": "Working directory inside /workspace (defaults to /workspace).",
                "default": str(DEFAULT_WORKSPACE_ROOT),
            },
            "files": {
                "type": "array",
                "items": {"type": "string"},
                "description": "Optional workspace files to attach to the prompt.",
            },
            "timeout_sec": {
                "type": "integer",
                "description": "Execution timeout in seconds (10-600, default 120).",
                "default": DEFAULT_TIMEOUT_SEC,
            },
        },
        "required": ["prompt"],
    }


def _mcp_tool_definitions() -> list[dict[str, Any]]:
    """Return MCP tool schemas exposed by opencode-worker."""
    return [
        {
            "name": "opencode_run",
            "description": (
                "Delegate a scoped coding, refactoring, test-writing, or codebase exploration task "
                "to the local headless OpenCode worker using free models with automatic rate-limit fallback."
            ),
            "inputSchema": _run_tool_input_schema("auto"),
        },
        {
            "name": "opencode_models",
            "description": "List active OpenCode models and the default free fallback chain.",
            "inputSchema": {
                "type": "object",
                "properties": {},
            },
        },
        {
            "name": "copilot_subagent",
            "description": (
                "Delegate a scoped coding, refactoring, or debugging task to the GitHub Copilot subagent "
                "via OpenCode's github-copilot provider chain."
            ),
            "inputSchema": _run_tool_input_schema("copilot"),
        },
    ]


def _jsonrpc_result(msg_id: Any, result: Any) -> dict[str, Any]:
    return {"jsonrpc": "2.0", "id": msg_id, "result": result}


def _jsonrpc_error(msg_id: Any, code: int, message: str) -> dict[str, Any]:
    return {"jsonrpc": "2.0", "id": msg_id, "error": {"code": code, "message": message}}


def handle_mcp_message(
    msg: dict[str, Any],
    allowed_root: Path = DEFAULT_WORKSPACE_ROOT,
    runner: CommandRunner | None = None,
) -> dict[str, Any] | None:
    """Handle one parsed JSON-RPC 2.0 MCP message; return None for notifications."""
    msg_id = msg.get("id")
    method = msg.get("method")
    params = msg.get("params") if isinstance(msg.get("params"), dict) else {}

    if msg_id is None:
        return None

    if method == "initialize":
        req_version = params.get("protocolVersion")
        protocol_version = req_version if isinstance(req_version, str) and req_version else MCP_PROTOCOL_VERSION
        return _jsonrpc_result(
            msg_id,
            {
                "protocolVersion": protocol_version,
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "opencode-worker", "version": "1.0.0"},
            },
        )

    if method == "ping":
        return _jsonrpc_result(msg_id, {})

    if method == "tools/list":
        return _jsonrpc_result(msg_id, {"tools": _mcp_tool_definitions()})

    if method == "tools/call":
        name = params.get("name")
        args = params.get("arguments") if isinstance(params.get("arguments"), dict) else {}
        try:
            if name == "opencode_models":
                res = list_opencode_models(runner=runner)
                return _jsonrpc_result(
                    msg_id,
                    {
                        "content": [{"type": "text", "text": json.dumps(res, ensure_ascii=False, indent=2)}],
                        "isError": not res.get("ok", False),
                    },
                )
            if name in {"opencode_run", "copilot_subagent"}:
                selected_model = args.get("model")
                if name == "copilot_subagent" and not selected_model:
                    selected_model = "copilot"
                res = run_opencode_task(
                    prompt=str(args.get("prompt", "")),
                    model=selected_model,
                    agent=str(args.get("agent") or "build"),
                    workdir=args.get("workdir"),
                    files=args.get("files"),
                    timeout_sec=args.get("timeout_sec"),
                    allowed_root=allowed_root,
                    runner=runner,
                )
                return _jsonrpc_result(
                    msg_id,
                    {
                        "content": [{"type": "text", "text": json.dumps(res, ensure_ascii=False, indent=2)}],
                        "isError": not res.get("ok", False),
                    },
                )
            return _jsonrpc_error(msg_id, -32601, f"Unknown tool: {name}")
        except (ValueError, TypeError) as exc:
            return _jsonrpc_result(
                msg_id,
                {
                    "content": [{"type": "text", "text": json.dumps({"ok": False, "error": str(exc)})}],
                    "isError": True,
                },
            )

    return _jsonrpc_error(msg_id, -32601, f"Method not found: {method}")


def serve_mcp(
    stdin: TextIO = sys.stdin,
    stdout: TextIO = sys.stdout,
    stderr: TextIO = sys.stderr,
    allowed_root: Path = DEFAULT_WORKSPACE_ROOT,
    runner: CommandRunner | None = None,
) -> int:
    """Serve newline-delimited JSON-RPC 2.0 MCP messages over stdio."""
    for raw_line in stdin:
        line = raw_line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError as exc:
            err = _jsonrpc_error(None, -32700, f"Parse error: {exc.msg}")
            stdout.write(json.dumps(err, separators=(",", ":")) + "\n")
            stdout.flush()
            continue

        if not isinstance(msg, dict):
            err = _jsonrpc_error(None, -32600, "Invalid Request")
            stdout.write(json.dumps(err, separators=(",", ":")) + "\n")
            stdout.flush()
            continue

        try:
            resp = handle_mcp_message(msg, allowed_root=allowed_root, runner=runner)
        except Exception as exc:  # pragma: no cover - defensive boundary
            print(f"[opencode-worker] unhandled error: {exc}", file=stderr)
            resp = (
                _jsonrpc_error(msg.get("id"), -32603, f"Internal error: {exc}")
                if msg.get("id") is not None
                else None
            )

        if resp is not None:
            stdout.write(json.dumps(resp, ensure_ascii=False, separators=(",", ":")) + "\n")
            stdout.flush()
    return 0


def _build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Headless OpenCode worker & MCP server")
    sub = parser.add_subparsers(dest="command", required=True)

    run_p = sub.add_parser("run", help="Run a delegated OpenCode prompt")
    run_p.add_argument("--prompt", "-p", required=True, help="Task prompt")
    run_p.add_argument("--model", "-m", default="auto", help="Model ID or 'auto'")
    run_p.add_argument("--agent", default="build", choices=ALLOWED_AGENTS)
    run_p.add_argument("--workdir", default=str(DEFAULT_WORKSPACE_ROOT))
    run_p.add_argument("--file", "-f", action="append", dest="files", help="Attach file")
    run_p.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT_SEC)

    sub.add_parser("models", help="List available OpenCode models")
    sub.add_parser("mcp", help="Run Stdio MCP server")
    return parser


def main(argv: list[str] | None = None) -> int:
    """CLI entrypoint."""
    args = _build_arg_parser().parse_args(argv)
    if args.command == "mcp":
        return serve_mcp()
    if args.command == "models":
        res = list_opencode_models()
        print(json.dumps(res, ensure_ascii=False, indent=2))
        return 0 if res.get("ok") else 1
    if args.command == "run":
        res = run_opencode_task(
            prompt=args.prompt,
            model=args.model,
            agent=args.agent,
            workdir=args.workdir,
            files=args.files,
            timeout_sec=args.timeout,
        )
        print(json.dumps(res, ensure_ascii=False, indent=2))
        return 0 if res.get("ok") else 1
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
