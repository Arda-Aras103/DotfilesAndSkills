#!/usr/bin/env python3
"""Workspace diagnostics CLI for agent security, token audits, log squeezing, and code graphs."""

from __future__ import annotations

import argparse
import ast
import json
import re
import sys
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

# --- Shared Constants & Patterns ---

_SKILL_NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---(?:\n|$)", re.S)

_ZERO_WIDTH_RE = re.compile(r"[\u200b-\u200f\u202a-\u202e\u2060\ufeff]")
_INJECTION_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("ignore_previous_instructions", re.compile(r"\bignore\s+(?:all\s+|any\s+)?previous\s+instructions\b", re.I)),
    ("override_system", re.compile(r"\boverride\s+(?:the\s+)?system(?:\s+(?:prompt|rules|instructions))?\b", re.I)),
    ("exfiltrate", re.compile(r"\bexfiltrate\b", re.I)),
    ("disregard_instructions", re.compile(r"\bdisregard\s+(?:all\s+|prior\s+|above\s+)?instructions\b", re.I)),
)
_UNSAFE_SHELL_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    (
        "pipe_to_shell",
        re.compile(r"\b(?:curl|wget)\b[^|;\n]*\|\s*(?:sudo\s+|env\s+)?(?:(?:ba|z|da|k)?sh|python3?|perl|ruby)\b", re.I),
    ),
    ("chmod_777", re.compile(r"\bchmod\s+(?:-[rRf]+\s+)?(?:0?777|a\+rwx)\b", re.I)),
)
_NEGATION_PREFIX_RE = re.compile(
    r"\b(?:never|do\s+not|don't|avoid|forbid(?:den)?|prohibit(?:ed)?|disallow)\s+"
    r"(?:recommend|use|run|execute|allow|set|pipe|grant)(?:ing)?\s+$",
    re.I,
)
_SECRET_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("google_api_key", re.compile(r"\bAIza[0-9A-Za-z_-]{8,}")),
    ("secret_key_prefix", re.compile(r"\bsk-(?:ant-|proj-|or-|live-|test-)?[0-9A-Za-z_-]{8,}")),
    ("github_token", re.compile(r"\bgh[pousr]_[0-9A-Za-z]{8,}")),
    ("aws_access_key", re.compile(r"\bAKIA[0-9A-Z]{8,}")),
    ("private_key_pem", re.compile(r"(?:-----)?BEGIN\s+(?:[A-Z0-9]+\s+)*PRIVATE KEY(?:-----)?")),
)

_ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b[@-_]")
_CRITICAL_LOG_RE = re.compile(r"(?:error|warn|fail|exception|traceback|fatal)", re.I)
_PROGRESS_RE = re.compile(
    r"(?:\[[=>#\-\s]{4,}\]|\b\d{1,3}%|\b\d+/\d+\s+(?:downloading|compiling|fetching|building)\b|[█▓▒░]{3,})",
    re.I,
)
_TRACE_HEADER_RE = re.compile(r"^(?:Traceback \(most recent call last\):|stack backtrace:|goroutine \d+ \[)", re.I)
_TRACE_FRAME_RE = re.compile(
    r"^(?:\s+File \".*\", line \d+|\s+at\s+\S+|\s+\d+:\s+0x[0-9a-f]+|\s+\S+\(.*?\)\s*$|\s+[^\s:]+\.go:\d+)",
    re.I,
)

_EXCLUDED_DIRS = frozenset({".git", "target", "node_modules", "__pycache__", ".venv", "venv", ".mypy_cache", ".pytest_cache"})
_SUPPORTED_EXTS = {
    ".py": "python",
    ".rs": "rust",
    ".go": "go",
    ".js": "javascript",
    ".mjs": "javascript",
    ".ts": "typescript",
}
_READ_TOOLS = frozenset({"read_file", "view_file"})
_WRITE_TOOLS = frozenset({"write_file", "edit_file", "write_to_file", "replace_file_content", "multi_replace_file_content"})


@dataclass
class Finding:
    """Single security or token audit finding."""

    component: str
    severity: str
    rule: str
    line: int
    message: str


# --- Security Audit (`audit-security`) ---


def _mask_secret(raw: str) -> str:
    """Redact detected credentials before logging or serializing."""
    if "PRIVATE KEY" in raw.upper():
        return "***PRIVATE_KEY_REDACTED***"
    prefix = raw[:4] if len(raw) >= 4 else raw[:2]
    return f"{prefix}***"


def _validate_skill_yaml(text: str) -> list[str]:
    """Validate SKILL.md frontmatter against workspace posttool_validator constraints."""
    m = _FRONTMATTER_RE.match(text)
    if not m:
        return ["Missing YAML frontmatter block (`--- ... ---`)."]

    errors: list[str] = []
    lines = m.group(1).splitlines()
    name_lines = [line for line in lines if line.startswith("name:")]
    if not name_lines:
        errors.append("Missing required `name:` field in frontmatter.")
    else:
        name_val = name_lines[0].split(":", 1)[1].strip()
        if not _SKILL_NAME_RE.match(name_val):
            errors.append(f"Invalid skill `name` ({name_val!r}); must be lowercase-hyphen.")

    desc_idx = next((i for i, line in enumerate(lines) if line.startswith("description:")), None)
    if desc_idx is None:
        errors.append("Missing required `description:` field in frontmatter.")
    else:
        desc_val = lines[desc_idx].split(":", 1)[1].strip()
        if not desc_val or desc_val in {">", ">-", "|", "|-"}:
            errors.append("`description:` must be a single non-empty line (no block scalars).")
        if desc_idx + 1 < len(lines) and lines[desc_idx + 1].startswith(" "):
            errors.append("`description:` must not span multiple lines.")
        if '"' in desc_val or "'" in desc_val:
            errors.append("`description:` must not contain quotes.")
        if ": " in desc_val:
            errors.append("`description:` must not contain `: `.")
        if "<" in desc_val or ">" in desc_val:
            errors.append("`description:` must not contain `<` or `>`.")
    return errors


def _is_negated_prose(line: str, match_start: int, in_code_fence: bool) -> bool:
    """Return True when a prose constraint explicitly forbids an unsafe command."""
    if in_code_fence:
        return False
    prefix = re.sub(r"[`*_]", "", line[:match_start])
    return bool(_NEGATION_PREFIX_RE.search(prefix[-45:]))


def _scan_text_security(
    component: str,
    text: str,
    *,
    is_markdown: bool = False,
) -> list[Finding]:
    """Scan file text line by line for injections, zero-width chars, unsafe commands, and secrets."""
    findings: list[Finding] = []
    in_code_fence = False
    for idx, line in enumerate(text.splitlines(), start=1):
        stripped = line.lstrip()
        if is_markdown and stripped.startswith("```"):
            in_code_fence = not in_code_fence

        zw = _ZERO_WIDTH_RE.search(line)
        if zw:
            cps = ", ".join(f"U+{ord(ch):04X}" for ch in sorted(set(_ZERO_WIDTH_RE.findall(line))))
            findings.append(Finding(component, "CRITICAL", "zero_width_unicode", idx, f"Hidden unicode characters ({cps})."))

        for rule_name, pattern in _INJECTION_PATTERNS:
            if pattern.search(line):
                findings.append(Finding(component, "CRITICAL", f"prompt_injection:{rule_name}", idx, f"Potential prompt injection phrase ({rule_name})."))

        for rule_name, pattern in _UNSAFE_SHELL_PATTERNS:
            m = pattern.search(line)
            if m and not (is_markdown and _is_negated_prose(line, m.start(), in_code_fence)):
                findings.append(Finding(component, "CRITICAL", f"unsafe_shell:{rule_name}", idx, f"Unsafe shell pattern ({rule_name})."))

        for rule_name, pattern in _SECRET_PATTERNS:
            for m in pattern.finditer(line):
                masked = _mask_secret(m.group(0))
                findings.append(Finding(component, "CRITICAL", f"unmasked_secret:{rule_name}", idx, f"Detected unmasked credential ({masked})."))
    return findings


def _score_findings(findings: list[Finding]) -> tuple[int, str]:
    """Compute a 0-100 security score and PASS/WARN/FAIL status from component findings."""
    penalty = 0
    has_critical = False
    for item in findings:
        if item.severity == "CRITICAL":
            penalty += 40
            has_critical = True
        else:
            penalty += 20
    score = max(0, 100 - penalty)
    if has_critical or score < 70:
        return score, "FAIL"
    if score < 100:
        return score, "WARN"
    return score, "PASS"


def _audit_json_artifact(component: str, path: Path) -> list[Finding]:
    """Validate JSON syntax and scan serialized contents for security issues."""
    text = path.read_text(encoding="utf-8", errors="replace")
    findings = _scan_text_security(component, text, is_markdown=False)
    try:
        json.loads(text)
    except json.JSONDecodeError as exc:
        findings.append(Finding(component, "CRITICAL", "invalid_json", exc.lineno, f"Invalid JSON: {exc.msg}."))
    return findings


def run_audit_security(root: Path, mcp_config: Path | None = None) -> dict[str, Any]:
    """Audit skills, hooks.json, and mcp_config.json under root and return structured report."""
    components: list[dict[str, Any]] = []
    all_findings: list[Finding] = []

    skills_dir = root / ".agents" / "skills"
    skill_files = sorted(skills_dir.glob("*/SKILL.md")) if skills_dir.is_dir() else []
    for skill_path in skill_files:
        comp = f"skill:{skill_path.parent.name}"
        text = skill_path.read_text(encoding="utf-8", errors="replace")
        findings = _scan_text_security(comp, text, is_markdown=True)
        for err in _validate_skill_yaml(text):
            findings.append(Finding(comp, "WARN", "yaml_constraint", 1, err))
        score, status = _score_findings(findings)
        components.append({"component": comp, "path": str(skill_path), "score": score, "status": status, "findings": [asdict(f) for f in findings]})
        all_findings.extend(findings)

    hooks_path = root / ".agents" / "hooks.json"
    if hooks_path.is_file():
        findings = _audit_json_artifact("hooks.json", hooks_path)
        score, status = _score_findings(findings)
        components.append({"component": "hooks.json", "path": str(hooks_path), "score": score, "status": status, "findings": [asdict(f) for f in findings]})
        all_findings.extend(findings)

    explicit_mcp = mcp_config is not None
    resolved_mcp = mcp_config if mcp_config is not None else (Path.home() / ".gemini" / "config" / "mcp_config.json")
    if resolved_mcp.is_file():
        findings = _audit_json_artifact("mcp_config.json", resolved_mcp)
        score, status = _score_findings(findings)
        components.append({"component": "mcp_config.json", "path": str(resolved_mcp), "score": score, "status": status, "findings": [asdict(f) for f in findings]})
        all_findings.extend(findings)
    elif explicit_mcp:
        missing = Finding("mcp_config.json", "CRITICAL", "missing_mcp_config", 0, f"Specified MCP config not found: {resolved_mcp}")
        components.append({"component": "mcp_config.json", "path": str(resolved_mcp), "score": 0, "status": "FAIL", "findings": [asdict(missing)]})
        all_findings.append(missing)

    overall_score = round(sum(c["score"] for c in components) / len(components)) if components else 100
    if any(c["status"] == "FAIL" for c in components):
        overall_status = "FAIL"
        overall_score = min(overall_score, min(c["score"] for c in components))
    elif any(c["status"] == "WARN" for c in components):
        overall_status = "WARN"
    else:
        overall_status = "PASS"

    return {
        "root": str(root),
        "overall_score": overall_score,
        "status": overall_status,
        "components_scanned": len(components),
        "finding_count": len(all_findings),
        "components": components,
    }


# --- Token & Transcript Audit (`audit-tokens`) ---


def _estimate_tokens(text: str) -> int:
    """Approximate token cost at ~4 chars per token."""
    return (len(text) + 3) // 4 if text else 0


def _extract_skill_triggers(text: str) -> list[str]:
    """Parse trigger phrases listed after 'Triggers include' in SKILL.md description."""
    m = _FRONTMATTER_RE.match(text)
    if not m:
        return []
    for line in m.group(1).splitlines():
        if line.startswith("description:"):
            desc = line.split(":", 1)[1].strip()
            tm = re.search(r"triggers include\s+(.+)$", desc, re.I)
            if not tm:
                return []
            raw_list = tm.group(1).split(".")[0]
            return [item.strip().lower() for item in raw_list.split(",") if item.strip()]
    return []


def _unwrap_arg(val: Any) -> Any:
    """Decode JSON-quoted string values emitted in compact transcript logs."""
    if isinstance(val, str) and len(val) >= 2 and val[0] == '"' and val[-1] == '"':
        try:
            return json.loads(val)
        except json.JSONDecodeError:
            return val.strip('"')
    return val


def _extract_tool_path(args: dict[str, Any]) -> str:
    """Extract normalized path field across file tool schemas."""
    for key in ("Path", "TargetFile", "AbsolutePath", "path"):
        if key in args:
            val = _unwrap_arg(args[key])
            if isinstance(val, str) and val.strip():
                return val.strip()
    return ""


def _analyze_transcript_file(transcript_path: Path) -> dict[str, Any]:
    """Inspect a transcript JSONL file for duplicate reads, failed retries, and >10KB outputs."""
    seen_reads: dict[tuple[str, str, str, str], int] = {}
    duplicate_reads: list[dict[str, Any]] = []
    pending_calls: list[tuple[str, str]] = []
    failed_cmd_counts: Counter[str] = Counter()
    large_outputs: list[dict[str, Any]] = []

    for line_no, raw in enumerate(transcript_path.read_text(encoding="utf-8", errors="replace").splitlines(), start=1):
        stripped = raw.strip()
        if not stripped:
            continue
        try:
            step = json.loads(stripped)
        except json.JSONDecodeError:
            continue
        if not isinstance(step, dict):
            continue

        tool_calls = step.get("tool_calls")
        if not isinstance(tool_calls, list) and isinstance(step.get("tool"), str):
            tool_calls = [{"name": step["tool"], "args": step.get("args") or {}}]

        if isinstance(tool_calls, list):
            for call in tool_calls:
                if not isinstance(call, dict):
                    continue
                name = str(call.get("name", ""))
                args = call.get("args") if isinstance(call.get("args"), dict) else {}
                arg_summary = ""
                if name in _READ_TOOLS:
                    fpath = _extract_tool_path(args)
                    arg_summary = fpath
                    if fpath:
                        key = (
                            fpath,
                            str(_unwrap_arg(args.get("StartLine", ""))),
                            str(_unwrap_arg(args.get("EndLine", ""))),
                            str(_unwrap_arg(args.get("ByteOffset", ""))),
                        )
                        if key in seen_reads:
                            duplicate_reads.append({"step": step.get("step_index", line_no), "path": fpath, "start": key[1], "end": key[2]})
                        seen_reads[key] = seen_reads.get(key, 0) + 1
                elif name in _WRITE_TOOLS:
                    fpath = _extract_tool_path(args)
                    arg_summary = fpath
                    for k in [k for k in seen_reads if k[0] == fpath]:
                        seen_reads.pop(k, None)
                elif name == "run_command":
                    arg_summary = str(_unwrap_arg(args.get("CommandLine") or args.get("command") or "")).strip()
                    if step.get("status") == "ERROR" and arg_summary:
                        failed_cmd_counts[arg_summary] += 1
                        arg_summary = ""
                pending_calls.append((name, arg_summary))

        content = step.get("content")
        stype = str(step.get("type", ""))
        source = str(step.get("source", ""))
        is_tool_output = stype in {"GENERIC", "TOOL_RESULT"} or (source not in {"USER_EXPLICIT", "SYSTEM_SDK", "SYSTEM"} and stype != "PLANNER_RESPONSE")
        if isinstance(content, str) and is_tool_output:
            byte_len = len(content.encode("utf-8"))
            if "content" in (step.get("truncated_fields") or []):
                tm = re.search(r"<truncated (\d+) bytes>", content)
                if tm:
                    byte_len += int(tm.group(1))
            if byte_len > 10240:
                large_outputs.append({"step": step.get("step_index", line_no), "bytes": byte_len, "estimated_tokens": byte_len // 4})

            if pending_calls:
                call_name, call_arg = pending_calls.pop(0)
                is_err = (
                    step.get("status") == "ERROR"
                    or "Command failed to run" in content
                    or bool(re.search(r"Exit code:\s*[1-9]\d*|Traceback \(most recent call last\)|^Error:", content, re.M))
                )
                if call_name == "run_command" and call_arg and is_err:
                    failed_cmd_counts[call_arg] += 1

    repeated_failures = [{"command": cmd, "failures": cnt} for cmd, cnt in failed_cmd_counts.items() if cnt >= 2]
    ghost_tokens = (
        len(duplicate_reads) * 300
        + sum((item["failures"] - 1) * 200 for item in repeated_failures)
        + sum(item["estimated_tokens"] for item in large_outputs)
    )
    return {
        "transcript": str(transcript_path),
        "duplicate_reads": duplicate_reads,
        "repeated_failed_commands": repeated_failures,
        "large_outputs_gt_10kb": large_outputs,
        "estimated_ghost_tokens": ghost_tokens,
    }


def _discover_recent_transcripts(brain_dir: Path, limit: int = 5) -> list[Path]:
    """Locate most recently modified transcript logs under the Antigravity brain directory."""
    if not brain_dir.is_dir():
        return []
    candidates: list[Path] = []
    for conv_dir in brain_dir.iterdir():
        log_dir = conv_dir / ".system_generated" / "logs"
        full = log_dir / "transcript_full.jsonl"
        compact = log_dir / "transcript.jsonl"
        if full.is_file():
            candidates.append(full)
        elif compact.is_file():
            candidates.append(compact)
    candidates.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return candidates[:limit]


def run_audit_tokens(
    root: Path,
    transcript: Path | None = None,
    scan_recent_transcripts: bool = False,
    brain_dir: Path | None = None,
) -> dict[str, Any]:
    """Compute token cost for skills/rules, flag bloat/duplicate triggers, and detect ghost tokens."""
    entries: list[dict[str, Any]] = []
    oversized: list[dict[str, Any]] = []
    trigger_owners: dict[str, list[str]] = defaultdict(list)

    skills_dir = root / ".agents" / "skills"
    for path in sorted(skills_dir.glob("*/SKILL.md")) if skills_dir.is_dir() else []:
        text = path.read_text(encoding="utf-8", errors="replace")
        chars = len(text)
        lines = len(text.splitlines())
        est = _estimate_tokens(text)
        skill_name = path.parent.name
        rec = {
            "kind": "skill",
            "name": skill_name,
            "path": str(path),
            "bytes": len(text.encode("utf-8")),
            "chars": chars,
            "lines": lines,
            "estimated_tokens": est,
        }
        entries.append(rec)
        if lines > 100 or chars > 2500:
            reasons = []
            if lines > 100:
                reasons.append(f"{lines} lines (>100)")
            if chars > 2500:
                reasons.append(f"{chars} chars (>2500)")
            oversized.append({"name": skill_name, "path": str(path), "reasons": reasons})
        for trig in _extract_skill_triggers(text):
            if skill_name not in trigger_owners[trig]:
                trigger_owners[trig].append(skill_name)

    rules_dir = root / ".agents" / "rules"
    for path in sorted(rules_dir.glob("*.md")) if rules_dir.is_dir() else []:
        text = path.read_text(encoding="utf-8", errors="replace")
        entries.append(
            {
                "kind": "rule",
                "name": path.name,
                "path": str(path),
                "bytes": len(text.encode("utf-8")),
                "chars": len(text),
                "lines": len(text.splitlines()),
                "estimated_tokens": _estimate_tokens(text),
            }
        )

    duplicate_triggers = {trig: owners for trig, owners in sorted(trigger_owners.items()) if len(owners) > 1}
    transcript_reports: list[dict[str, Any]] = []
    if transcript is not None:
        if not transcript.is_file():
            raise FileNotFoundError(f"Transcript not found: {transcript}")
        transcript_reports.append(_analyze_transcript_file(transcript))
    elif scan_recent_transcripts:
        target_brain = brain_dir or (Path.home() / ".gemini" / "antigravity-cli" / "brain")
        for tpath in _discover_recent_transcripts(target_brain):
            transcript_reports.append(_analyze_transcript_file(tpath))

    return {
        "root": str(root),
        "total_bytes": sum(e["bytes"] for e in entries),
        "total_lines": sum(e["lines"] for e in entries),
        "total_estimated_tokens": sum(e["estimated_tokens"] for e in entries),
        "files": entries,
        "oversized_skills": oversized,
        "duplicate_triggers": duplicate_triggers,
        "transcript_audits": transcript_reports,
    }


# --- Log Squeezing (`squeeze`) ---


def _normalize_log_line(line: str) -> str:
    """Normalize volatile timestamps, hex pointers, and numbers for near-duplicate matching."""
    norm = re.sub(r"\b\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:\.\d+)?Z?\b", "<TS>", line)
    norm = re.sub(r"\b\d{2}:\d{2}:\d{2}(?:[.,]\d+)?\b", "<TIME>", norm)
    norm = re.sub(r"\b0x[0-9a-fA-F]+\b", "<HEX>", norm)
    norm = re.sub(r"\b\d+(?:\.\d+)?\b", "<N>", norm)
    return re.sub(r"\s+", " ", norm).strip()


def _collapse_traces_and_progress(lines: list[str]) -> list[str]:
    """Condense progress bar spam and deep stack traces before line-budget truncation."""
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if _PROGRESS_RE.search(line) and not _CRITICAL_LOG_RE.search(line):
            j = i + 1
            while j < len(lines) and _PROGRESS_RE.search(lines[j]) and not _CRITICAL_LOG_RE.search(lines[j]):
                j += 1
            if j - i >= 2:
                out.append(f"{lines[j - 1]} [x{j - i} progress updates collapsed]")
            else:
                out.append(line)
            i = j
            continue

        if _TRACE_HEADER_RE.match(line) or (_TRACE_FRAME_RE.match(line) and i > 0):
            frames: list[str] = []
            if _TRACE_HEADER_RE.match(line):
                out.append(line)
                i += 1
            while i < len(lines) and (_TRACE_FRAME_RE.match(lines[i]) or (lines[i].startswith("    ") and frames)):
                frames.append(lines[i])
                i += 1
            if len(frames) > 6:
                out.extend(frames[:2])
                out.append(f"  ... [{len(frames) - 4} stack frames omitted] ...")
                out.extend(frames[-2:])
            else:
                out.extend(frames)
            continue

        out.append(line)
        i += 1
    return out


def _collapse_duplicates(lines: list[str]) -> list[str]:
    """Collapse consecutive duplicate or near-duplicate lines while keeping critical error specifics."""
    collapsed: list[str] = []
    idx = 0
    while idx < len(lines):
        cur = lines[idx]
        is_crit = bool(_CRITICAL_LOG_RE.search(cur))
        sig = re.sub(r"\s+", " ", cur).strip() if is_crit else _normalize_log_line(cur)
        run = 1
        while idx + run < len(lines):
            nxt = lines[idx + run]
            nxt_crit = bool(_CRITICAL_LOG_RE.search(nxt))
            if nxt_crit != is_crit:
                break
            nxt_sig = re.sub(r"\s+", " ", nxt).strip() if is_crit else _normalize_log_line(nxt)
            if nxt_sig != sig:
                break
            run += 1
        collapsed.append(f"{cur} [x{run} repeated]" if run > 1 else cur)
        idx += run
    return collapsed


def _count_gaps(sorted_indices: list[int]) -> int:
    """Count contiguous non-kept gaps between sorted indices."""
    return sum(1 for a, b in zip(sorted_indices, sorted_indices[1:]) if b > a + 1)


def _budget_lines_with_criticals(lines: list[str], max_lines: int) -> list[str]:
    """Keep head + tail + all critical lines strictly within max_lines."""
    if max_lines <= 0:
        return []
    if len(lines) <= max_lines:
        return lines

    crit_indices = [i for i, line in enumerate(lines) if _CRITICAL_LOG_RE.search(line)]
    if len(crit_indices) >= max_lines:
        head_c = max(1, max_lines // 2)
        tail_c = max_lines - head_c
        selected = crit_indices[:head_c] + (crit_indices[-tail_c:] if tail_c else [])
        return [lines[i] for i in sorted(set(selected))][:max_lines]

    kept: set[int] = set(crit_indices)
    left, right = 0, len(lines) - 1
    take_head = True
    while left <= right:
        candidate = left if take_head else right
        if take_head:
            left += 1
        else:
            right -= 1
        take_head = not take_head
        if candidate in kept:
            continue
        trial = sorted(kept | {candidate})
        if len(trial) + _count_gaps(trial) <= max_lines:
            kept.add(candidate)
        elif len(kept) + _count_gaps(sorted(kept)) >= max_lines:
            break

    sorted_idx = sorted(kept)
    include_markers = len(sorted_idx) + _count_gaps(sorted_idx) <= max_lines
    result: list[str] = []
    prev = -1
    for idx in sorted_idx:
        if include_markers and prev != -1 and idx > prev + 1:
            result.append(f"... [{idx - prev - 1} lines omitted] ...")
        result.append(lines[idx])
        prev = idx
    return result[:max_lines]


def squeeze_text(raw_text: str, max_lines: int = 80) -> tuple[str, dict[str, Any]]:
    """Strip ANSI, condense repeats/traces/progress, preserve critical lines, and return stats."""
    cleaned_lines: list[str] = []
    for raw_line in raw_text.splitlines():
        no_ansi = _ANSI_RE.sub("", raw_line)
        final_segment = no_ansi.split("\r")[-1].rstrip()
        cleaned_lines.append(final_segment)

    orig_lines = len(cleaned_lines)
    orig_bytes = len(raw_text.encode("utf-8"))

    condensed = _collapse_traces_and_progress(cleaned_lines)
    deduped = _collapse_duplicates(condensed)
    final_lines = _budget_lines_with_criticals(deduped, max_lines)

    output = "\n".join(final_lines) + ("\n" if final_lines else "")
    out_bytes = len(output.encode("utf-8"))
    saved_pct = ((orig_lines - len(final_lines)) / orig_lines * 100.0) if orig_lines else 0.0
    stats = {
        "original_lines": orig_lines,
        "compressed_lines": len(final_lines),
        "original_bytes": orig_bytes,
        "compressed_bytes": out_bytes,
        "saved_percent": round(saved_pct, 1),
    }
    return output, stats


# --- Code Graph (`code-graph`) ---


def _analyze_python_file(path: Path, rel_path: str) -> dict[str, Any]:
    """Use stdlib ast to extract Python imports, symbols, and __main__ entry point."""
    text = path.read_text(encoding="utf-8", errors="replace")
    imports: list[str] = []
    symbols: list[str] = []
    is_entry = False
    try:
        tree = ast.parse(text, filename=str(path))
    except SyntaxError:
        return {"path": rel_path, "lang": "python", "imports": [], "symbols": [], "entry": False}

    for node in tree.body:
        if isinstance(node, ast.Import):
            for alias in node.names:
                imports.append(alias.name)
        elif isinstance(node, ast.ImportFrom):
            prefix = "." * node.level
            if node.module:
                imports.append(f"{prefix}{node.module}")
            elif prefix:
                for alias in node.names:
                    imports.append(f"{prefix}{alias.name}")
        elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            symbols.append(node.name)
        elif isinstance(node, ast.If) and isinstance(node.test, ast.Compare):
            left = node.test.left
            comps = node.test.comparators
            if (
                isinstance(left, ast.Name)
                and left.id == "__name__"
                and len(comps) == 1
                and isinstance(comps[0], ast.Constant)
                and comps[0].value == "__main__"
            ):
                is_entry = True
    return {"path": rel_path, "lang": "python", "imports": [i for i in imports if i], "symbols": symbols, "entry": is_entry}


def _analyze_regex_file(path: Path, rel_path: str, lang: str) -> dict[str, Any]:
    """Extract imports, entry points, and top symbols for Rust, Go, and JS/TS via regex."""
    text = path.read_text(encoding="utf-8", errors="replace")
    imports: list[str] = []
    symbols: list[str] = []
    is_entry = False

    if lang == "rust":
        is_entry = bool(re.search(r"\b(?:async\s+)?fn\s+main\s*\(", text))
        imports.extend(re.findall(r"^\s*mod\s+([a-zA-Z_]\w*)\s*;", text, re.M))
        for use_path in re.findall(r"^\s*(?:pub\s+)?use\s+([^;{]+)", text, re.M):
            imports.append(use_path.strip())
        symbols.extend(re.findall(r"^\s*(?:pub(?:\([^)]*\))?\s+)?(?:async\s+)?fn\s+([a-zA-Z_]\w*)", text, re.M))
        symbols.extend(re.findall(r"^\s*(?:pub(?:\([^)]*\))?\s+)?(?:struct|enum|trait)\s+([a-zA-Z_]\w*)", text, re.M))
    elif lang == "go":
        is_entry = bool(re.search(r"^\s*func\s+main\s*\(\s*\)", text, re.M))
        imports.extend(re.findall(r'^\s*import\s+(?:\w+\s+)?"([^"]+)"', text, re.M))
        for block in re.findall(r"import\s*\((.*?)\)", text, re.S):
            imports.extend(re.findall(r'"([^"]+)"', block))
        symbols.extend(re.findall(r"^\s*func\s+(?:\([^)]+\)\s*)?([a-zA-Z_]\w*)\s*\(", text, re.M))
        symbols.extend(re.findall(r"^\s*type\s+([a-zA-Z_]\w*)\s+(?:struct|interface)\b", text, re.M))
    else:  # javascript / typescript
        is_entry = Path(rel_path).stem in {"index", "main"} or bool(re.search(r"\b(?:app\.listen|createServer)\s*\(", text))
        imports.extend(re.findall(r"""(?:import|export)\s+(?:[^'"]+\s+from\s+)?['"]([^'"]+)['"]""", text))
        imports.extend(re.findall(r"""\brequire\(\s*['"]([^'"]+)['"]\s*\)""", text))
        symbols.extend(re.findall(r"^\s*(?:export\s+(?:default\s+)?)?(?:async\s+)?function\s+([a-zA-Z_$][\w$]*)", text, re.M))
        symbols.extend(re.findall(r"^\s*(?:export\s+)?class\s+([a-zA-Z_$][\w$]*)", text, re.M))
        symbols.extend(re.findall(r"^\s*export\s+(?:const|let)\s+([a-zA-Z_$][\w$]*)\s*=", text, re.M))

    dedup_symbols = list(dict.fromkeys(symbols))
    return {"path": rel_path, "lang": lang, "imports": imports, "symbols": dedup_symbols, "entry": is_entry}


def _resolve_internal_edge(source_rel: str, imp: str, lang: str, file_index: dict[str, str], stem_index: dict[str, list[str]]) -> str | None:
    """Resolve an import specifier to a known relative file path inside target_dir."""
    src_dir = Path(source_rel).parent

    if lang == "python":
        dots = len(imp) - len(imp.lstrip("."))
        clean = imp.lstrip(".")
        base_dir = src_dir
        for _ in range(max(0, dots - 1)):
            base_dir = base_dir.parent
        rel_mod = clean.replace(".", "/")
        candidates = [f"{(base_dir / rel_mod).as_posix()}.py", f"{(base_dir / rel_mod / '__init__').as_posix()}.py"] if dots else []
        if rel_mod:
            candidates.extend([f"{rel_mod}.py", f"{rel_mod}/__init__.py"])
        for cand in candidates:
            norm = cand.lstrip("./")
            if norm in file_index:
                return file_index[norm]
        last_part = clean.split(".")[-1] if clean else ""
        if last_part in stem_index and len(stem_index[last_part]) == 1:
            return stem_index[last_part][0]
        return None

    if lang == "rust":
        parts = [p for p in imp.replace("crate::", "").replace("super::", "").split("::") if p and p != "self"]
        if parts:
            cand_rs = f"{parts[0]}.rs"
            if (src_dir / cand_rs).as_posix().lstrip("./") in file_index:
                return file_index[(src_dir / cand_rs).as_posix().lstrip("./")]
            if parts[0] in stem_index and len(stem_index[parts[0]]) == 1:
                return stem_index[parts[0]][0]
        return None

    if lang == "go":
        leaf = imp.rstrip("/").split("/")[-1]
        go_matches = sorted(
            (rel for rel in file_index.values() if rel.endswith(".go") and Path(rel).parent.name == leaf),
            key=lambda r: (r.endswith("_test.go"), r),
        )
        if go_matches:
            return go_matches[0]
        if leaf in stem_index and len(stem_index[leaf]) == 1:
            return stem_index[leaf][0]
        return None

    # javascript / typescript
    if imp.startswith("."):
        joined = (src_dir / imp).as_posix()
        norm_parts: list[str] = []
        for part in joined.split("/"):
            if part in {"", "."}:
                continue
            if part == ".." and norm_parts:
                norm_parts.pop()
            else:
                norm_parts.append(part)
        base = "/".join(norm_parts)
        bases = [base]
        if base.endswith((".js", ".mjs")):
            bases.append(base.rsplit(".", 1)[0])
        for b in bases:
            for ext in ("", ".ts", ".js", ".mjs", "/index.ts", "/index.js"):
                if f"{b}{ext}" in file_index:
                    return file_index[f"{b}{ext}"]
    return None


def build_code_graph(target_dir: Path, max_nodes: int = 40) -> dict[str, Any]:
    """Scan target_dir for supported source files and return nodes, edges, and summary."""
    if not target_dir.is_dir():
        raise NotADirectoryError(f"Target directory does not exist: {target_dir}")

    nodes_raw: list[dict[str, Any]] = []
    for path in sorted(target_dir.rglob("*")):
        if any(part in _EXCLUDED_DIRS for part in path.relative_to(target_dir).parts):
            continue
        if not path.is_file():
            continue
        lang = _SUPPORTED_EXTS.get(path.suffix)
        if not lang:
            continue
        rel = path.relative_to(target_dir).as_posix()
        info = _analyze_python_file(path, rel) if lang == "python" else _analyze_regex_file(path, rel, lang)
        nodes_raw.append(info)

    file_index = {n["path"]: n["path"] for n in nodes_raw}
    stem_index: dict[str, list[str]] = defaultdict(list)
    for n in nodes_raw:
        stem_index[Path(n["path"]).stem].append(n["path"])

    edges_set: set[tuple[str, str]] = set()
    degree: Counter[str] = Counter()
    for node in nodes_raw:
        src = node["path"]
        for imp in node["imports"]:
            dst = _resolve_internal_edge(src, imp, node["lang"], file_index, stem_index)
            if dst and dst != src:
                edges_set.add((src, dst))
                degree[src] += 1
                degree[dst] += 1

    # Prioritize entry points, connected modules, and symbol-rich files within max_nodes.
    ranked = sorted(
        nodes_raw,
        key=lambda n: (not n["entry"], -degree[n["path"]], -len(n["symbols"]), n["path"]),
    )
    kept_nodes = ranked[: max(1, max_nodes)]
    kept_paths = {n["path"] for n in kept_nodes}
    kept_edges = sorted((s, d) for (s, d) in edges_set if s in kept_paths and d in kept_paths)

    return {
        "target_dir": str(target_dir),
        "total_files_scanned": len(nodes_raw),
        "nodes_shown": len(kept_nodes),
        "entry_points": [n["path"] for n in kept_nodes if n["entry"]],
        "nodes": kept_nodes,
        "edges": [{"from": s, "to": d} for s, d in kept_edges],
    }


def render_mermaid_graph(graph: dict[str, Any]) -> str:
    """Render a quoted Mermaid flowchart LR diagram without HTML tags."""
    lines = ["flowchart LR"]
    node_ids: dict[str, str] = {}
    for idx, node in enumerate(graph["nodes"]):
        nid = f"m{idx}"
        node_ids[node["path"]] = nid
        label_parts = [node["path"]]
        if node["entry"]:
            label_parts.append("entry")
        elif node["symbols"]:
            label_parts.append(f"{len(node['symbols'])} sym")
        safe_label = " | ".join(label_parts).replace('"', "'")
        lines.append(f'    {nid}["{safe_label}"]')

    for edge in graph["edges"]:
        s_id = node_ids.get(edge["from"])
        d_id = node_ids.get(edge["to"])
        if s_id and d_id:
            lines.append(f"    {s_id} --> {d_id}")
    return "\n".join(lines)


def render_markdown_graph(graph: dict[str, Any]) -> str:
    """Render compact Markdown summary and quoted Mermaid diagram for code-graph."""
    entries = ", ".join(f"`{ep}`" for ep in graph["entry_points"]) or "None detected"
    lines = [
        f"# Code Graph: {graph['target_dir']}",
        f"- **Files scanned:** {graph['total_files_scanned']} (showing {graph['nodes_shown']})",
        f"- **Internal edges:** {len(graph['edges'])}",
        f"- **Entry points:** {entries}",
        "",
        "## Top Symbols",
    ]
    for node in graph["nodes"]:
        if node["symbols"] or node["entry"]:
            syms = ", ".join(f"`{s}`" for s in node["symbols"][:6]) or "(script)"
            tag = " *(entry)*" if node["entry"] else ""
            lines.append(f"- `{node['path']}`{tag}: {syms}")

    lines.extend(["", "## Dependency Flow", "", "```mermaid", render_mermaid_graph(graph), "```"])
    return "\n".join(lines)


# --- Human-Readable Formatters & CLI Entrypoint ---


def _format_security_text(report: dict[str, Any]) -> str:
    """Render concise security audit table and findings."""
    lines = [
        f"Security Audit: {report['status']} ({report['overall_score']}/100) | components={report['components_scanned']} | findings={report['finding_count']}"
    ]
    for comp in report["components"]:
        lines.append(f"- [{comp['status']}] {comp['component']}: {comp['score']}/100")
        for f in comp["findings"]:
            lines.append(f"  L{f['line']} ({f['severity']} {f['rule']}): {f['message']}")
    return "\n".join(lines)


def _format_tokens_text(report: dict[str, Any]) -> str:
    """Render concise token budget and ghost-token report."""
    lines = [
        f"Token Audit: {report['total_estimated_tokens']} est. tokens ({report['total_bytes']} bytes, {report['total_lines']} lines across {len(report['files'])} files)"
    ]
    for item in sorted(report["files"], key=lambda x: -x["estimated_tokens"]):
        lines.append(f"- {item['kind']}:{item['name']} -> ~{item['estimated_tokens']} tok ({item['lines']}L / {item['chars']}C)")
    if report["oversized_skills"]:
        lines.append("Oversized Skills (>100L or >2500C):")
        for os_item in report["oversized_skills"]:
            lines.append(f"- {os_item['name']}: {', '.join(os_item['reasons'])}")
    if report["duplicate_triggers"]:
        lines.append("Duplicate Triggers:")
        for trig, owners in report["duplicate_triggers"].items():
            lines.append(f"- '{trig}': {', '.join(owners)}")
    for tr in report["transcript_audits"]:
        lines.append(
            f"Transcript Ghost Tokens ({tr['transcript']}): ~{tr['estimated_ghost_tokens']} tok "
            f"(dup_reads={len(tr['duplicate_reads'])}, retry_failures={len(tr['repeated_failed_commands'])}, >10KB={len(tr['large_outputs_gt_10kb'])})"
        )
    return "\n".join(lines)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Agent Doctor CLI (security, tokens, log squeeze, code graph)")
    sub = parser.add_subparsers(dest="subcommand", required=True)

    sec = sub.add_parser("audit-security", help="Audit skills, hooks, and MCP config for security issues")
    sec.add_argument("--root", default="/workspace", help="Workspace root directory")
    sec.add_argument("--mcp-config", default=None, help="Path to mcp_config.json")
    sec.add_argument("--json", action="store_true", dest="as_json", help="Emit JSON report")

    tok = sub.add_parser("audit-tokens", help="Audit always-loaded token budget and transcript ghost tokens")
    tok.add_argument("--root", default="/workspace", help="Workspace root directory")
    tok.add_argument("--transcript", default=None, help="Path to Antigravity transcript JSONL")
    tok.add_argument("--scan-recent-transcripts", action="store_true", help="Scan recent Antigravity brain transcripts")
    tok.add_argument("--json", action="store_true", dest="as_json", help="Emit JSON report")

    sq = sub.add_parser("squeeze", help="Compress noisy CLI/build logs while preserving errors")
    sq.add_argument("--input-file", default=None, help="Read log from file instead of stdin")
    sq.add_argument("--max-lines", type=int, default=80, help="Maximum output line budget")

    cg = sub.add_parser("code-graph", help="Generate AST/regex code graph in Markdown, Mermaid, or JSON")
    cg.add_argument("target_dir", help="Target directory to scan")
    cg.add_argument("--max-nodes", type=int, default=40, help="Maximum file nodes to keep")
    cg.add_argument("--format", choices=("markdown", "mermaid", "json"), default="markdown", dest="fmt")
    return parser


def main(argv: list[str] | None = None) -> int:
    """CLI entrypoint."""
    args = _build_parser().parse_args(argv)

    if args.subcommand == "audit-security":
        mcp_path = Path(args.mcp_config) if args.mcp_config else None
        report = run_audit_security(Path(args.root), mcp_config=mcp_path)
        print(json.dumps(report, ensure_ascii=False, indent=2) if args.as_json else _format_security_text(report))
        return 1 if report["status"] == "FAIL" else 0

    if args.subcommand == "audit-tokens":
        t_path = Path(args.transcript) if args.transcript else None
        try:
            report = run_audit_tokens(Path(args.root), transcript=t_path, scan_recent_transcripts=args.scan_recent_transcripts)
        except FileNotFoundError as exc:
            print(str(exc), file=sys.stderr)
            return 1
        print(json.dumps(report, ensure_ascii=False, indent=2) if args.as_json else _format_tokens_text(report))
        return 0

    if args.subcommand == "squeeze":
        if args.input_file:
            in_path = Path(args.input_file)
            if not in_path.is_file():
                print(f"Input file not found: {in_path}", file=sys.stderr)
                return 1
            raw = in_path.read_text(encoding="utf-8", errors="replace")
        else:
            raw = sys.stdin.read()
        compressed, stats = squeeze_text(raw, max_lines=args.max_lines)
        sys.stdout.write(compressed)
        print(
            f"[squeeze] {stats['original_lines']} -> {stats['compressed_lines']} lines "
            f"({stats['saved_percent']}% saved; {stats['original_bytes']} -> {stats['compressed_bytes']} bytes)",
            file=sys.stderr,
        )
        return 0

    if args.subcommand == "code-graph":
        try:
            graph = build_code_graph(Path(args.target_dir), max_nodes=args.max_nodes)
        except NotADirectoryError as exc:
            print(str(exc), file=sys.stderr)
            return 1
        if args.fmt == "json":
            print(json.dumps(graph, ensure_ascii=False, indent=2))
        elif args.fmt == "mermaid":
            print(render_mermaid_graph(graph))
        else:
            print(render_markdown_graph(graph))
        return 0

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
