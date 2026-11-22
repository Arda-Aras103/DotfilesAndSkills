#!/usr/bin/env python3
"""Wayland Layer-Shell Desktop Robot Vacuum (`desk-roomba`).

Transparent GTK4 + gtk4-layer-shell overlay for KDE Plasma (Wayland) and other
wlr-layer-shell compositors. Click the docked robot vacuum to sweep loose files
from watched directories into categorized subfolders under Organized/, or
right-click for a harmless visual demo sweep.
"""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
from dataclasses import dataclass
from datetime import datetime, timezone
import json
import math
import os
import random
import shutil
import signal
import subprocess
import sys
import time
import traceback
import urllib.parse
import uuid
import warnings
from pathlib import Path
from typing import Any

# Populated lazily by init_gui_bindings() after pre-loading libgtk4-layer-shell.
cairo: Any = None
Gdk: Any = None
Gio: Any = None
GLib: Any = None
Gtk: Any = None
Gtk4LayerShell: Any = None

DATA_DIR = Path.home() / ".local" / "share" / "desk-roomba"
HISTORY_FILE = DATA_DIR / "history.jsonl"
LOG_FILE = DATA_DIR / "roomba.log"

DOCK_SIZE = 90
DOCK_MARGIN_X = 48
DOCK_MARGIN_BOTTOM = 110
ROOMBA_RADIUS = 34.0
SUCTION_RANGE = 18.0
SUCK_DURATION = 0.28
WAKE_DURATION = 0.35
DONE_HOLD_DURATION = 1.4
MAX_CARDS_PER_WAVE = 24
AUTO_WATCH_MIN_AGE_SECS = 3.0

SKIP_SUFFIXES = {".desktop", ".part", ".crdownload", ".tmp"}
SCREENSHOT_PREFIXES = ("screenshot", "ekran", "spectacle", "grim", "ksnip")
MULTI_ARCHIVE_SUFFIXES = (".tar.gz", ".tar.xz", ".tar.zst", ".tar.bz2")

CATEGORY_RULES: tuple[tuple[str, frozenset[str]], ...] = (
    (
        "Documents",
        frozenset({
            ".pdf", ".txt", ".md", ".doc", ".docx", ".odt", ".rtf",
            ".pptx", ".xlsx", ".csv", ".epub",
        }),
    ),
    (
        "Images",
        frozenset({
            ".png", ".jpg", ".jpeg", ".webp", ".svg", ".gif", ".bmp", ".ico",
        }),
    ),
    (
        "Archives",
        frozenset({
            ".zip", ".tar", ".gz", ".xz", ".zst", ".bz2", ".7z", ".rar",
            ".iso", ".rpm", ".deb", ".appimage",
        }),
    ),
    (
        "Code",
        frozenset({
            ".py", ".rs", ".go", ".sh", ".js", ".ts", ".html", ".css",
            ".json", ".yaml", ".yml", ".toml", ".c", ".cpp", ".h", ".sql",
            ".patch",
        }),
    ),
    (
        "Media",
        frozenset({
            ".mp4", ".mkv", ".webm", ".mov", ".mp3", ".flac", ".wav",
            ".ogg", ".m4a",
        }),
    ),
)

SCREENSHOT_EXTENSIONS = frozenset({
    ".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif", ".mp4", ".mkv", ".webm",
})

BADGE_STYLES: dict[str, tuple[str, tuple[float, float, float]]] = {
    "Screenshots": ("SCR", (0.20, 0.56, 0.96)),
    "Documents": ("DOC", (0.88, 0.30, 0.28)),
    "Images": ("IMG", (0.16, 0.68, 0.56)),
    "Archives": ("ZIP", (0.85, 0.58, 0.14)),
    "Code": ("DEV", (0.48, 0.36, 0.88)),
    "Media": ("MED", (0.84, 0.28, 0.62)),
    "Folders": ("DIR", (0.24, 0.62, 0.92)),
    "Other": ("FILE", (0.42, 0.46, 0.54)),
}

DEMO_FILES: tuple[tuple[str, str, str], ...] = (
    ("boarding pass (1).pdf", "Documents", "PDF"),
    ("node_modules.zip", "Archives", "ZIP"),
    ("essay_final_real_final.txt", "Documents", "TXT"),
    ("Screenshot_2026-11-15.png", "Screenshots", "PNG"),
    ("design_system_v12.svg", "Images", "SVG"),
    ("meeting_notes_11.md", "Documents", "MD"),
    ("archive_do_not_open.tar.gz", "Archives", "TAR"),
    ("roomba_service.py", "Code", "PY"),
)


@dataclass
class FileTarget:
    """Visual card and optional real filesystem source queued for vacuuming."""

    name: str
    category: str
    badge: str
    x: float
    y: float
    src_path: Path | None = None
    is_demo: bool = False
    is_folder_style: bool = False
    suck_progress: float = 0.0
    spin_dir: float = 1.0


def log_message(msg: str) -> None:
    """Write a timestamped diagnostic message to stderr and LOG_FILE."""
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"[{timestamp}] {msg}"
    print(line, file=sys.stderr)
    try:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        with LOG_FILE.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except OSError:
        pass


def _find_layer_shell_library() -> str | None:
    """Locate libgtk4-layer-shell.so.0 in standard library paths."""
    candidates = (
        "/usr/lib64/libgtk4-layer-shell.so.0",
        "/usr/lib/libgtk4-layer-shell.so.0",
        "/lib64/libgtk4-layer-shell.so.0",
        "/usr/lib/x86_64-linux-gnu/libgtk4-layer-shell.so.0",
    )
    for path in candidates:
        if Path(path).is_file():
            return path
    return ctypes.util.find_library("gtk4-layer-shell")


def ensure_layer_shell_preload() -> None:
    """Re-exec with LD_PRELOAD so libgtk4-layer-shell interposes libwayland-client."""
    os.environ.pop("XDG_ACTIVATION_TOKEN", None)
    os.environ.pop("DESKTOP_STARTUP_ID", None)

    ld_preload = os.environ.get("LD_PRELOAD", "")
    if "libgtk4-layer-shell" in ld_preload or os.environ.get("_DESK_ROOMBA_PRELOADED") == "1":
        return

    lib_path = _find_layer_shell_library()
    if not lib_path:
        return

    env = os.environ.copy()
    env["LD_PRELOAD"] = f"{lib_path}:{ld_preload}" if ld_preload else lib_path
    env["_DESK_ROOMBA_PRELOADED"] = "1"
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    os.execve(sys.executable, [sys.executable, "-B", *sys.argv], env)


def init_gui_bindings() -> None:
    """Pre-load libgtk4-layer-shell.so.0 before importing gi and GTK4."""
    global cairo, Gdk, Gio, GLib, Gtk, Gtk4LayerShell

    # Fallback global load when LD_PRELOAD wasn't set externally.
    for lib_name in ("libgtk4-layer-shell.so.0", "libgtk4-layer-shell.so"):
        try:
            ctypes.CDLL(lib_name, mode=ctypes.RTLD_GLOBAL)
            break
        except OSError:
            continue

    try:
        import cairo as _cairo
        import gi

        gi.require_version("Gdk", "4.0")
        gi.require_version("Gtk", "4.0")
        gi.require_version("Gtk4LayerShell", "1.0")
        from gi.repository import Gdk as _Gdk
        from gi.repository import Gio as _Gio
        from gi.repository import GLib as _GLib
        from gi.repository import Gtk as _Gtk
        from gi.repository import Gtk4LayerShell as _Gtk4LayerShell
    except Exception as exc:
        log_message(
            "Missing GUI dependencies for desk-roomba.\n"
            f"Details: {exc}\n"
            "Install on Fedora with:\n"
            "  sudo dnf install -y gtk4-layer-shell python3-gobject python3-cairo"
        )
        sys.exit(1)

    cairo = _cairo
    Gdk = _Gdk
    Gio = _Gio
    GLib = _GLib
    Gtk = _Gtk
    Gtk4LayerShell = _Gtk4LayerShell


def _proc_starttime(pid: int) -> int:
    """Return process starttime in clock ticks from /proc/<pid>/stat, or 0."""
    try:
        stat_text = Path(f"/proc/{pid}/stat").read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return 0
    rparen = stat_text.rfind(")")
    if rparen == -1:
        return 0
    fields = stat_text[rparen + 1 :].split()
    if len(fields) <= 19:
        return 0
    try:
        return int(fields[19])
    except ValueError:
        return 0


def _is_desk_roomba_pid(pid: int) -> bool:
    """Return True if /proc/<pid> is a same-UID Python process running desk_roomba.py."""
    proc_path = Path(f"/proc/{pid}")
    try:
        if proc_path.stat().st_uid != os.getuid():
            return False
        raw = (proc_path / "cmdline").read_bytes()
    except OSError:
        return False
    parts = [p for p in raw.decode("utf-8", errors="ignore").split("\x00") if p]
    if len(parts) < 2:
        return False
    if not Path(parts[0]).name.lower().startswith("python"):
        return False
    return any(Path(arg).name == "desk_roomba.py" for arg in parts[1:])


def kill_existing_instances() -> None:
    """Terminate older running desk_roomba.py instances cleanly."""
    self_pid = os.getpid()
    parent_pid = os.getppid()
    self_start = _proc_starttime(self_pid)
    pids_to_stop: list[int] = []

    proc_dir = Path("/proc")
    if proc_dir.is_dir():
        try:
            entries = list(proc_dir.iterdir())
        except OSError:
            entries = []
        for entry in entries:
            if not entry.name.isdigit():
                continue
            pid = int(entry.name)
            if pid in (self_pid, parent_pid):
                continue
            if not _is_desk_roomba_pid(pid):
                continue
            other_start = _proc_starttime(pid)
            if self_start > 0 and other_start > 0:
                if (other_start, pid) >= (self_start, self_pid):
                    continue
            elif pid == self_pid:
                continue
            pids_to_stop.append(pid)

    for pid in pids_to_stop:
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            pass

    if pids_to_stop:
        deadline = time.monotonic() + 0.4
        remaining = list(pids_to_stop)
        while remaining and time.monotonic() < deadline:
            remaining = [p for p in remaining if Path(f"/proc/{p}").exists()]
            if remaining:
                time.sleep(0.05)
        for pid in remaining:
            try:
                os.kill(pid, signal.SIGKILL)
            except OSError:
                pass


def _uri_to_desktop_name(uri: str) -> str:
    decoded = urllib.parse.unquote(uri.strip())
    if decoded.startswith("desktop:/"):
        decoded = decoded[len("desktop:/"):]
    elif decoded.startswith("file://"):
        decoded = decoded[len("file://"):]
    return Path(decoded.rstrip("/")).name


def _extract_position_lists(raw_val: str, screen_w: int, screen_h: int) -> list[list[str]]:
    val = raw_val.strip()
    if not val:
        return []
    if val.startswith("{"):
        parsed_dict: dict[str, Any] | None = None
        for candidate in (val, val.replace('\\"', '"').replace("\\\\", "\\")):
            try:
                obj = json.loads(candidate)
                if isinstance(obj, dict):
                    parsed_dict = obj
                    break
            except json.JSONDecodeError:
                continue
        if not parsed_dict:
            return []
        res_key = f"{screen_w}x{screen_h}"
        ordered_keys = [k for k in parsed_dict if k != res_key]
        if res_key in parsed_dict:
            ordered_keys.append(res_key)
        lists: list[list[str]] = []
        for key in ordered_keys:
            arr = parsed_dict.get(key)
            if isinstance(arr, list):
                lists.append([str(x) for x in arr])
        return lists
    parts = [part.strip() for part in val.split(",") if part.strip()]
    return [parts] if parts else []


def _query_plasmashell_positions() -> list[tuple[int, str]]:
    """Query live in-memory arrangement and positions from plasmashell via D-Bus."""
    if Gio is None or GLib is None:
        return []
    script = (
        "var out = [];"
        "var list = desktops();"
        "for (var i = 0; i < list.length; i++) {"
        "  var d = list[i];"
        '  d.currentConfigGroup = ["General"];'
        '  var arr = parseInt(d.readConfig("arrangement", "0"), 10);'
        "  if (isNaN(arr)) arr = 0;"
        '  var rawPos = d.readConfig("positions", "");'
        '  var pos = Array.isArray(rawPos) ? rawPos.join(",") : String(rawPos || "");'
        "  if (pos) {"
        '    out.push({plugin: String(d.type || ""), arr: arr, pos: pos});'
        "  }"
        "}"
        "print(JSON.stringify(out));"
    )
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        res = bus.call_sync(
            "org.kde.plasmashell",
            "/PlasmaShell",
            "org.kde.PlasmaShell",
            "evaluateScript",
            GLib.Variant("(s)", (script,)),
            GLib.VariantType.new("(s)"),
            Gio.DBusCallFlags.NONE,
            600,
            None,
        )
        raw_out = str(res.unpack()[0]).strip()
        if not raw_out:
            return []
        parsed = json.loads(raw_out)
        if not isinstance(parsed, list):
            return []
        items = [x for x in parsed if isinstance(x, dict) and x.get("pos")]
        items.sort(key=lambda item: item.get("plugin") == "org.kde.plasma.folder")
        results: list[tuple[int, str]] = []
        for item in items:
            try:
                arr_val = int(item.get("arr", 0))
            except (TypeError, ValueError):
                arr_val = 0
            results.append((arr_val, str(item["pos"])))
        return results
    except Exception:
        return []


def _try_int(tok: str) -> int | None:
    try:
        return int(tok)
    except ValueError:
        return None


def read_kde_desktop_positions(
    screen_w: int,
    screen_h: int,
) -> tuple[dict[str, tuple[float, float]], Any]:
    """Parse KDE Plasma desktop icon positions and return (name->xy, next_cell_fn)."""
    applets_rc = Path.home() / ".config" / "plasma-org.kde.plasma.desktop-appletsrc"
    containment_plugins: dict[str, str] = {}
    containment_arrangements: dict[str, int] = {}
    containment_positions: dict[str, str] = {}

    if applets_rc.is_file():
        current_section = ""
        try:
            lines = applets_rc.read_text(encoding="utf-8", errors="ignore").splitlines()
        except OSError:
            lines = []
        for raw_line in lines:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("[") and line.endswith("]"):
                current_section = line
                continue
            if "=" not in line:
                continue
            key, val = line.split("=", 1)
            key = key.strip()
            # Match [Containments][N]
            if current_section.startswith("[Containments][") and current_section.count("[") == 2:
                cid = current_section.split("][")[1].rstrip("]")
                if key == "plugin":
                    containment_plugins[cid] = val.strip()
            # Match [Containments][N][General]
            elif current_section.startswith("[Containments][") and current_section.endswith("][General]"):
                parts = current_section.strip("[]").split("][")
                if len(parts) == 3 and parts[0] == "Containments" and parts[2] == "General":
                    cid = parts[1]
                    if key == "arrangement":
                        try:
                            containment_arrangements[cid] = int(val.strip())
                        except ValueError:
                            pass
                    elif key == "positions":
                        containment_positions[cid] = val.strip()

    disk_candidates: list[tuple[bool, int, str]] = []
    for cid, pos_raw in containment_positions.items():
        is_folder = containment_plugins.get(cid) == "org.kde.plasma.folder"
        disk_candidates.append((is_folder, containment_arrangements.get(cid, 0), pos_raw))
    disk_candidates.sort(key=lambda item: item[0])

    candidates: list[tuple[int, str]] = [
        (arr_val, pos_raw) for _, arr_val, pos_raw in disk_candidates
    ]
    candidates.extend(_query_plasmashell_positions())

    rows = max(6, int((max(480, screen_h) - 56) // 100))
    cols = max(8, int((max(640, screen_w) - 24) // 100))
    arrangement = 0  # KDE default: left-to-right rows
    occupied: set[tuple[int, int]] = set()
    name_to_xy: dict[str, tuple[float, float]] = {}

    def cell_to_xy(row: int, col: int, n_rows: int, n_cols: int) -> tuple[float, float]:
        cell_w = (float(screen_w) - 24.0) / max(1, n_cols)
        cell_h = (float(screen_h) - 56.0) / max(1, n_rows)
        x = 12.0 + (float(col) + 0.5) * cell_w
        y = 10.0 + (float(row) + 0.5) * cell_h
        return x, y

    for cand_arr, raw_pos in candidates:
        token_lists = _extract_position_lists(raw_pos, screen_w, screen_h)
        if token_lists:
            arrangement = cand_arr
        for tokens in token_lists:
            if not tokens:
                continue
            r0 = _try_int(tokens[0]) if len(tokens) >= 2 else None
            c0 = _try_int(tokens[1]) if len(tokens) >= 2 else None
            if r0 is not None and c0 is not None:
                list_rows = max(1, r0)
                list_cols = max(1, c0)
                rows, cols = list_rows, list_cols
                idx = 2
            else:
                list_rows, list_cols = rows, cols
                idx = 0

            while idx + 2 < len(tokens):
                uri_tok, r_tok, c_tok = tokens[idx], tokens[idx + 1], tokens[idx + 2]
                idx += 3
                r_val = _try_int(r_tok)
                c_val = _try_int(c_tok)
                if r_val is None or c_val is None:
                    continue
                occupied.add((r_val, c_val))
                item_name = _uri_to_desktop_name(uri_tok)
                if item_name:
                    name_to_xy[item_name] = cell_to_xy(r_val, c_val, list_rows, list_cols)

    def next_unoccupied_xy() -> tuple[float, float]:
        if arrangement == 0:
            order = ((r, c) for r in range(rows) for c in range(cols))
        else:
            order = ((r, c) for c in range(cols) for r in range(rows))
        for r, c in order:
            if (r, c) not in occupied:
                occupied.add((r, c))
                return cell_to_xy(r, c, rows, cols)
        return cell_to_xy(0, 0, rows, cols)

    desktop_dir = Path.home() / "Desktop"
    if desktop_dir.is_dir():
        try:
            visible_entries = sorted(
                (p for p in desktop_dir.iterdir() if not p.name.startswith(".")),
                key=lambda p: (not p.is_dir(), p.name.lower()),
            )
        except OSError:
            visible_entries = []
        for entry in visible_entries:
            if entry.name not in name_to_xy:
                name_to_xy[entry.name] = next_unoccupied_xy()

    return name_to_xy, next_unoccupied_xy


def classify_file(path: Path) -> tuple[str, str]:
    """Return (category_name, short_badge) for a file or folder path."""
    if path.is_dir():
        return "Folders", "DIR"

    name_lower = path.name.lower()
    suffix = path.suffix.lower()

    if name_lower.startswith(SCREENSHOT_PREFIXES) and suffix in SCREENSHOT_EXTENSIONS:
        return "Screenshots", (suffix.lstrip(".").upper()[:4] or "SCR")

    for category, extensions in CATEGORY_RULES:
        if suffix in extensions:
            badge = suffix.lstrip(".").upper()[:4] or BADGE_STYLES[category][0]
            return category, badge

    badge = suffix.lstrip(".").upper()[:4] or "FILE"
    return "Other", badge


def split_name_and_suffix(filename: str) -> tuple[str, str]:
    """Split filename while preserving multi-part tar archive suffixes."""
    lower = filename.lower()
    for multi in MULTI_ARCHIVE_SUFFIXES:
        if lower.endswith(multi) and len(filename) > len(multi):
            idx = len(filename) - len(multi)
            return filename[:idx], filename[idx:]
    p = Path(filename)
    return p.stem, p.suffix


def resolve_unique_dest(dest_folder: Path, filename: str, is_dir: bool = False) -> Path:
    """Return a non-colliding path inside dest_folder (appending _1, _2, ...)."""
    candidate = dest_folder / filename
    if not candidate.exists():
        return candidate

    if is_dir:
        stem, suffix = filename, ""
    else:
        stem, suffix = split_name_and_suffix(filename)
    counter = 1
    while True:
        numbered = dest_folder / f"{stem}_{counter}{suffix}"
        if not numbered.exists():
            return numbered
        counter += 1


def scan_loose_files(
    watch_dirs: list[Path],
    dest_dir: Path,
    min_age_seconds: float = 0.0,
) -> list[Path]:
    """Find eligible loose files and folders in watch_dirs with strict safety guards."""
    found: list[Path] = []
    dest_resolved = dest_dir.resolve()
    watch_resolved = {wd.resolve() for wd in watch_dirs if wd.exists()}
    now_ts = datetime.now(timezone.utc).timestamp()

    for watch_dir in watch_dirs:
        if not watch_dir.exists() or not watch_dir.is_dir():
            continue
        try:
            entries = sorted(watch_dir.iterdir(), key=lambda p: p.name.lower())
        except OSError:
            continue

        for entry in entries:
            if entry.name.startswith("."):
                continue
            if entry.is_symlink():
                continue
            try:
                resolved = entry.resolve()
            except OSError:
                continue
            if (
                resolved == dest_resolved
                or dest_resolved in resolved.parents
                or resolved in dest_resolved.parents
                or resolved in watch_resolved
            ):
                continue
            is_dir = entry.is_dir()
            if not is_dir and not entry.is_file():
                continue
            if not is_dir and entry.suffix.lower() in SKIP_SUFFIXES:
                continue
            if min_age_seconds > 0.0:
                try:
                    mtime = entry.stat().st_mtime
                    if (now_ts - mtime) < min_age_seconds:
                        continue
                except OSError:
                    continue
            found.append(entry)

    return found


def append_history_record(batch_id: str, src: Path, dst: Path) -> None:
    """Append a single file-move operation to the JSONL undo log."""
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    record = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "batch_id": batch_id,
        "src": str(src),
        "dst": str(dst),
    }
    with HISTORY_FILE.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(record, ensure_ascii=False) + "\n")


def move_file_safely(src: Path, dest_root: Path, category: str, batch_id: str) -> Path | None:
    """Move src file/folder into dest_root/category without overwriting, recording undo history."""
    if not src.exists() or src.is_symlink() or (not src.is_file() and not src.is_dir()):
        return None

    target_dir = dest_root / category
    target_dir.mkdir(parents=True, exist_ok=True)
    dst = resolve_unique_dest(target_dir, src.name, is_dir=src.is_dir())
    shutil.move(str(src), str(dst))
    append_history_record(batch_id, src, dst)
    return dst


def run_undo(dest_root: Path) -> int:
    """Restore all files from the most recent batch in history.jsonl."""
    if not HISTORY_FILE.exists():
        print("No desk-roomba history found. Nothing to undo.")
        return 0

    records: list[dict[str, str]] = []
    with HISTORY_FILE.open("r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                item = json.loads(line)
                if "batch_id" in item and "src" in item and "dst" in item:
                    records.append(item)
            except json.JSONDecodeError:
                continue

    if not records:
        print("History is empty. Nothing to undo.")
        return 0

    last_batch_id = records[-1]["batch_id"]
    remaining = [r for r in records if r["batch_id"] != last_batch_id]
    to_restore = [r for r in records if r["batch_id"] == last_batch_id]

    restored_count = 0
    for rec in reversed(to_restore):
        src_orig = Path(rec["src"])
        dst_curr = Path(rec["dst"])
        if not dst_curr.exists():
            print(f"[skip] Missing moved file: {dst_curr}")
            continue

        src_orig.parent.mkdir(parents=True, exist_ok=True)
        restore_path = resolve_unique_dest(
            src_orig.parent,
            src_orig.name,
            is_dir=dst_curr.is_dir(),
        )
        shutil.move(str(dst_curr), str(restore_path))
        print(f"[restored] {dst_curr} -> {restore_path}")
        restored_count += 1

        # Clean up empty category directory and empty destination root if clean.
        cat_dir = dst_curr.parent
        parent_dir = cat_dir.parent
        try:
            if cat_dir.is_dir() and not any(cat_dir.iterdir()):
                cat_dir.rmdir()
            if parent_dir != Path.home() and parent_dir.is_dir() and not any(parent_dir.iterdir()):
                parent_dir.rmdir()
            if dest_root != Path.home() and dest_root.is_dir() and not any(dest_root.iterdir()):
                dest_root.rmdir()
        except OSError:
            pass

    if remaining:
        with HISTORY_FILE.open("w", encoding="utf-8") as fh:
            for rec in remaining:
                fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
    else:
        HISTORY_FILE.unlink(missing_ok=True)

    print(f"Undo complete: restored {restored_count} file(s) from batch {last_batch_id[:8]}.")
    return 0


def normalize_angle(angle: float) -> float:
    """Wrap angle to [-pi, pi]."""
    return (angle + math.pi) % (2.0 * math.pi) - math.pi


def truncate_label(text: str, max_chars: int = 18) -> str:
    """Truncate long filenames cleanly for compact card pills."""
    if len(text) <= max_chars:
        return text
    return text[: max_chars - 3] + "..."


def rounded_rect_path(cr: Any, x: float, y: float, w: float, h: float, r: float) -> None:
    """Add a rounded rectangle path to a Cairo context."""
    r = max(0.0, min(r, w * 0.5, h * 0.5))
    cr.new_sub_path()
    cr.arc(x + w - r, y + r, r, -math.pi / 2.0, 0.0)
    cr.arc(x + w - r, y + h - r, r, 0.0, math.pi / 2.0)
    cr.arc(x + r, y + h - r, r, math.pi / 2.0, math.pi)
    cr.arc(x + r, y + r, r, math.pi, 3.0 * math.pi / 2.0)
    cr.close_path()


class DeskRoombaOverlay:
    """GTK4 Layer-Shell transparent overlay managing the Roomba and file cards."""

    def __init__(self, args: argparse.Namespace) -> None:
        self.watch_dirs = [Path(p).expanduser() for p in (args.dir or [str(Path.home() / "Desktop")])]
        self.dest_dir = Path(args.dest).expanduser()
        self.layer_name = args.layer
        self.speed = max(120.0, float(args.speed))
        self.auto_watch = bool(args.auto_watch)
        self.watch_interval = max(2, int(args.watch_interval))
        self.start_demo = bool(args.demo)
        self.start_sweep = bool(args.sweep)

        self.width = 1920
        self.height = 1080
        self.dock_x = float(DOCK_MARGIN_X)
        self.dock_y = float(self.height - DOCK_MARGIN_BOTTOM)

        self.rx = self.dock_x + DOCK_SIZE * 0.5
        self.ry = self.dock_y + DOCK_SIZE * 0.5
        self.heading = -math.pi * 0.25
        self.brush_angle = 0.0
        self.pulse_phase = 0.0

        self.state = "PARKED"  # PARKED, WAKING, MOVING, SUCKING, RETURNING, DOCKING
        self.state_timer = 0.0
        self.bubble_text = ""
        self.bubble_timer = 0.0

        self.targets: list[FileTarget] = []
        self.active_target: FileTarget | None = None
        self.current_batch_id = ""
        self.current_sweep_is_demo = False
        self.moved_in_batch = 0

        self.tick_source_id: int | None = None
        self.watch_source_id: int | None = None
        self.last_tick_us: int | None = None
        self._last_input_bounds: tuple[int, int, int, int] | None = None
        self._input_region_dirty = True
        self.rng = random.Random()

        self.app: Any = None
        self.window: Any = None
        self.drawing_area: Any = None

    def run(self) -> int:
        """Start the GTK4 application main loop."""
        self.app = Gtk.Application(
            application_id="dev.arda.DeskRoomba",
            flags=Gio.ApplicationFlags.NON_UNIQUE,
        )
        self.app.connect("activate", self._on_activate)

        try:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, self._on_unix_signal)
                GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, self._on_unix_signal)
        except AttributeError:
            pass

        status = int(self.app.run([]))
        if status != 0:
            log_message(f"Gtk.Application exited with non-zero status: {status}")
        return status

    def _on_unix_signal(self) -> int:
        log_message("desk-roomba received termination signal, quitting.")
        if self.app is not None:
            self.app.quit()
        return int(GLib.SOURCE_REMOVE)

    def _on_activate(self, app: Any) -> None:
        try:
            self.window = Gtk.ApplicationWindow(application=app)
            self.window.set_title("desk-roomba")
            self.window.set_decorated(False)
            self.window.set_focusable(False)
            self.window.add_css_class("desk-roomba-window")

            if not Gtk4LayerShell.is_supported():
                log_message(
                    "Error: Wayland wlr-layer-shell protocol is not supported by the current session."
                )
                app.quit()
                return

            layer_map = {
                "background": Gtk4LayerShell.Layer.BACKGROUND,
                "bottom": Gtk4LayerShell.Layer.BOTTOM,
                "top": Gtk4LayerShell.Layer.TOP,
                "overlay": Gtk4LayerShell.Layer.OVERLAY,
            }

            Gtk4LayerShell.init_for_window(self.window)
            Gtk4LayerShell.set_namespace(self.window, "desk-roomba")
            Gtk4LayerShell.set_layer(self.window, layer_map[self.layer_name])
            Gtk4LayerShell.set_exclusive_zone(self.window, -1)
            Gtk4LayerShell.set_keyboard_mode(self.window, Gtk4LayerShell.KeyboardMode.NONE)
            for edge in (
                Gtk4LayerShell.Edge.TOP,
                Gtk4LayerShell.Edge.BOTTOM,
                Gtk4LayerShell.Edge.LEFT,
                Gtk4LayerShell.Edge.RIGHT,
            ):
                Gtk4LayerShell.set_anchor(self.window, edge, True)

            self._install_transparent_css()

            self.drawing_area = Gtk.DrawingArea()
            self.drawing_area.set_hexpand(True)
            self.drawing_area.set_vexpand(True)
            self.drawing_area.set_draw_func(self._on_draw)
            self.drawing_area.connect("resize", self._on_resize)

            click = Gtk.GestureClick.new()
            click.set_button(0)
            click.connect("pressed", self._on_click_pressed)
            self.drawing_area.add_controller(click)

            self.window.set_child(self.drawing_area)
            self.window.connect("realize", self._on_window_map_or_realize)
            self.window.connect("map", self._on_window_map_or_realize)
            self.window.set_visible(True)
            self._force_kwin_show_desktop()
            GLib.timeout_add(120, self._force_kwin_show_desktop)
            GLib.timeout_add(280, self._force_kwin_show_desktop)
            log_message(f"desk-roomba active (layer={self.layer_name}, auto_watch={self.auto_watch})")

            if self.start_demo:
                GLib.timeout_add(350, self._trigger_initial_demo)
            elif self.start_sweep:
                GLib.timeout_add(350, self._trigger_initial_sweep)

            if self.auto_watch:
                self.watch_source_id = GLib.timeout_add_seconds(
                    self.watch_interval,
                    self._on_auto_watch_tick,
                )
        except Exception as exc:
            log_message(
                f"Error during desk-roomba activation: {exc}\n{traceback.format_exc()}"
            )
            app.quit()

    def _force_kwin_show_desktop(self) -> int:
        """Keep KWin in Show Desktop mode so closing KRunner does not raise old windows."""
        try:
            bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
            bus.call_sync(
                "org.kde.KWin",
                "/KWin",
                "org.kde.KWin",
                "setShowingDesktop",
                GLib.Variant("(b)", (True,)),
                None,
                Gio.DBusCallFlags.NONE,
                300,
                None,
            )
        except Exception:
            pass
        return int(GLib.SOURCE_REMOVE)

    def _install_transparent_css(self) -> None:
        css = (
            "window.desk-roomba-window, window.desk-roomba-window > * {"
            "  background-color: transparent;"
            "  background-image: none;"
            "  box-shadow: none;"
            "}"
        )
        provider = Gtk.CssProvider()
        if hasattr(provider, "load_from_string"):
            provider.load_from_string(css)
        else:
            provider.load_from_data(css.encode("utf-8"))

        display = Gdk.Display.get_default()
        if display is not None:
            Gtk.StyleContext.add_provider_for_display(
                display,
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
            )

    def _dock_center(self) -> tuple[float, float]:
        return self.dock_x + DOCK_SIZE * 0.5, self.dock_y + DOCK_SIZE * 0.5

    def _on_window_map_or_realize(self, _widget: Any) -> None:
        self._input_region_dirty = True
        self._update_input_region(force=True)

    def _on_resize(self, _area: Any, width: int, height: int) -> None:
        if width <= 0 or height <= 0:
            return
        self.width = width
        self.height = height
        self.dock_x = float(DOCK_MARGIN_X)
        self.dock_y = float(max(40, height - DOCK_MARGIN_BOTTOM))
        if self.state == "PARKED":
            self.rx, self.ry = self._dock_center()
        self._input_region_dirty = True
        self._update_input_region(force=True)
        self.drawing_area.queue_draw()

    def _update_input_region(self, force: bool = False) -> None:
        if self.window is None:
            return
        surface = self.window.get_surface()
        if surface is None:
            return

        dock_x = max(0, int(self.dock_x))
        dock_y = max(0, int(self.dock_y))
        bot_x = max(0, int(self.rx - 55))
        bot_y = max(0, int(self.ry - 70))
        bounds = (dock_x, dock_y, bot_x, bot_y)

        if not force and not self._input_region_dirty and bounds == self._last_input_bounds:
            return

        region = cairo.Region()
        region.union(cairo.RectangleInt(dock_x, dock_y, DOCK_SIZE, DOCK_SIZE))
        region.union(cairo.RectangleInt(bot_x, bot_y, 110, 125))

        surface.set_input_region(region)
        self._last_input_bounds = bounds
        self._input_region_dirty = False

    def _trigger_initial_demo(self) -> int:
        self.start_sweep_session(demo=True)
        return int(GLib.SOURCE_REMOVE)

    def _trigger_initial_sweep(self) -> int:
        files = scan_loose_files(self.watch_dirs, self.dest_dir)
        if files:
            self.start_sweep_session(demo=False, files=files)
        else:
            self._show_parked_bubble("victory", 1.8)
        return int(GLib.SOURCE_REMOVE)

    def _on_auto_watch_tick(self) -> int:
        if self.state != "PARKED":
            return int(GLib.SOURCE_CONTINUE)
        files = scan_loose_files(
            self.watch_dirs,
            self.dest_dir,
            min_age_seconds=AUTO_WATCH_MIN_AGE_SECS,
        )
        if files:
            self.start_sweep_session(demo=False, files=files)
        return int(GLib.SOURCE_CONTINUE)

    def _on_click_pressed(self, gesture: Any, _n_press: int, x: float, y: float) -> None:
        if not self._hit_interactive(x, y):
            return

        button = gesture.get_current_button()
        event_state = gesture.get_current_event_state()
        shift_held = bool(event_state & Gdk.ModifierType.SHIFT_MASK)

        if button == 2:  # Middle click: open Organized folder with Shift, else quit.
            if shift_held:
                self.dest_dir.mkdir(parents=True, exist_ok=True)
                subprocess.Popen(
                    ["xdg-open", str(self.dest_dir)],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
            elif self.app is not None:
                self.app.quit()
            return

        if self.state != "PARKED":
            return

        if button == 3:  # Right click: explicit visual demo sweep.
            self.start_sweep_session(demo=True)
            return

        if button == 1:  # Left click: sweep real loose items only; never spawn fake demo files.
            files = scan_loose_files(self.watch_dirs, self.dest_dir)
            if files:
                self.start_sweep_session(demo=False, files=files)
            else:
                self._show_parked_bubble("victory", 1.8)

    def _hit_interactive(self, x: float, y: float) -> bool:
        in_dock = (
            self.dock_x <= x <= self.dock_x + DOCK_SIZE
            and self.dock_y <= y <= self.dock_y + DOCK_SIZE
        )
        dist_bot = math.hypot(x - self.rx, y - self.ry)
        return in_dock or dist_bot <= (ROOMBA_RADIUS + 24.0)

    def _show_parked_bubble(self, text: str, duration: float) -> None:
        self.bubble_text = text
        self.bubble_timer = duration
        self._ensure_tick_running()
        self.drawing_area.queue_draw()

    def start_sweep_session(self, demo: bool, files: list[Path] | None = None) -> None:
        """Spawn scattered file cards and launch the Roomba from its dock."""
        self.targets.clear()
        self.active_target = None
        self.current_sweep_is_demo = demo
        self.current_batch_id = uuid.uuid4().hex
        self.moved_in_batch = 0

        if demo:
            raw_targets = self._build_demo_targets()
        else:
            raw_files = files if files is not None else scan_loose_files(self.watch_dirs, self.dest_dir)
            if not raw_files:
                self._show_parked_bubble("victory", 1.8)
                return
            raw_targets = self._build_file_targets(raw_files[:MAX_CARDS_PER_WAVE])

        self.targets = self._order_nearest_path(raw_targets)
        self.state = "WAKING"
        self.state_timer = WAKE_DURATION
        self.bubble_text = "vrrr..."
        self.bubble_timer = 1.0
        self._ensure_tick_running()
        self.drawing_area.queue_draw()

    def _build_demo_targets(self) -> list[FileTarget]:
        positions = self._generate_card_positions(len(DEMO_FILES))
        return [
            FileTarget(
                name=name,
                category=cat,
                badge=badge,
                x=px,
                y=py,
                src_path=None,
                is_demo=True,
                is_folder_style=(cat == "Archives" and idx % 2 == 1),
                spin_dir=1.0 if idx % 2 == 0 else -1.0,
            )
            for idx, ((name, cat, badge), (px, py)) in enumerate(zip(DEMO_FILES, positions))
        ]

    def _build_file_targets(self, files: list[Path]) -> list[FileTarget]:
        pos_map, next_cell_fn = read_kde_desktop_positions(self.width, self.height)
        desktop_dir = (Path.home() / "Desktop").resolve()
        fallback_positions = self._generate_card_positions(len(files))

        targets: list[FileTarget] = []
        for idx, fpath in enumerate(files):
            cat, badge = classify_file(fpath)
            if fpath.parent.resolve() == desktop_dir:
                px, py = pos_map.get(fpath.name) or next_cell_fn()
            else:
                px, py = fallback_positions[idx]
            targets.append(
                FileTarget(
                    name=fpath.name,
                    category=cat,
                    badge=badge,
                    x=px,
                    y=py,
                    src_path=fpath,
                    is_demo=False,
                    is_folder_style=(cat == "Folders"),
                    spin_dir=1.0 if idx % 2 == 0 else -1.0,
                )
            )
        return targets

    def _generate_card_positions(self, count: int) -> list[tuple[float, float]]:
        min_x = 120.0
        max_x = max(min_x + 80.0, float(self.width - 120))
        min_y = 95.0
        max_y = max(min_y + 80.0, float(self.height - 135))

        placed: list[tuple[float, float]] = []
        for _ in range(count):
            best_pos: tuple[float, float] | None = None
            best_min_dist = -1.0
            for _attempt in range(36):
                cx = self.rng.uniform(min_x, max_x)
                cy = self.rng.uniform(min_y, max_y)
                # Keep clear of the bottom-left charging dock corner.
                if cx < self.dock_x + DOCK_SIZE + 95.0 and cy > self.dock_y - 75.0:
                    continue
                if not placed:
                    best_pos = (cx, cy)
                    break
                nearest = min(math.hypot(cx - px, cy - py) for px, py in placed)
                if nearest >= 115.0:
                    best_pos = (cx, cy)
                    break
                if nearest > best_min_dist:
                    best_min_dist = nearest
                    best_pos = (cx, cy)
            if best_pos is None:
                best_pos = (self.rng.uniform(min_x, max_x), self.rng.uniform(min_y, max_y))
            placed.append(best_pos)
        return placed

    def _order_nearest_path(self, raw_targets: list[FileTarget]) -> list[FileTarget]:
        remaining = list(raw_targets)
        ordered: list[FileTarget] = []
        cur_x, cur_y = self.rx, self.ry
        while remaining:
            nearest_idx = min(
                range(len(remaining)),
                key=lambda i: math.hypot(remaining[i].x - cur_x, remaining[i].y - cur_y),
            )
            chosen = remaining.pop(nearest_idx)
            ordered.append(chosen)
            cur_x, cur_y = chosen.x, chosen.y
        return ordered

    def _ensure_tick_running(self) -> None:
        if self.tick_source_id is None:
            self.last_tick_us = GLib.get_monotonic_time()
            self.tick_source_id = GLib.timeout_add(16, self._on_tick)

    def _stop_tick(self) -> None:
        if self.tick_source_id is not None:
            GLib.source_remove(self.tick_source_id)
            self.tick_source_id = None
        self.last_tick_us = None

    def _on_tick(self) -> int:
        now_us = GLib.get_monotonic_time()
        dt = 0.016 if self.last_tick_us is None else (now_us - self.last_tick_us) / 1_000_000.0
        dt = max(0.001, min(dt, 0.05))
        self.last_tick_us = now_us

        self.pulse_phase += dt * 3.0
        if self.bubble_timer > 0.0:
            self.bubble_timer = max(0.0, self.bubble_timer - dt)
            if self.bubble_timer == 0.0:
                self.bubble_text = ""

        if self.state == "PARKED":
            if self.bubble_timer <= 0.0:
                self.tick_source_id = None
                self.last_tick_us = None
                self._update_input_region(force=True)
                self.drawing_area.queue_draw()
                return int(GLib.SOURCE_REMOVE)
        elif self.state == "WAKING":
            self.state_timer -= dt
            self.brush_angle += dt * 9.0
            if self.state_timer <= 0.0:
                if self.targets:
                    self.active_target = self.targets.pop(0)
                    self.state = "MOVING"
                else:
                    self.state = "RETURNING"
        elif self.state == "MOVING":
            self._step_moving(dt)
        elif self.state == "SUCKING":
            self._step_sucking(dt)
        elif self.state == "RETURNING":
            self._step_returning(dt)
        elif self.state == "DOCKING":
            self._step_docking(dt)

        self._update_input_region()
        self.drawing_area.queue_draw()
        return int(GLib.SOURCE_CONTINUE)

    def _steer_towards(self, tx: float, ty: float, dt: float) -> float:
        dx = tx - self.rx
        dy = ty - self.ry
        dist = math.hypot(dx, dy)
        if dist > 1e-3:
            desired = math.atan2(dy, dx)
            diff = normalize_angle(desired - self.heading)
            turn_step = min(abs(diff), 8.5 * dt)
            self.heading = normalize_angle(self.heading + math.copysign(turn_step, diff))

            # Slow down smoothly near target so suction alignment looks natural.
            ease = min(1.0, max(0.32, dist / 140.0))
            step = min(dist, self.speed * ease * dt)
            self.rx += math.cos(self.heading) * step
            self.ry += math.sin(self.heading) * step

        self.brush_angle += dt * 13.0
        return math.hypot(tx - self.rx, ty - self.ry)

    def _step_moving(self, dt: float) -> None:
        if self.active_target is None:
            if self.targets:
                self.active_target = self.targets.pop(0)
            else:
                self._begin_return()
                return

        dist = self._steer_towards(self.active_target.x, self.active_target.y, dt)
        if dist <= SUCTION_RANGE:
            self.state = "SUCKING"
            self.state_timer = SUCK_DURATION
            self.active_target.suck_progress = 0.001
            self.bubble_text = "victory"
            self.bubble_timer = SUCK_DURATION + 0.15
            if not self.active_target.is_demo and self.active_target.src_path is not None:
                try:
                    moved = move_file_safely(
                        self.active_target.src_path,
                        self.dest_dir,
                        self.active_target.category,
                        self.current_batch_id,
                    )
                    if moved is not None:
                        self.moved_in_batch += 1
                except OSError as exc:
                    print(
                        f"[warn] Could not move {self.active_target.src_path}: {exc}",
                        file=sys.stderr,
                    )
                self.active_target.src_path = None

    def _step_sucking(self, dt: float) -> None:
        target = self.active_target
        if target is None:
            self.state = "MOVING"
            return

        self.brush_angle += dt * 18.0
        self.state_timer = max(0.0, self.state_timer - dt)
        target.suck_progress = min(1.0, 1.0 - (self.state_timer / SUCK_DURATION))

        if self.state_timer <= 0.0:
            if not target.is_demo and target.src_path is not None:
                try:
                    moved = move_file_safely(
                        target.src_path,
                        self.dest_dir,
                        target.category,
                        self.current_batch_id,
                    )
                    if moved is not None:
                        self.moved_in_batch += 1
                except OSError as exc:
                    print(f"[warn] Could not move {target.src_path}: {exc}", file=sys.stderr)

            self.active_target = None
            if self.targets:
                self.active_target = self.targets.pop(0)
                self.state = "MOVING"
            elif not self.current_sweep_is_demo:
                # Check if additional files remain beyond MAX_CARDS_PER_WAVE.
                more_files = scan_loose_files(self.watch_dirs, self.dest_dir)
                if more_files:
                    self._queue_next_wave(more_files)
                    return
                self._begin_return()
            else:
                self._begin_return()

    def _queue_next_wave(self, files: list[Path]) -> None:
        raw_targets = self._build_file_targets(files[:MAX_CARDS_PER_WAVE])
        self.targets = self._order_nearest_path(raw_targets)
        self.active_target = self.targets.pop(0)
        self.state = "MOVING"

    def _begin_return(self) -> None:
        self.state = "RETURNING"
        self.bubble_text = "victory"
        self.bubble_timer = DONE_HOLD_DURATION

    def _step_returning(self, dt: float) -> None:
        dcx, dcy = self._dock_center()
        dist = self._steer_towards(dcx, dcy, dt)
        if dist <= 6.0:
            self.rx, self.ry = dcx, dcy
            self.state = "DOCKING"
            self.state_timer = 0.55
            if self.bubble_timer <= 0.1:
                self.bubble_text = "zzz"
                self.bubble_timer = 0.8

    def _step_docking(self, dt: float) -> None:
        rest_heading = -math.pi * 0.25
        diff = normalize_angle(rest_heading - self.heading)
        step = min(abs(diff), 6.0 * dt)
        self.heading = normalize_angle(self.heading + math.copysign(step, diff))
        self.state_timer -= dt
        if self.state_timer <= 0.0:
            self.heading = rest_heading
            self.state = "PARKED"
            if self.bubble_text == "victory":
                self.bubble_timer = min(self.bubble_timer, 0.5)

    def _on_draw(self, _area: Any, cr: Any, _width: int, _height: int) -> None:
        if self._input_region_dirty:
            self._update_input_region(force=True)

        self._draw_dock(cr)

        # Draw waiting/moving cards only in demo mode; real files are already drawn by Plasma.
        for target in self.targets:
            if target.is_demo:
                self._draw_file_card(cr, target)

        if self.active_target is not None and self.active_target.is_demo:
            self._draw_file_card(cr, self.active_target)

        if self.state in ("WAKING", "MOVING", "SUCKING", "RETURNING"):
            self._draw_headlight_cone(cr)

        self._draw_roomba(cr)

        if self.bubble_text and self.bubble_timer > 0.0:
            self._draw_speech_bubble(cr, self.bubble_text)

    def _draw_dock(self, cr: Any) -> None:
        cr.save()
        x, y, s = self.dock_x, self.dock_y, float(DOCK_SIZE)

        # Soft ground shadow
        rounded_rect_path(cr, x + 2.0, y + 5.0, s, s, 18.0)
        cr.set_source_rgba(0.0, 0.0, 0.0, 0.32)
        cr.fill()

        # Slate dock pad
        rounded_rect_path(cr, x, y, s, s, 18.0)
        cr.set_source_rgba(0.11, 0.13, 0.17, 0.88)
        cr.fill_preserve()
        cr.set_line_width(1.5)
        cr.set_source_rgba(0.75, 0.82, 0.92, 0.24)
        cr.stroke()

        # Metallic charging contacts along upper dock edge
        for offset_x in (x + 28.0, x + s - 38.0):
            rounded_rect_path(cr, offset_x, y + 10.0, 10.0, 5.0, 2.0)
            cr.set_source_rgba(0.78, 0.83, 0.90, 0.72)
            cr.fill()

        # Pulsing green LED
        pulse = 0.65 + 0.35 * math.sin(self.pulse_phase)
        cr.arc(x + s - 16.0, y + 16.0, 4.0, 0.0, 2.0 * math.pi)
        cr.set_source_rgba(0.20, 0.86, 0.56, pulse if self.state == "PARKED" else 0.95)
        cr.fill()

        # Micro DOCK label
        cr.select_font_face("Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
        cr.set_font_size(9.5)
        ext = cr.text_extents("DOCK")
        cr.move_to(x + (s - ext.width) * 0.5 - ext.x_bearing, y + s - 10.0)
        cr.set_source_rgba(0.78, 0.84, 0.92, 0.75)
        cr.show_text("DOCK")
        cr.restore()

    def _draw_file_card(self, cr: Any, target: FileTarget) -> None:
        p = target.suck_progress
        draw_x = target.x
        draw_y = target.y
        scale = 1.0
        rot = 0.0
        alpha = 1.0

        if p > 0.0:
            nozzle_x = self.rx + math.cos(self.heading) * (ROOMBA_RADIUS * 0.75)
            nozzle_y = self.ry + math.sin(self.heading) * (ROOMBA_RADIUS * 0.75)
            eased = p * p
            spiral_r = (1.0 - p) * 14.0 * math.sin(p * math.pi)
            perp_x = -math.sin(self.heading) * spiral_r * target.spin_dir
            perp_y = math.cos(self.heading) * spiral_r * target.spin_dir
            draw_x = target.x + (nozzle_x - target.x) * eased + perp_x
            draw_y = target.y + (nozzle_y - target.y) * eased + perp_y
            scale = max(0.05, 1.0 - eased * 0.92)
            rot = p * 4.2 * target.spin_dir
            alpha = max(0.0, 1.0 - max(0.0, (p - 0.55) / 0.45))

        cr.save()
        cr.translate(draw_x, draw_y)
        cr.rotate(rot)
        cr.scale(scale, scale)

        _default_badge, accent = BADGE_STYLES.get(target.category, BADGE_STYLES["Other"])
        badge_text = target.badge or _default_badge

        if target.is_folder_style:
            self._draw_folder_icon(cr, alpha)
        else:
            self._draw_document_icon(cr, badge_text, accent, alpha)

        # Filename pill under card
        label = truncate_label(target.name, 17)
        cr.select_font_face("Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
        cr.set_font_size(10.0)
        ext = cr.text_extents(label)
        pill_w = ext.width + 14.0
        pill_h = 18.0
        pill_x = -pill_w * 0.5
        pill_y = 26.0

        rounded_rect_path(cr, pill_x, pill_y, pill_w, pill_h, 6.0)
        cr.set_source_rgba(0.08, 0.10, 0.14, 0.76 * alpha)
        cr.fill()

        cr.move_to(-ext.width * 0.5 - ext.x_bearing, pill_y + 12.5)
        cr.set_source_rgba(0.97, 0.98, 1.0, 0.96 * alpha)
        cr.show_text(label)
        cr.restore()

    def _draw_document_icon(
        self,
        cr: Any,
        badge_text: str,
        accent: tuple[float, float, float],
        alpha: float,
    ) -> None:
        w, h, fold = 40.0, 48.0, 10.0
        x, y = -w * 0.5, -h * 0.5 - 4.0

        # Shadow
        rounded_rect_path(cr, x + 2.0, y + 3.0, w, h, 5.0)
        cr.set_source_rgba(0.0, 0.0, 0.0, 0.30 * alpha)
        cr.fill()

        # White page body with folded top-right corner
        cr.new_path()
        cr.move_to(x + 4.0, y)
        cr.line_to(x + w - fold, y)
        cr.line_to(x + w, y + fold)
        cr.line_to(x + w, y + h - 4.0)
        cr.arc(x + w - 4.0, y + h - 4.0, 4.0, 0.0, math.pi / 2.0)
        cr.line_to(x + 4.0, y + h)
        cr.arc(x + 4.0, y + h - 4.0, 4.0, math.pi / 2.0, math.pi)
        cr.line_to(x, y + 4.0)
        cr.arc(x + 4.0, y + 4.0, 4.0, math.pi, 3.0 * math.pi / 2.0)
        cr.close_path()
        cr.set_source_rgba(0.97, 0.98, 1.0, 0.98 * alpha)
        cr.fill_preserve()
        cr.set_line_width(1.0)
        cr.set_source_rgba(0.75, 0.80, 0.88, 0.7 * alpha)
        cr.stroke()

        # Folded triangle
        cr.new_path()
        cr.move_to(x + w - fold, y)
        cr.line_to(x + w - fold, y + fold)
        cr.line_to(x + w, y + fold)
        cr.close_path()
        cr.set_source_rgba(0.84, 0.88, 0.94, 0.95 * alpha)
        cr.fill()

        # Color badge pill
        rounded_rect_path(cr, x + 6.0, y + 13.0, w - 12.0, 14.0, 3.5)
        cr.set_source_rgba(accent[0], accent[1], accent[2], 0.95 * alpha)
        cr.fill()

        cr.select_font_face("Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
        cr.set_font_size(8.2)
        ext = cr.text_extents(badge_text)
        cr.move_to(x + (w - ext.width) * 0.5 - ext.x_bearing, y + 23.0)
        cr.set_source_rgba(1.0, 1.0, 1.0, alpha)
        cr.show_text(badge_text)

        # Decorative text lines
        for line_y, line_w in ((y + 33.0, 24.0), (y + 39.0, 18.0)):
            rounded_rect_path(cr, x + 8.0, line_y, line_w, 2.6, 1.3)
            cr.set_source_rgba(0.68, 0.73, 0.82, 0.75 * alpha)
            cr.fill()

    def _draw_folder_icon(self, cr: Any, alpha: float) -> None:
        w, h = 48.0, 38.0
        x, y = -w * 0.5, -h * 0.5 - 2.0

        # Folder back tab
        rounded_rect_path(cr, x, y - 5.0, 20.0, 12.0, 4.0)
        cr.set_source_rgba(0.24, 0.62, 0.92, 0.96 * alpha)
        cr.fill()

        # Folder front body
        rounded_rect_path(cr, x, y, w, h, 6.0)
        cr.set_source_rgba(0.36, 0.74, 0.98, 0.98 * alpha)
        cr.fill_preserve()
        cr.set_line_width(1.0)
        cr.set_source_rgba(0.18, 0.48, 0.78, 0.65 * alpha)
        cr.stroke()

    def _draw_headlight_cone(self, cr: Any) -> None:
        cr.save()
        cr.translate(self.rx, self.ry)
        cr.rotate(self.heading)

        cone_len = 135.0
        half_spread = 0.52

        grad = cairo.LinearGradient(ROOMBA_RADIUS * 0.5, 0.0, cone_len, 0.0)
        grad.add_color_stop_rgba(0.0, 0.74, 0.88, 1.0, 0.34)
        grad.add_color_stop_rgba(0.55, 0.74, 0.88, 1.0, 0.14)
        grad.add_color_stop_rgba(1.0, 0.74, 0.88, 1.0, 0.0)

        cr.new_path()
        cr.move_to(0.0, 0.0)
        cr.arc(0.0, 0.0, cone_len, -half_spread, half_spread)
        cr.close_path()
        cr.set_source(grad)
        cr.fill()
        cr.restore()

    def _draw_roomba(self, cr: Any) -> None:
        cr.save()
        cr.translate(self.rx, self.ry)

        # Ground drop shadow (unrotated)
        cr.arc(2.0, 5.0, ROOMBA_RADIUS + 1.5, 0.0, 2.0 * math.pi)
        cr.set_source_rgba(0.0, 0.0, 0.0, 0.36)
        cr.fill()

        cr.rotate(self.heading)

        # Rotating side sweeper brush near front-right bumper
        if self.state != "PARKED":
            bx = ROOMBA_RADIUS * 0.68
            by = ROOMBA_RADIUS * 0.56
            cr.save()
            cr.translate(bx, by)
            cr.rotate(self.brush_angle)
            cr.set_line_width(1.6)
            cr.set_source_rgba(0.62, 0.72, 0.84, 0.85)
            for idx in range(3):
                ang = idx * (2.0 * math.pi / 3.0)
                cr.move_to(0.0, 0.0)
                cr.line_to(math.cos(ang) * 14.0, math.sin(ang) * 14.0)
            cr.stroke()
            cr.restore()

        # Front metallic bumper arc
        cr.arc(0.0, 0.0, ROOMBA_RADIUS + 2.0, -math.pi * 0.48, math.pi * 0.48)
        cr.set_line_width(4.5)
        cr.set_source_rgba(0.76, 0.80, 0.86, 0.96)
        cr.stroke()

        # White circular main body
        body_grad = cairo.RadialGradient(-6.0, -6.0, 4.0, 0.0, 0.0, ROOMBA_RADIUS)
        body_grad.add_color_stop_rgba(0.0, 1.0, 1.0, 1.0, 1.0)
        body_grad.add_color_stop_rgba(0.78, 0.94, 0.95, 0.97, 1.0)
        body_grad.add_color_stop_rgba(1.0, 0.83, 0.86, 0.90, 1.0)
        cr.arc(0.0, 0.0, ROOMBA_RADIUS, 0.0, 2.0 * math.pi)
        cr.set_source(body_grad)
        cr.fill_preserve()
        cr.set_line_width(1.4)
        cr.set_source_rgba(0.65, 0.70, 0.78, 0.90)
        cr.stroke()

        # Subtle top panel seam arc
        cr.arc(0.0, 0.0, ROOMBA_RADIUS * 0.76, -math.pi * 0.42, math.pi * 0.42)
        cr.set_line_width(1.0)
        cr.set_source_rgba(0.75, 0.79, 0.85, 0.75)
        cr.stroke()

        # Front IR navigation sensor bump
        cr.arc(ROOMBA_RADIUS * 0.72, 0.0, 4.2, 0.0, 2.0 * math.pi)
        cr.set_source_rgba(0.22, 0.25, 0.30, 0.92)
        cr.fill()

        # Central metallic LiDAR / CLEAN button ring
        cr.arc(-2.0, 0.0, 12.0, 0.0, 2.0 * math.pi)
        cr.set_source_rgba(0.84, 0.87, 0.91, 1.0)
        cr.fill_preserve()
        cr.set_line_width(1.4)
        cr.set_source_rgba(0.62, 0.67, 0.74, 0.9)
        cr.stroke()

        # Inner hub
        cr.arc(-2.0, 0.0, 6.2, 0.0, 2.0 * math.pi)
        cr.set_source_rgba(0.28, 0.31, 0.36, 0.92)
        cr.fill()

        # 3 colored status dots on side (green, blue, cyan) matching reference design
        dot_specs = (
            (-11.0, -17.0, (0.20, 0.82, 0.48)),
            (-16.0, -13.0, (0.24, 0.56, 0.98)),
            (-19.0, -8.0, (0.18, 0.78, 0.86)),
        )
        for dx, dy, (r, g, b) in dot_specs:
            cr.arc(dx, dy, 2.5, 0.0, 2.0 * math.pi)
            cr.set_source_rgba(r, g, b, 0.98)
            cr.fill()

        cr.restore()

    def _draw_speech_bubble(self, cr: Any, text: str) -> None:
        cr.save()
        cr.select_font_face("Sans", cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD)
        cr.set_font_size(12.5)
        ext = cr.text_extents(text)

        pad_x = 12.0
        bw = max(46.0, ext.width + pad_x * 2.0)
        bh = 26.0
        bx = max(8.0, min(float(self.width) - bw - 8.0, self.rx - bw * 0.5))
        by = max(8.0, self.ry - ROOMBA_RADIUS - bh - 14.0)

        # Bubble shadow
        rounded_rect_path(cr, bx + 1.5, by + 2.5, bw, bh, 11.0)
        cr.set_source_rgba(0.0, 0.0, 0.0, 0.25)
        cr.fill()

        # Bubble body + bottom pointer triangle
        rounded_rect_path(cr, bx, by, bw, bh, 11.0)
        cr.set_source_rgba(1.0, 1.0, 1.0, 0.97)
        cr.fill_preserve()
        cr.set_line_width(1.1)
        cr.set_source_rgba(0.75, 0.80, 0.88, 0.85)
        cr.stroke()

        # Pointer triangle
        cr.new_path()
        cr.move_to(self.rx - 5.0, by + bh - 1.0)
        cr.line_to(self.rx + 5.0, by + bh - 1.0)
        cr.line_to(self.rx, by + bh + 6.5)
        cr.close_path()
        cr.set_source_rgba(1.0, 1.0, 1.0, 0.97)
        cr.fill()

        # Text
        cr.move_to(
            bx + (bw - ext.width) * 0.5 - ext.x_bearing,
            by + (bh + ext.height) * 0.5 - 1.0,
        )
        cr.set_source_rgba(0.12, 0.14, 0.18, 1.0)
        cr.show_text(text)
        cr.restore()


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="desk_roomba.py",
        description="Transparent Wayland layer-shell robot vacuum that organizes loose desktop files.",
    )
    parser.add_argument(
        "--dir",
        action="append",
        metavar="PATH",
        help="Directory to watch/sweep (repeatable; defaults to ~/Desktop).",
    )
    parser.add_argument(
        "--dest",
        default=str(Path.home() / "Desktop" / "Organized"),
        metavar="PATH",
        help="Destination folder for categorized files (default: ~/Desktop/Organized).",
    )
    parser.add_argument(
        "--layer",
        choices=("background", "bottom", "top", "overlay"),
        default="bottom",
        help="Wayland layer-shell layer (use 'bottom' to stay below normal windows; default: bottom).",
    )
    parser.add_argument(
        "--demo",
        action="store_true",
        help="Run a harmless visual demo sweep immediately without touching real files.",
    )
    parser.add_argument(
        "--sweep",
        action="store_true",
        help="Sweep loose files in --dir immediately on launch.",
    )
    parser.add_argument(
        "--auto-watch",
        action="store_true",
        help="Periodically check --dir while parked and sweep new clutter automatically.",
    )
    parser.add_argument(
        "--watch-interval",
        type=int,
        default=4,
        metavar="SECS",
        help="Polling interval in seconds for --auto-watch (default: 4).",
    )
    parser.add_argument(
        "--speed",
        type=float,
        default=340.0,
        metavar="PX_PER_SEC",
        help="Roomba driving speed in pixels per second (default: 340).",
    )
    parser.add_argument(
        "--undo",
        action="store_true",
        help="Restore files from the most recent sweep batch and exit.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_arg_parser()
    args = parser.parse_args(argv)

    if args.undo:
        return run_undo(Path(args.dest).expanduser())

    ensure_layer_shell_preload()
    kill_existing_instances()
    init_gui_bindings()
    overlay = DeskRoombaOverlay(args)
    return overlay.run()


if __name__ == "__main__":
    raise SystemExit(main())
