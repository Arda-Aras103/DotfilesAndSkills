#!/usr/bin/env bash
set -euo pipefail

APPLET_RC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

echo "[1/2] Backing up desktop config and hiding desktop icons..."
if [[ -f "$APPLET_RC" && ! -f "$APPLET_RC.desktop.bak" ]]; then
  cp -f "$APPLET_RC" "$APPLET_RC.desktop.bak"
fi

dbus-send --session --type=method_call --dest=org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
  'string:desktops().forEach(function(d){ d.wallpaperPlugin = "org.kde.image"; d.currentConfigGroup = ["General"]; });' >/dev/null 2>&1 || true

python3 - <<'EOF'
import os, re
p = os.path.expanduser("~/.config/plasma-org.kde.plasma.desktop-appletsrc")
if os.path.exists(p):
    with open(p, "r", encoding="utf-8") as f:
        text = f.read()
    new_text = text.replace("plugin=org.kde.plasma.folder", "plugin=org.kde.desktopcontainment")
    if new_text != text:
        with open(p, "w", encoding="utf-8") as f:
            f.write(new_text)
EOF

echo "[2/2] Restarting Plasma Shell..."
systemctl --user restart plasma-plasmashell.service
echo "Desktop icons removed (clean desktop)."
