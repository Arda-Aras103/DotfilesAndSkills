#!/usr/bin/env bash
set -euo pipefail

echo "[1/5] Backing up existing KDE configs..."
for f in kdeglobals kwinrc kglobalshortcutsrc; do
  if [[ -f "$HOME/.config/$f" && ! -f "$HOME/.config/$f.rice.bak" ]]; then
    cp -f "$HOME/.config/$f" "$HOME/.config/$f.rice.bak"
  fi
done

echo "[2/5] Disabling Baloo file indexing..."
if command -v balooctl6 >/dev/null 2>&1; then
  balooctl6 disable >/dev/null 2>&1 || true
  balooctl6 purge >/dev/null 2>&1 || true
fi

echo "[3/5] Writing animation speed, subtle Blur, 4 Virtual Desktops, and Shortcuts..."
python3 - <<'EOF'
import configparser
import os

def update_ini(path, updates):
    full_path = os.path.expanduser(path)
    cfg = configparser.ConfigParser(interpolation=None, strict=False)
    cfg.optionxform = str
    if os.path.exists(full_path):
        cfg.read(full_path)
    for section, kv in updates.items():
        if not cfg.has_section(section):
            cfg.add_section(section)
        for k, v in kv.items():
            cfg.set(section, k, str(v))
    with open(full_path, "w") as f:
        cfg.write(f, space_around_delimiters=False)

update_ini("~/.config/kdeglobals", {
    "KDE": {"AnimationDurationFactor": "0.25"}
})

update_ini("~/.config/kwinrc", {
    "Effect-blur": {"BlurStrength": "5", "NoiseStrength": "0"},
    "Desktops": {"Number": "4", "Rows": "1"},
})

update_ini("~/.config/kglobalshortcutsrc", {
    "kwin": {
        "Switch to Desktop 1": "Meta+1\\tCtrl+F1,Ctrl+F1,Switch to Desktop 1",
        "Switch to Desktop 2": "Meta+2\\tCtrl+F2,Ctrl+F2,Switch to Desktop 2",
        "Switch to Desktop 3": "Meta+3\\tCtrl+F3,Ctrl+F3,Switch to Desktop 3",
        "Switch to Desktop 4": "Meta+4\\tCtrl+F4,Ctrl+F4,Switch to Desktop 4",
        "Window to Desktop 1": "Meta+Shift+1,none,Window to Desktop 1",
        "Window to Desktop 2": "Meta+Shift+2,none,Window to Desktop 2",
        "Window to Desktop 3": "Meta+Shift+3,none,Window to Desktop 3",
        "Window to Desktop 4": "Meta+Shift+4,none,Window to Desktop 4",
        "Window Close": "Meta+Q\\tAlt+F4,Alt+F4,Close Window",
    }
})
EOF

echo "[4/5] Moving panel to top (Floating + 34px)..."
dbus-send --session --type=method_call --dest=org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
  'string:panels().forEach(function(p){ p.location = "top"; p.floating = true; p.height = 34; });' >/dev/null 2>&1 || true

echo "[5/5] Reloading KWin and global shortcuts service..."
dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure
systemctl --user restart plasma-kglobalaccel.service >/dev/null 2>&1 || true

echo "Done."
