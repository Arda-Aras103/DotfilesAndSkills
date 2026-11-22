#!/usr/bin/env bash
set -euo pipefail

TABBOX_STATE="$HOME/.config/.rice-tabbox-prev"
SPEC_RC="$HOME/.config/spectaclerc"

echo "[1/3] Restoring Alt+Tab layout..."
PREV_TABBOX=""
if [[ -f "$TABBOX_STATE" ]]; then
  # shellcheck disable=SC1090
  source "$TABBOX_STATE"
  rm -f "$TABBOX_STATE"
fi
if [[ -n "$PREV_TABBOX" ]]; then
  kwriteconfig6 --file kwinrc --group TabBox --key LayoutName "$PREV_TABBOX"
else
  kwriteconfig6 --file kwinrc --group TabBox --key LayoutName --delete 2>/dev/null || true
fi

echo "[2/3] Restoring Spectacle settings and shortcut..."
if [[ -f "$SPEC_RC.rice.bak" ]]; then
  mv -f "$SPEC_RC.rice.bak" "$SPEC_RC"
else
  rm -f "$SPEC_RC"
fi
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setShortcutKeys \
  "['org.kde.spectacle.desktop', 'RectangularRegionScreenShot', 'Spectacle', 'Capture Rectangular Region']" \
  "[([318767113, 0, 0, 0],)]" 4 >/dev/null 2>&1 || true

echo "[3/3] Reloading KWin..."
dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true
echo "Alt+Tab and Spectacle settings reverted."
