#!/usr/bin/env bash
set -euo pipefail

TABBOX_STATE="$HOME/.config/.rice-tabbox-prev"
SPEC_RC="$HOME/.config/spectaclerc"

echo "[1/3] Setting Alt+Tab switcher to compact mode..."
if [[ ! -f "$TABBOX_STATE" ]]; then
  PREV_TABBOX="$(kreadconfig6 --file kwinrc --group TabBox --key LayoutName 2>/dev/null || true)"
  printf 'PREV_TABBOX=%q\n' "$PREV_TABBOX" > "$TABBOX_STATE"
fi
kwriteconfig6 --file kwinrc --group TabBox --key LayoutName compact

echo "[2/3] Configuring Spectacle auto-copy to clipboard + auto-quit + Meta+Shift+S..."
if [[ -f "$SPEC_RC" && ! -f "$SPEC_RC.rice.bak" ]]; then
  cp -f "$SPEC_RC" "$SPEC_RC.rice.bak"
fi
kwriteconfig6 --file spectaclerc --group General --key clipboardGroup PostScreenshotCopyImage
kwriteconfig6 --file spectaclerc --group GuiConfig --key quitAfterSaveCopyExport --type bool true

# Meta+Shift+S (301989971) + Meta+Shift+Print (318767113)
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setShortcutKeys \
  "['org.kde.spectacle.desktop', 'RectangularRegionScreenShot', 'Spectacle', 'Capture Rectangular Region']" \
  "[([301989971, 0, 0, 0],), ([318767113, 0, 0, 0],)]" 4 >/dev/null 2>&1 || true

echo "[3/3] Reloading KWin..."
dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true
echo "Done. (Alt+Tab simplified; press Meta+Shift+S to capture a region straight to clipboard.)"
