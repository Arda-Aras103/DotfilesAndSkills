#!/usr/bin/env bash
set -euo pipefail

ZED_DIR="$HOME/.config/zed"
ZED_CFG="$ZED_DIR/settings.json"

echo "[1/2] Backing up Zed settings file..."
mkdir -p "$ZED_DIR"
if [[ -f "$ZED_CFG" && ! -f "$ZED_CFG.rice.bak" ]]; then
  cp -f "$ZED_CFG" "$ZED_CFG.rice.bak"
fi

echo "[2/2] Writing Zed Tokyo Night colors, JetBrainsMono Nerd Font, and minimal UI..."
python3 - <<'EOF'
import json
import os
import re

path = os.path.expanduser("~/.config/zed/settings.json")

def strip_jsonc(text):
    out = []
    i, n = 0, len(text)
    in_str = False
    esc = False
    while i < n:
        ch = text[i]
        if in_str:
            out.append(ch)
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            i += 1
            continue
        if ch == '"':
            in_str = True
            out.append(ch)
            i += 1
        elif ch == "/" and i + 1 < n and text[i + 1] == "/":
            i += 2
            while i < n and text[i] != "\n":
                i += 1
        elif ch == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i += 2
        else:
            out.append(ch)
            i += 1
    cleaned = "".join(out)
    return re.sub(r",(\s*[}\]])", r"\1", cleaned)

data = {}
if os.path.exists(path):
    raw = open(path, "r", encoding="utf-8").read().strip()
    if raw:
        data = json.loads(strip_jsonc(raw))

data["theme"] = "One Dark"
data["buffer_font_family"] = "JetBrainsMono Nerd Font"
data["buffer_font_size"] = 14
data["ui_font_family"] = "JetBrainsMono Nerd Font"
data["ui_font_size"] = 13
data["telemetry"] = {"diagnostics": False, "metrics": False}
data["toolbar"] = {"breadcrumbs": True, "quick_actions": False}
data["scrollbar"] = {"show": "auto"}
data["autosave"] = "on_focus_change"
data["ensure_final_newline_on_save"] = True
data["remove_trailing_whitespace_on_save"] = True

terminal = data.get("terminal", {})
if not isinstance(terminal, dict):
    terminal = {}
terminal["font_family"] = "JetBrainsMono Nerd Font"
data["terminal"] = terminal

inlay = data.get("inlay_hints", {})
if not isinstance(inlay, dict):
    inlay = {}
inlay.update({"enabled": True, "show_background": False})
data["inlay_hints"] = inlay

exts = data.get("auto_install_extensions", {})
if not isinstance(exts, dict):
    exts = {}
for ext_id in ("html", "toml", "sql", "dockerfile", "make", "basher", "git-firefly", "ini", "log"):
    exts.setdefault(ext_id, True)
data["auto_install_extensions"] = exts

overrides = data.get("experimental.theme_overrides", {})
if not isinstance(overrides, dict):
    overrides = {}
overrides.update({
    "background": "#1a1b26",
    "surface.background": "#16161e",
    "elevated_surface.background": "#16161e",
    "title_bar.background": "#16161e",
    "tab_bar.background": "#16161e",
    "tab.active_background": "#1a1b26",
    "tab.inactive_background": "#16161e",
    "toolbar.background": "#1a1b26",
    "status_bar.background": "#16161e",
    "panel.background": "#16161e",
    "editor.background": "#1a1b26",
    "editor.gutter.background": "#1a1b26",
    "editor.active_line.background": "#24283b",
    "element.hover": "#24283b",
    "element.selected": "#283457",
    "border": "#24283b",
    "border.variant": "#24283b",
    "text": "#c0caf5",
    "text.muted": "#565f89",
    "text.accent": "#7aa2f7",
})
data["experimental.theme_overrides"] = overrides

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
EOF

echo "Done. (Zed reloads settings live while running.)"
