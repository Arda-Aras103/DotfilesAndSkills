#!/usr/bin/env python3
"""Read-only workspace scanner for dropped media, inbox captures, and report mirrors."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

MEDIA_EXTS = frozenset({".mkv", ".mp4", ".webm", ".srt", ".vtt"})
CAPTURE_MARKER = "<!-- Yakalama -->"


def _sha256(path: Path) -> str:
    """Compute SHA-256 hex digest of a file."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _scan_screenshots(root: Path) -> list[dict[str, Any]]:
    """List top-level PNG screenshots in the workspace root."""
    items: list[dict[str, Any]] = []
    for png in sorted(root.glob("*.png")):
        if png.is_file():
            items.append({"name": png.name, "size_kb": round(png.stat().st_size / 1024, 1)})
    return items


def _scan_video_dirs(root: Path) -> list[dict[str, Any]]:
    """List immediate subdirectories containing video or subtitle downloads."""
    dirs: list[dict[str, Any]] = []
    for child in sorted(root.iterdir()):
        if not child.is_dir() or child.name.startswith("."):
            continue
        files = [f for f in child.iterdir() if f.is_file()]
        media_files = [f for f in files if f.suffix.lower() in MEDIA_EXTS]
        if not media_files:
            continue
        srts = sorted(f.name for f in files if f.suffix.lower() == ".srt")
        total_mb = round(sum(f.stat().st_size for f in files) / (1024 * 1024), 1)
        dirs.append({"dir": child.name, "total_mb": total_mb, "srts": srts, "file_count": len(files)})
    return dirs


def _scan_inbox(root: Path) -> dict[str, Any]:
    """Check notes/00-inbox.md for uncategorized lines below the capture marker."""
    inbox = root / "notes" / "00-inbox.md"
    if not inbox.is_file():
        return {"exists": False, "line_count": 0, "preview": []}
    text = inbox.read_text(encoding="utf-8", errors="replace")
    body = text.split(CAPTURE_MARKER, 1)[1] if CAPTURE_MARKER in text else text
    lines = [line.strip() for line in body.splitlines() if line.strip()]
    return {"exists": True, "line_count": len(lines), "preview": lines[:3]}


def _check_mirrors(root: Path) -> list[dict[str, str]]:
    """Verify hash parity between reports/*.md and notes/workspace-reports/*.md."""
    reports_dir = root / "reports"
    mirror_dir = root / "notes" / "workspace-reports"
    if not reports_dir.is_dir() or not mirror_dir.is_dir():
        return []
    results: list[dict[str, str]] = []
    for src in sorted(reports_dir.glob("*.md")):
        dst = mirror_dir / src.name
        if not dst.is_file():
            status = "missing_mirror"
        elif _sha256(src) == _sha256(dst):
            status = "match"
        else:
            status = "diverged"
        results.append({"file": src.name, "status": status})
    return results


def scan_workspace(root: Path) -> dict[str, Any]:
    """Collect read-only triage state across screenshots, videos, inbox, and mirrors."""
    return {
        "root": str(root),
        "screenshots": _scan_screenshots(root),
        "video_dirs": _scan_video_dirs(root),
        "inbox": _scan_inbox(root),
        "mirrors": _check_mirrors(root),
    }


def _print_text(report: dict[str, Any]) -> None:
    """Format scan findings as compact, human-readable lines."""
    shots = report["screenshots"]
    vids = report["video_dirs"]
    inbox = report["inbox"]
    non_match = [m for m in report["mirrors"] if m["status"] != "match"]

    print(f"Screenshots ({len(shots)}): " + (", ".join(s["name"] for s in shots) or "none"))
    print(f"Video dirs ({len(vids)}):")
    for v in vids:
        print(f"  - {v['dir']} ({v['total_mb']} MB, {len(v['srts'])} srt)")
    print(f"Inbox lines below marker: {inbox['line_count']}")
    for line in inbox["preview"]:
        print(f"  > {line[:100]}")
    if non_match:
        print("Mirror mismatches: " + ", ".join(f"{m['file']}={m['status']}" for m in non_match))
    else:
        print(f"Report mirrors: all {len(report['mirrors'])} matched")


def main() -> int:
    """CLI entrypoint."""
    parser = argparse.ArgumentParser(description="Scan workspace for triage targets.")
    parser.add_argument("root", nargs="?", default="/workspace", help="Workspace root path")
    parser.add_argument("--json", action="store_true", help="Emit JSON output")
    args = parser.parse_args()

    report = scan_workspace(Path(args.root).resolve())
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        _print_text(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
