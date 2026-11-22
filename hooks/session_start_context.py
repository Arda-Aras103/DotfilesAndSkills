#!/usr/bin/env python3
"""Antigravity SessionStart hook that alerts only on imminent (<7d) deadlines."""

from __future__ import annotations

import datetime as dt
import re
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

from hook_common import emit_json, read_hook_payload

_DATE_RE = re.compile(r"\b(20\d{2}-\d{2}-\d{2})\b")
_MD_LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)\s]+)\)")
_ITEM_ID_RE = re.compile(r"\b((?:APP|TGT)-\d+)\b")
_STOP_SECTIONS = ("## Arşiv", "## Kapalı", "## Uymaz", "## Bakılmadı", "### Sonraki pencere")
_SKIP_ROW_MARKERS = ("❌ Red", "İptal", "Tamamlandı", "Son güncelleme")
_APPLIED_KANBAN_HEADERS = (
    "### 📨 Başvuruldu",
    "### 💻 OA / Teknik Test",
    "### 🗣️ Mülakat",
    "### 🎉 Teklif / Kabul",
    "### ❌ Red / İptal",
)
_GENERIC_URL_PATHS = frozenset(
    {
        "",
        "/",
        "/etkinlikler",
        "/etkinlikler/bootcamp",
        "/jobs",
        "/careers",
        "/careers/jobs",
        "/en/careers",
        "/tr/kariyer",
        "/kariyer",
        "/ilanlar",
        "/global/en/search-results",
    }
)
_GENERIC_LINK_TITLES = frozenset(
    {
        "resmi site",
        "resmi sayfa",
        "youthall",
        "apply",
        "apply now",
        "portal",
        "ilan",
        "duyuru",
        "program",
        "sr",
        "p&g careers",
        "coderspace sayfası",
        "smartrecruiters",
    }
)
_INBOX_UNCHECKED_RE = re.compile(r"^\s*[-*]\s+(?!\[[xX]\])(?:\[\s*\]\s+)?\S")


def _normalize_url(raw_url: str) -> str | None:
    """Normalize a URL for cross-file deduplication, ignoring generic listing roots."""
    try:
        parts = urlsplit(raw_url.strip())
    except ValueError:
        return None
    if parts.scheme not in {"http", "https"} or not parts.netloc:
        return None
    host = parts.netloc.lower().removeprefix("www.")
    path = parts.path.rstrip("/")
    if not parts.query and path.lower() in _GENERIC_URL_PATHS:
        return None
    base = f"{host}{path}"
    return f"{base}?{parts.query}" if parts.query else base


def _normalize_title(raw_title: str) -> list[str]:
    """Return normalized title variants (full and stripped of parenthetical/dash suffixes)."""
    cleaned = re.sub(r"[*_`]", "", raw_title).strip().lower()
    if not cleaned or cleaned in _GENERIC_LINK_TITLES:
        return []

    variants: list[str] = []
    for candidate in (
        cleaned,
        re.split(r"\s+[—–-]\s+(?:resmi|sonuç|hazırlık|engage|akademik)", cleaned, maxsplit=1)[0].strip(),
        re.sub(r"\s*\([^)]*\)\s*", " ", cleaned).strip(),
    ):
        norm = re.sub(r"\s+", " ", candidate).strip(" :-–—")
        if len(norm) >= 8 and norm not in _GENERIC_LINK_TITLES and norm not in variants:
            variants.append(norm)
    return variants


def _extract_links_and_titles(text: str) -> tuple[set[str], set[str]]:
    """Extract normalized specific URLs and title variants from markdown links in text."""
    urls: set[str] = set()
    titles: set[str] = set()
    for label, href in _MD_LINK_RE.findall(text):
        norm_url = _normalize_url(href)
        if norm_url:
            urls.add(norm_url)
        titles.update(_normalize_title(label))
    return urls, titles


def extract_applied_keys(apps_path: Path) -> tuple[set[str], set[str]]:
    """Extract specific URLs and normalized titles for submitted/accepted/closed apps."""
    if not apps_path.exists():
        return set(), set()

    urls: set[str] = set()
    titles: set[str] = set()
    in_applied_kanban = False

    for raw_line in apps_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line.startswith("### "):
            in_applied_kanban = any(line.startswith(h) for h in _APPLIED_KANBAN_HEADERS)
            continue
        if line.startswith("## "):
            in_applied_kanban = False
            continue

        if in_applied_kanban and line.startswith("- "):
            u, t = _extract_links_and_titles(line)
            urls.update(u)
            titles.update(t)
        elif line.startswith("| **APP-"):
            cols = [c.strip() for c in line.strip("|").split("|")]
            if len(cols) >= 3:
                u, t = _extract_links_and_titles(cols[2])
                urls.update(u)
                titles.update(t)
    return urls, titles


def line_matches_applied(line: str, applied_urls: set[str], applied_titles: set[str]) -> bool:
    """Return True if a career.md line matches an already-submitted/handled APP entry."""
    urls, titles = _extract_links_and_titles(line)
    if urls & applied_urls:
        return True
    for cand in titles:
        if cand in applied_titles:
            return True
        if len(cand) >= 12:
            for ref in applied_titles:
                if len(ref) >= 12 and (cand in ref or ref in cand):
                    return True
    return False


def _dedup_key_for_app_line(line: str, date_iso: str, summary_text: str) -> tuple[str, str]:
    """Build a canonical deduplication key across Yaklaşan Tarihler and the main table."""
    id_match = _ITEM_ID_RE.search(line)
    if id_match:
        return (date_iso, id_match.group(1))
    urls, titles = _extract_links_and_titles(line)
    if urls:
        return (date_iso, sorted(urls)[0])
    if titles:
        return (date_iso, sorted(titles, key=len)[0])
    return (date_iso, summary_text[:40].lower())


def _format_plain(text: str) -> str:
    """Strip markdown link targets and normalize whitespace."""
    plain = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    return re.sub(r"\s+", " ", plain).strip("-| ")


def _extract_urgent_lines(
    md_path: Path,
    today: dt.date,
    horizon_days: int = 7,
    applied_keys: tuple[set[str], set[str]] | None = None,
) -> list[str]:
    """Collect active markdown lines with dates within [today, today + horizon_days]."""
    if not md_path.exists():
        return []

    cutoff = today + dt.timedelta(days=horizon_days)
    hits: list[str] = []
    seen_app_keys: set[tuple[str, str]] = set()
    section_mode = "career" if md_path.name == "career.md" else ""
    applied_urls, applied_titles = applied_keys or (set(), set())

    for raw_line in md_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if any(line.startswith(sec) for sec in _STOP_SECTIONS):
            break
        if md_path.name == "applications.md":
            if line.startswith("## "):
                if "Yaklaşan Tarihler" in line:
                    section_mode = "upcoming"
                elif "Başvuru ve Hedef Tablosu" in line:
                    section_mode = "table"
                else:
                    section_mode = ""
                continue
            if not section_mode:
                continue

        if not line or line.startswith("#") or line.startswith("Güncel tarama"):
            continue
        if any(m in line for m in _SKIP_ROW_MARKERS):
            continue

        if section_mode == "career" and (applied_urls or applied_titles):
            if line_matches_applied(line, applied_urls, applied_titles):
                continue

        if section_mode == "table":
            if not line.startswith("|") or line.startswith("| ID ") or line.startswith("| :---"):
                continue
            cols = [c.strip() for c in line.strip("|").split("|")]
            if len(cols) < 7:
                continue
            # Scan ONLY "Son Tarih / Sonraki Adım" (col 6), never "Başvuru Tarihi" (col 5).
            scan_text = cols[6]
            display_source = f"{cols[0]} {cols[2]} — {cols[6]}"
        else:
            scan_text = line
            display_source = line

        for m in _DATE_RE.finditer(scan_text):
            try:
                parsed = dt.date.fromisoformat(m.group(1))
            except ValueError:
                continue
            if today <= parsed <= cutoff:
                clean = _format_plain(display_source)
                if md_path.name == "applications.md":
                    key = _dedup_key_for_app_line(line, parsed.isoformat(), clean)
                    if key in seen_app_keys:
                        break
                    seen_app_keys.add(key)
                hits.append(f"{parsed.isoformat()}: {clean[:100]}")
                break
    return hits


def check_inbox_backlog(inbox_path: Path, threshold: int = 10) -> str | None:
    """Return a zero-content count alert if notes/00-inbox.md meets or exceeds threshold."""
    if not inbox_path.is_file():
        return None
    count = 0
    for raw_line in inbox_path.read_text(encoding="utf-8").splitlines():
        if _INBOX_UNCHECKED_RE.match(raw_line):
            count += 1
    if count >= threshold:
        return f"[notes/00-inbox.md] {count} bekleyen ham not birikti"
    return None


def build_session_start_response(
    payload: dict[str, Any],
    today: dt.date | None = None,
) -> dict[str, Any]:
    """Return a concise SessionStart systemMessage only when <7d deadlines or inbox backlog exist."""
    ws_paths = payload.get("workspacePaths") or []
    root = Path(ws_paths[0]) if ws_paths else Path(__file__).resolve().parent.parent
    ref_day = today or dt.date.today()

    apps_path = root / "reports/applications.md"
    applied_keys = extract_applied_keys(apps_path)

    urgent: list[str] = []
    for rel, keys in (("reports/applications.md", None), ("reports/career.md", applied_keys)):
        for item in _extract_urgent_lines(root / rel, ref_day, applied_keys=keys):
            urgent.append(f"[{rel}] {item}")

    lines = [f"- {u}" for u in urgent[:5]]
    inbox_alert = check_inbox_backlog(root / "notes/00-inbox.md")
    if inbox_alert:
        lines.append(f"- {inbox_alert}")

    if not lines:
        return {"injectSteps": []}

    header = "Yaklaşan (<7 gün) tarihler:\n" if urgent else "Hatırlatmalar:\n"
    msg = header + "\n".join(lines)
    return {"injectSteps": [{"systemMessage": {"systemMessage": msg}}]}


def main() -> int:
    """Read stdin JSON and emit SessionStart context injection."""
    payload, exc = read_hook_payload()
    if exc is not None:
        emit_json({"injectSteps": []})
        return 0
    emit_json(build_session_start_response(payload))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
