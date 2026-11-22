#!/usr/bin/env python3
"""Zero-token workspace & Obsidian vault hygiene checker."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any
from urllib.parse import unquote

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from session_start_context import (  # noqa: E402
    _DATE_RE,
    _INBOX_UNCHECKED_RE,
    extract_applied_keys,
    line_matches_applied,
)

_FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---(?:\n|$)", re.S)
_REL_LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
_SCHEME_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.-]*:")
_CAREER_STOP_SECTIONS = ("## Uymaz", "## Kapalı", "## Bakılmadı", "## Arşiv", "### Sonraki pencere")
_EXCLUDED_NOTES_PARTS = frozenset({".obsidian", ".trash", ".git", "assets"})


@dataclass
class VaultFinding:
    """Single deterministic hygiene finding."""

    category: str
    severity: str
    path: str
    message: str


def _parse_frontmatter(text: str) -> dict[str, str] | None:
    """Extract top-level key: value pairs from YAML frontmatter if present."""
    match = _FRONTMATTER_RE.match(text)
    if not match:
        return None
    fields: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if ":" in line and not line.startswith((" ", "\t", "-")):
            key, val = line.split(":", 1)
            fields[key.strip()] = val.strip().strip("\"'")
    return fields


def _strip_inline_code(line: str) -> str:
    """Remove inline backtick spans so code examples aren't treated as Markdown links."""
    return re.sub(r"`[^`]*`", "", line)


def _check_career_and_applications(
    root: Path,
    today: dt.date,
) -> list[VaultFinding]:
    """Detect career.md duplicates with APP-* entries and past-due TGT-* deadlines."""
    findings: list[VaultFinding] = []
    apps_path = root / "reports" / "applications.md"
    career_path = root / "reports" / "career.md"
    applied_urls, applied_titles = extract_applied_keys(apps_path)

    if career_path.is_file() and (applied_urls or applied_titles):
        for idx, raw_line in enumerate(career_path.read_text(encoding="utf-8").splitlines(), start=1):
            line = raw_line.strip()
            if any(line.startswith(sec) for sec in _CAREER_STOP_SECTIONS):
                break
            if not line.startswith("- "):
                continue
            if line_matches_applied(line, applied_urls, applied_titles):
                label_m = re.search(r"\[([^\]]+)\]", line)
                label = label_m.group(1) if label_m else line[:60]
                findings.append(
                    VaultFinding(
                        category="career_duplicate",
                        severity="WARN",
                        path=f"reports/career.md:{idx}",
                        message=f"Active career entry already handled in applications.md: {label}",
                    )
                )

    if apps_path.is_file():
        in_table = False
        for idx, raw_line in enumerate(apps_path.read_text(encoding="utf-8").splitlines(), start=1):
            line = raw_line.strip()
            if line.startswith("## "):
                in_table = "Başvuru ve Hedef Tablosu" in line
                continue
            if not in_table or not line.startswith("| **TGT-"):
                continue
            cols = [c.strip() for c in line.strip("|").split("|")]
            if len(cols) < 7 or "🎯 Hedef" not in cols[4]:
                continue
            dates: list[dt.date] = []
            for m in _DATE_RE.finditer(cols[6]):
                try:
                    dates.append(dt.date.fromisoformat(m.group(1)))
                except ValueError:
                    continue
            if dates and max(dates) < today:
                tgt_id = re.sub(r"[*`]", "", cols[0]).strip()
                findings.append(
                    VaultFinding(
                        category="past_due_target",
                        severity="WARN",
                        path=f"reports/applications.md:{idx}",
                        message=f"Target {tgt_id} deadline passed ({max(dates).isoformat()} < {today.isoformat()})",
                    )
                )
    return findings


def _check_notes_vault(root: Path) -> tuple[list[VaultFinding], int]:
    """Inspect notes/ for broken relative links, empty files, frontmatter, and inbox size."""
    findings: list[VaultFinding] = []
    notes_dir = root / "notes"
    if not notes_dir.is_dir():
        return findings, 0

    inbox_count = 0
    inbox_path = notes_dir / "00-inbox.md"
    if inbox_path.is_file():
        for raw_line in inbox_path.read_text(encoding="utf-8").splitlines():
            if _INBOX_UNCHECKED_RE.match(raw_line):
                inbox_count += 1
        if inbox_count >= 10:
            findings.append(
                VaultFinding(
                    category="inbox_backlog",
                    severity="WARN",
                    path="notes/00-inbox.md",
                    message=f"{inbox_count} unchecked items waiting in 00-inbox.md (>=10)",
                )
            )

    for md_path in sorted(notes_dir.rglob("*.md")):
        rel_parts = md_path.relative_to(notes_dir).parts
        if any(part in _EXCLUDED_NOTES_PARTS for part in rel_parts):
            continue

        rel_str = md_path.relative_to(root).as_posix()
        text = md_path.read_text(encoding="utf-8", errors="replace")

        if md_path.name != "00-inbox.md":
            stripped_lines = [
                ln.strip()
                for ln in text.splitlines()
                if ln.strip() and not ln.strip().startswith(("<!--", "---"))
            ]
            if not text.strip() or not stripped_lines:
                findings.append(
                    VaultFinding(
                        category="empty_note",
                        severity="WARN",
                        path=rel_str,
                        message="Empty markdown note file",
                    )
                )

        if len(rel_parts) >= 2 and (
            rel_parts[0] == "10-courses" or rel_parts[:2] == ("20-engineering", "papers")
        ):
            fm = _parse_frontmatter(text)
            missing = [k for k in ("type", "status") if not fm or not fm.get(k)]
            if missing:
                findings.append(
                    VaultFinding(
                        category="missing_frontmatter",
                        severity="WARN",
                        path=rel_str,
                        message=f"Missing required YAML frontmatter field(s): {', '.join(missing)}",
                    )
                )

        in_fence = False
        for line_no, raw_line in enumerate(text.splitlines(), start=1):
            stripped = raw_line.lstrip()
            if stripped.startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            for raw_target in _REL_LINK_RE.findall(_strip_inline_code(raw_line)):
                target = raw_target.strip("<>")
                if not target or target.startswith("#") or _SCHEME_RE.match(target):
                    continue
                target_no_frag = unquote(target.split("#", 1)[0].split("?", 1)[0])
                if not target_no_frag:
                    continue
                resolved = (md_path.parent / target_no_frag).resolve()
                if not resolved.exists():
                    findings.append(
                        VaultFinding(
                            category="broken_link",
                            severity="ERROR",
                            path=f"{rel_str}:{line_no}",
                            message=f"Broken relative link target: {target}",
                        )
                    )
    return findings, inbox_count


def _check_context_budgets(root: Path) -> list[VaultFinding]:
    """Ensure always-on AGENTS.md and on-demand context/ files stay within line limits."""
    findings: list[VaultFinding] = []
    budgets = (
        (root / ".agents" / "rules" / "AGENTS.md", 60),
        (root / "context" / "prefs-and-decisions.md", 55),
    )
    for path, max_lines in budgets:
        if not path.is_file():
            continue
        line_count = len(path.read_text(encoding="utf-8").splitlines())
        if line_count > max_lines:
            findings.append(
                VaultFinding(
                    category="budget_overflow",
                    severity="WARN",
                    path=path.relative_to(root).as_posix(),
                    message=f"File exceeds {max_lines}-line budget ({line_count} lines)",
                )
            )
    return findings


def run_vault_doctor(root: Path, today: dt.date | None = None) -> dict[str, Any]:
    """Run all deterministic vault and workspace hygiene checks."""
    ref_day = today or dt.date.today()
    findings: list[VaultFinding] = []
    findings.extend(_check_career_and_applications(root, ref_day))
    note_findings, inbox_count = _check_notes_vault(root)
    findings.extend(note_findings)
    findings.extend(_check_context_budgets(root))

    status = "CLEAN" if not findings else "WARN"
    if any(f.severity == "ERROR" for f in findings):
        status = "ERROR"

    return {
        "root": str(root),
        "today": ref_day.isoformat(),
        "status": status,
        "finding_count": len(findings),
        "inbox_count": inbox_count,
        "findings": [asdict(f) for f in findings],
    }


def main(argv: list[str] | None = None) -> int:
    """CLI entrypoint for vault_doctor."""
    parser = argparse.ArgumentParser(description="Zero-token workspace & Obsidian vault hygiene checker")
    parser.add_argument("--root", default="/workspace", help="Workspace root directory")
    parser.add_argument("--json", action="store_true", help="Emit JSON report")
    parser.add_argument("--strict", action="store_true", help="Exit 1 if any finding is reported")
    args = parser.parse_args(argv)

    report = run_vault_doctor(Path(args.root).resolve())
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(
            f"Vault Doctor: {report['status']} | findings={report['finding_count']} | inbox={report['inbox_count']}"
        )
        for item in report["findings"]:
            print(f"- [{item['severity']}] ({item['category']}) {item['path']}: {item['message']}")

    if args.strict and report["finding_count"] > 0:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
