#!/usr/bin/env bash
set -euo pipefail

APPLET_RC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

echo "[1/3] Removing Plasmusic Toolbar..."
kpackagetool6 -r plasmusic-toolbar --type Plasma/Applet 2>/dev/null || true

echo "[2/3] Restoring backed up panel config..."
if [[ -f "$APPLET_RC.music.bak" ]]; then
  mv -f "$APPLET_RC.music.bak" "$APPLET_RC"
fi

echo "[3/3] Restarting Plasma Shell..."
systemctl --user restart plasma-plasmashell.service
echo "Plasmusic Toolbar cleanup complete."
