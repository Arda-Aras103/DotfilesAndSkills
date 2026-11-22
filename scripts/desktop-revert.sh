#!/usr/bin/env bash
set -euo pipefail

APPLET_RC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
if [[ -f "$APPLET_RC.desktop.bak" ]]; then
  mv -f "$APPLET_RC.desktop.bak" "$APPLET_RC"
elif [[ -f "$APPLET_RC" ]]; then
  sed -i 's/plugin=org\.kde\.desktopcontainment/plugin=org.kde.plasma.folder/g' "$APPLET_RC"
fi

systemctl --user restart plasma-plasmashell.service
echo "Desktop folder view restored."
