#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="$HOME/.config/.rice-minimizeall-prev"

echo "[1/4] Backing up KWin and notification configs..."
for f in kwinrc plasmanotifyrc; do
  if [[ -f "$HOME/.config/$f" && ! -f "$HOME/.config/$f.ergo.bak" ]]; then
    cp -f "$HOME/.config/$f" "$HOME/.config/$f.ergo.bak"
  fi
done

if [[ ! -f "$STATE_FILE" ]]; then
  python3 - "$STATE_FILE" <<'PY'
import configparser
import os
import shlex
import sys

state_path = sys.argv[1]

def read_ini_opt(path, section, key):
    full_path = os.path.expanduser(path)
    if not os.path.exists(full_path):
        return ""
    cfg = configparser.ConfigParser(interpolation=None, strict=False)
    cfg.optionxform = str
    cfg.read(full_path, encoding="utf-8")
    return cfg.get(section, key, fallback="")

prev_plugin = read_ini_opt("~/.config/kwinrc", "Plugins", "minimizeallEnabled")
prev_show = read_ini_opt("~/.config/kglobalshortcutsrc", "kwin", "Show Desktop").split(",", 1)[0]
prev_min = read_ini_opt("~/.config/kglobalshortcutsrc", "kwin", "MinimizeAll").split(",", 1)[0]

os.makedirs(os.path.dirname(state_path), exist_ok=True)
with open(state_path, "w", encoding="utf-8") as f:
    f.write(f"PREV_MINIMIZE_ALL_PLUGIN={shlex.quote(prev_plugin)}\n")
    f.write(f"PREV_SHOW_DESKTOP_SC={shlex.quote(prev_show)}\n")
    f.write(f"PREV_MINIMIZE_ALL_SC={shlex.quote(prev_min)}\n")
PY
fi

echo "[2/4] Configuring centered window placement, MinimizeAll, and notification position..."
python3 - <<'EOF'
import configparser
import os

def update_ini(path, updates):
    full_path = os.path.expanduser(path)
    cfg = configparser.ConfigParser(interpolation=None, strict=False)
    cfg.optionxform = str
    if os.path.exists(full_path):
        cfg.read(full_path, encoding="utf-8")
    for section, kv in updates.items():
        if not cfg.has_section(section):
            cfg.add_section(section)
        for k, v in kv.items():
            cfg.set(section, k, str(v))
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    with open(full_path, "w", encoding="utf-8") as f:
        cfg.write(f, space_around_delimiters=False)

update_ini("~/.config/kwinrc", {
    "Windows": {
        "Placement": "Centered",
        "RollOverDesktops": "true",
    },
    "ElectricBorders": {
        "TopRight": "None",
        "BottomLeft": "None",
        "BottomRight": "None",
    },
    "Plugins": {
        "minimizeallEnabled": "true",
    },
})

update_ini("~/.config/plasmanotifyrc", {
    "Notifications": {
        "PopupPosition": "TopRight",
        "PopupTimeout": "4000",
    },
})
EOF

echo "[3/4] Reloading KWin and binding Meta+D -> MinimizeAll..."
dbus-send --session --print-reply --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setShortcutKeys \
  "['kwin', 'Show Desktop', 'KWin', 'Peek at Desktop']" "[]" 4 >/dev/null 2>&1 || true
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setShortcutKeys \
  "['kwin', 'MinimizeAll', 'KWin', 'Minimize all windows']" "[([268435524, 0, 0, 0],)]" 4 >/dev/null 2>&1 || true

echo "[4/4] Restarting Plasma Shell..."
systemctl --user restart plasma-plasmashell.service

echo "Done. (New windows open centered, Meta+D uses true MinimizeAll, notifications appear at top-right.)"
