#!/usr/bin/env bash
# Revert scripts/vkbd-off.sh
set -euo pipefail

STATE_FILE="$HOME/.config/.rice-vkbd-prev"
SDDM_DROPIN="/etc/sddm.conf.d/zz-no-virtual-keyboard.conf"
SDDM_MAIN="/etc/sddm.conf"
PLM_DROPIN="/etc/plasmalogin.conf.d/zz-no-virtual-keyboard.conf"

echo "[1/2] Restoring kwinrc [Wayland] input method..."
PREV_IM="" PREV_VK=""
if [[ -f "$STATE_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$STATE_FILE"
  rm -f "$STATE_FILE"
fi
if [[ -n "$PREV_IM" ]]; then
  kwriteconfig6 --file kwinrc --group Wayland --key InputMethod "$PREV_IM"
else
  kwriteconfig6 --file kwinrc --group Wayland --key InputMethod --delete 2>/dev/null || true
fi
if [[ -n "$PREV_VK" ]]; then
  kwriteconfig6 --file kwinrc --group Wayland --key VirtualKeyboardEnabled "$PREV_VK"
else
  kwriteconfig6 --file kwinrc --group Wayland --key VirtualKeyboardEnabled --delete 2>/dev/null || true
fi
dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true

echo "[2/2] Restoring SDDM & Plasma Login Manager input method..."
sudo rm -f "$SDDM_DROPIN" "$PLM_DROPIN"
if sudo test -f "$SDDM_MAIN.vkbd.bak"; then
  sudo mv -f "$SDDM_MAIN.vkbd.bak" "$SDDM_MAIN"
fi
echo "Virtual keyboard settings reverted."
