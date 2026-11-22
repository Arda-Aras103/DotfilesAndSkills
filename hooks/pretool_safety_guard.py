#!/usr/bin/env python3
"""Antigravity PreToolUse safety guard hook for shell and file tools.

Reads Antigravity hook JSON on stdin and emits a valid decision JSON on stdout:
- "deny": hard-block catastrophic commands or private credential reads.
- "force_ask": force interactive confirmation (ignoring cached Always Allow).
- "allow": delegate normally to Antigravity's default policy engine (never auto_approve).
"""

from __future__ import annotations

import posixpath
import re
import shlex
from pathlib import PurePosixPath
from typing import Any

from hook_common import (
    ALL_FILE_TOOLS,
    WRITE_FILE_TOOLS,
    emit_json,
    extract_command_line,
    extract_file_path,
    read_hook_payload,
)

_SEPARATORS = {";", "&&", "||", "|", "\n"}
_WRAPPERS = {"sudo", "env", "nohup", "command", "time"}

_DANGEROUS_RM_ROOTS = {
    "/",
    "/*",
    ".",
    "..",
    "./",
    "../",
    "~",
    "~/",
    "~/*",
    "$HOME",
    "$HOME/",
    "$HOME/*",
    "${HOME}",
    "${HOME}/",
    "${HOME}/*",
    "/home",
    "/root",
    "/etc",
    "/usr",
    "/var",
    "/boot",
    "/bin",
    "/sbin",
    "/lib",
    "/lib64",
    "/opt",
    "/sys",
    "/proc",
    "/dev",
    "/workspace",
}

_PROTECTED_GLOB_PARENTS = {
    "/home",
    "/root",
    "/etc",
    "/usr",
    "/var",
    "/boot",
    "/workspace",
}

_FORK_BOMB_RE = re.compile(r":\(\)\s*\{[^}]*:\s*\|\s*:[^}]*\}")
_RAW_DISK_RE = re.compile(
    r"\b(?:mkfs(?:\.[a-z0-9_]+)?|wipefs)\b|\bdd\b[^\n]*\bof=/dev/(?:sd|nvme|vd|hd|xvd|mmcblk|disk)"
)
_PIPE_TO_SHELL_RE = re.compile(
    r"\b(?:curl|wget)\b[^|;\n]*\|\s*(?:sudo\s+|env\s+)?(?:ba|z|da|k)?sh\b"
    r"|\b(?:curl|wget)\b[^|;\n]*\|\s*(?:sudo\s+|env\s+)?(?:python3?|perl|ruby)\b"
)
_SECRET_FILE_CMD_RE = re.compile(
    r"(?:~|/home/[^/\s]+|/root)?/\.ssh/id_[a-zA-Z0-9_.-]+(?<!\.pub)(?=$|[\s\"';|&])"
    r"|/etc/(?:shadow|gshadow)(?=$|[\s\"';|&])"
    r"|(?:~|/home/[^/\s]+|/root)/\.gnupg/private-keys"
    r"|(?:~|/home/[^/\s]+|/root)/\.aws/credentials(?=$|[\s\"';|&])"
    r"|(?:~|/home/[^/\s]+|/root)/\.(?:netrc|git-credentials)(?=$|[\s\"';|&])"
    r"|(?:~|/home/[^/\s]+|/root)/\.gemini/antigravity-cli/antigravity-oauth-token(?=$|[\s\"';|&])"
)
_NET_TOOL_RE = re.compile(r"\b(?:curl|wget|nc|ncat|socat|scp|rsync|ssh)\b")
_SECRET_ENV_RE = re.compile(
    r"\b(?:OPENAI_API_KEY|GEMINI_API_KEY|ANTHROPIC_API_KEY|AWS_SECRET_ACCESS_KEY|GH_TOKEN|GITHUB_TOKEN)\b"
)
_HOOK_SELF_SUFFIXES = (
    "/.agents/hooks.json",
    "/scripts/pretool_safety_guard.py",
    "/scripts/posttool_validator.py",
    "/scripts/preinvocation_feedback.py",
    "/scripts/stop_verification_gate.py",
    "/scripts/session_start_context.py",
    "/scripts/hook_common.py",
    "/scripts/opencode_worker.py",
)
_HOOK_MUTATION_CMD_RE = re.compile(
    r"(?:>|>>|\b(?:rm|mv|cp|tee|sed\s+-i|truncate)\b)[^\n]*(?:\.agents/hooks\.json|pretool_safety_guard\.py|posttool_validator\.py|preinvocation_feedback\.py|stop_verification_gate\.py|session_start_context\.py|hook_common\.py|opencode_worker\.py)"
)
_ENV_SAFE_SUFFIXES = (".example", ".sample", ".template", ".dist")
_SHELL_INTERPRETERS = {"sh", "bash", "zsh", "dash", "ksh"}


def _split_shell_segments(command: str) -> list[list[str]]:
    """Split a shell command string into pipeline/statement token lists."""
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";|&")
    lexer.whitespace_split = True
    segments: list[list[str]] = []
    current: list[str] = []
    try:
        for tok in lexer:
            if tok in _SEPARATORS:
                if current:
                    segments.append(current)
                    current = []
            else:
                current.append(tok)
        if current:
            segments.append(current)
    except ValueError:
        for part in re.split(r"(?:&&|\|\||[;\n|])+", command):
            toks = part.strip().split()
            if toks:
                segments.append(toks)
    return segments


def _unwrap_command(tokens: list[str]) -> tuple[bool, list[str]]:
    """Strip leading env assignments and wrapper binaries; report whether sudo appeared."""
    idx = 0
    saw_sudo = False
    while idx < len(tokens):
        tok = tokens[idx]
        if "=" in tok and not tok.startswith(("/", ".", "-")) and tok.split("=", 1)[0].isidentifier():
            idx += 1
            continue
        base = posixpath.basename(tok)
        if base in _WRAPPERS:
            if base == "sudo":
                saw_sudo = True
            idx += 1
            while idx < len(tokens) and tokens[idx].startswith("-"):
                flag = tokens[idx]
                idx += 1
                if base == "sudo" and flag in {"-u", "-g", "-C"} and idx < len(tokens):
                    idx += 1
            continue
        break
    return saw_sudo, tokens[idx:]


def _is_dangerous_rm_target(raw_target: str) -> bool:
    """Return True if an rm target points to root, home, system dirs, or /workspace root."""
    if not raw_target:
        return False
    stripped = raw_target.strip().strip("\"'")
    if stripped in _DANGEROUS_RM_ROOTS:
        return True
    if stripped.endswith("/*") and posixpath.normpath(stripped[:-2] or "/") in _PROTECTED_GLOB_PARENTS:
        return True

    for prefix in ("$HOME/", "${HOME}/", "~/"):
        if stripped.startswith(prefix):
            rel = stripped[len(prefix) :]
            norm_rel = posixpath.normpath(rel) if rel else "."
            if norm_rel in {".", "..", ".ssh", ".gnupg", ".aws"} or norm_rel.startswith(("../", "*")):
                return True
            return False

    if stripped.startswith("/"):
        norm = posixpath.normpath(stripped)
        if norm in _DANGEROUS_RM_ROOTS:
            return True
        parts = [p for p in norm.split("/") if p]
        if len(parts) == 2 and parts[0] == "home":
            return True
    return False


def _evaluate_rm_segment(cmd_tokens: list[str], saw_sudo: bool) -> tuple[str, str] | None:
    """Inspect an rm invocation for catastrophic targets or sudo usage."""
    recursive = False
    targets: list[str] = []
    end_of_opts = False
    for tok in cmd_tokens[1:]:
        if not end_of_opts and tok == "--":
            end_of_opts = True
            continue
        if not end_of_opts and tok.startswith("-"):
            if tok == "--recursive" or (not tok.startswith("--") and any(c in tok[1:] for c in ("r", "R"))):
                recursive = True
            continue
        targets.append(tok)

    if recursive:
        for target in targets:
            if _is_dangerous_rm_target(target):
                return ("deny", f"Blocked recursive rm on protected path: {target}")
    if saw_sudo:
        return ("force_ask", "Confirm privileged rm command explicitly.")
    return None


def _is_sensitive_env_file(path_str: str) -> bool:
    """Return True for active .env files while ignoring .env.example/.sample templates."""
    name = PurePosixPath(path_str.rstrip("/")).name
    if not (name == ".env" or name.startswith(".env.")):
        return False
    return not name.endswith(_ENV_SAFE_SUFFIXES)


def _is_destructive_git(cmd_tokens: list[str]) -> bool:
    """Detect force-push, hard-reset, clean -fd/-fdx, or branch -D within tokenized git args."""
    if len(cmd_tokens) < 2:
        return False
    sub = cmd_tokens[1]
    rest = cmd_tokens[2:]
    if sub == "push":
        for tok in rest:
            if tok in {"--force", "-f"} or (tok.startswith("+") and len(tok) > 1):
                return True
    elif sub == "reset" and "--hard" in rest:
        return True
    elif sub == "branch" and "-D" in rest:
        return True
    elif sub == "clean":
        has_f = any(t == "--force" or (t.startswith("-") and not t.startswith("--") and "f" in t[1:]) for t in rest)
        has_d = any(t.startswith("-") and not t.startswith("--") and "d" in t[1:] for t in rest)
        if has_f and has_d:
            return True
    return False


def _extract_shell_c_payload(cmd_tokens: list[str]) -> str | None:
    """Return the inner script string if invoking `sh/bash -c <script>`."""
    for i, tok in enumerate(cmd_tokens[1:], start=1):
        if tok.startswith("-") and not tok.startswith("--") and "c" in tok[1:]:
            if i + 1 < len(cmd_tokens):
                return cmd_tokens[i + 1]
            return None
        if not tok.startswith("-"):
            return None
    return None


def _check_command(command: str, depth: int = 0) -> tuple[str, str]:
    """Evaluate a shell CommandLine and return (decision, reason)."""
    if not command.strip() or depth > 3:
        return ("allow", "")

    if _FORK_BOMB_RE.search(command):
        return ("deny", "Blocked fork-bomb pattern.")
    if _RAW_DISK_RE.search(command):
        return ("deny", "Blocked raw disk formatting or block-device overwrite command.")
    if _SECRET_FILE_CMD_RE.search(command):
        return ("deny", "Blocked direct access to private keys, OAuth tokens, or system shadow credentials.")
    if _NET_TOOL_RE.search(command) and _SECRET_ENV_RE.search(command):
        return ("deny", "Blocked potential network exfiltration of sensitive API keys/tokens.")

    segments = _split_shell_segments(command)
    needs_force_ask: str | None = None

    for seg in segments:
        saw_sudo, cmd_tokens = _unwrap_command(seg)
        if not cmd_tokens:
            continue
        cmd_name = posixpath.basename(cmd_tokens[0])

        if cmd_name == "rm":
            rm_res = _evaluate_rm_segment(cmd_tokens, saw_sudo)
            if rm_res:
                if rm_res[0] == "deny":
                    return rm_res
                needs_force_ask = needs_force_ask or rm_res[1]

        if cmd_name in _SHELL_INTERPRETERS:
            inner = _extract_shell_c_payload(cmd_tokens)
            if inner:
                inner_dec, inner_reason = _check_command(inner, depth + 1)
                if inner_dec == "deny":
                    return (inner_dec, inner_reason)
                if inner_dec == "force_ask":
                    needs_force_ask = needs_force_ask or inner_reason

        if cmd_name == "git" and _is_destructive_git(cmd_tokens):
            needs_force_ask = needs_force_ask or "Confirm destructive git operation (--force / --hard / clean -fd / -D)."

        if cmd_name == "chmod":
            joined = " ".join(cmd_tokens)
            targets = [t for t in cmd_tokens[1:] if not t.startswith("-")]
            if re.search(r"\b0?777\b|\ba\+rwx\b", joined):
                if any(_is_dangerous_rm_target(t) for t in targets):
                    return ("deny", "Blocked 777 permissions on protected system or workspace root path.")
                needs_force_ask = needs_force_ask or "Confirm overly permissive chmod (777 / a+rwx)."

        if cmd_name in {"printenv", "env"} and len(cmd_tokens) == 1:
            needs_force_ask = needs_force_ask or "Confirm dumping full environment variables."
        elif cmd_name == "printenv" and any(_SECRET_ENV_RE.search(t) for t in cmd_tokens[1:]):
            needs_force_ask = needs_force_ask or "Confirm reading sensitive environment variable."

        if cmd_name in {"cat", "head", "tail", "less", "more", "grep", "rg", "sed", "awk"}:
            for tok in cmd_tokens[1:]:
                if not tok.startswith("-") and _is_sensitive_env_file(tok):
                    needs_force_ask = needs_force_ask or f"Confirm reading sensitive env file: {tok}"

    if _PIPE_TO_SHELL_RE.search(command):
        needs_force_ask = needs_force_ask or "Confirm piping remote script directly into an interpreter."
    if _HOOK_MUTATION_CMD_RE.search(command):
        needs_force_ask = needs_force_ask or "Confirm modifying safety hook configuration or guard scripts."

    if needs_force_ask:
        return ("force_ask", needs_force_ask)
    return ("allow", "")


def _check_file_tool(tool_name: str, path_str: str) -> tuple[str, str]:
    """Evaluate file tool Path arguments for private credential or hook tampering."""
    if not path_str.strip():
        return ("allow", "")

    norm = posixpath.normpath(path_str.strip().replace("\\", "/"))
    if _SECRET_FILE_CMD_RE.search(norm) or ("/.ssh/id_" in norm and not norm.endswith(".pub")):
        return ("deny", f"Blocked file access to protected credential path: {path_str}")
    if _is_sensitive_env_file(norm):
        return ("force_ask", f"Confirm access to sensitive environment file: {path_str}")
    if tool_name in WRITE_FILE_TOOLS:
        if norm.endswith("/.gemini/config/mcp_config.json"):
            return ("force_ask", "Confirm modifying global mcp_config.json.")
        if norm.endswith(_HOOK_SELF_SUFFIXES):
            return ("force_ask", f"Confirm modifying safety/validation hook file: {path_str}")
    return ("allow", "")


def evaluate_hook_payload(payload: dict[str, Any]) -> dict[str, str]:
    """Classify an Antigravity PreToolUse hook payload into a decision response."""
    tool_call = payload.get("toolCall")
    if not isinstance(tool_call, dict):
        return {"decision": "ask", "reason": "Missing toolCall field; deferring to interactive prompt."}

    tool_name = str(tool_call.get("name", ""))
    args = tool_call.get("args")
    if not isinstance(args, dict):
        args = {}

    if tool_name == "run_command":
        cmd = extract_command_line(args)
        decision, reason = _check_command(cmd)
    elif tool_name in ALL_FILE_TOOLS:
        target = extract_file_path(args)
        decision, reason = _check_file_tool(tool_name, target)
    else:
        decision, reason = ("allow", "")

    resp: dict[str, str] = {"decision": decision}
    if reason:
        resp["reason"] = reason
    return resp


def main() -> int:
    """Read stdin JSON payload and emit decision JSON without crashing on malformed input."""
    payload, exc = read_hook_payload()
    if exc is not None:
        result = {"decision": "ask", "reason": f"Safety guard fallback ({exc}); deferring to prompt."}
    else:
        result = evaluate_hook_payload(payload)
    emit_json(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
