#!/usr/bin/env bash
set -euo pipefail

APPLET_RC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

echo "[1/2] Restoring backed up panel config..."
if [[ -f "$APPLET_RC.dropdown.bak" ]]; then
  mv -f "$APPLET_RC.dropdown.bak" "$APPLET_RC"
fi

echo "[2/2] Restarting Plasma Shell..."
systemctl --user restart plasma-plasmashell.service
echo "Top panel reverted to previous visible/full-width layout."
