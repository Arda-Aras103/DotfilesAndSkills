#!/usr/bin/env bash
set -euo pipefail

APPLET_RC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

echo "[1/3] Removing Panel Colorizer..."
kpackagetool6 --type Plasma/Applet --remove luisbocanegra.panel.colorizer 2>/dev/null || true

echo "[2/3] Restoring backed up panel config..."
if [[ -f "$APPLET_RC.rice.bak" ]]; then
  mv -f "$APPLET_RC.rice.bak" "$APPLET_RC"
  echo "  -> Backup restored."
fi

echo "[3/3] Restarting Plasma Shell..."
systemctl --user restart plasma-plasmashell.service
echo "Panel cleanup complete."
