#!/usr/bin/env bash
# Disable the on-screen virtual keyboard everywhere: SDDM login screen,
# KDE Plasma Wayland session and the Win+L lock screen.
# Revert: bash scripts/vkbd-on.sh
set -euo pipefail

STATE_FILE="$HOME/.config/.rice-vkbd-prev"
SDDM_DROPIN="/etc/sddm.conf.d/zz-no-virtual-keyboard.conf"
SDDM_MAIN="/etc/sddm.conf"
PLM_DROPIN="/etc/plasmalogin.conf.d/zz-no-virtual-keyboard.conf"

echo "[1/3] Plasma session + lock screen (kwinrc [Wayland])..."
if [[ ! -f "$STATE_FILE" ]]; then
  {
    printf 'PREV_IM=%q\n' "$(kreadconfig6 --file kwinrc --group Wayland --key InputMethod 2>/dev/null || true)"
    printf 'PREV_VK=%q\n' "$(kreadconfig6 --file kwinrc --group Wayland --key VirtualKeyboardEnabled 2>/dev/null || true)"
  } > "$STATE_FILE"
fi
kwriteconfig6 --file kwinrc --group Wayland --key InputMethod ""
kwriteconfig6 --file kwinrc --group Wayland --key VirtualKeyboardEnabled --type bool false
dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true

echo "[2/3] SDDM & Plasma Login Manager login screen (InputMethod=)..."
if [[ -d /etc/sddm.conf.d ]] || rpm -q sddm >/dev/null 2>&1; then
  sudo install -d -m 755 /etc/sddm.conf.d
  printf '[General]\nInputMethod=\n' | sudo tee "$SDDM_DROPIN" >/dev/null
  sudo chmod 644 "$SDDM_DROPIN"
  # /etc/sddm.conf is read after drop-ins, so neutralise any explicit InputMethod there too.
  if sudo test -f "$SDDM_MAIN" && sudo grep -qE '^[[:space:]]*InputMethod=.+' "$SDDM_MAIN"; then
    sudo test -f "$SDDM_MAIN.vkbd.bak" || sudo cp -f "$SDDM_MAIN" "$SDDM_MAIN.vkbd.bak"
    sudo sed -i -E 's/^[[:space:]]*InputMethod=.+$/InputMethod=/' "$SDDM_MAIN"
  fi
  command -v restorecon >/dev/null 2>&1 && sudo restorecon "$SDDM_DROPIN" "$SDDM_MAIN" >/dev/null 2>&1 || true
fi
if [[ -d /etc/plasmalogin.conf.d ]] || rpm -q plasma-login-manager >/dev/null 2>&1; then
  sudo install -d -m 755 /etc/plasmalogin.conf.d
  printf '[General]\nInputMethod=\n' | sudo tee "$PLM_DROPIN" >/dev/null
  sudo chmod 644 "$PLM_DROPIN"
  command -v restorecon >/dev/null 2>&1 && sudo restorecon "$PLM_DROPIN" >/dev/null 2>&1 || true
fi

echo "[3/3] Done. Log out/in (or reboot) for kwin + SDDM to pick it up."
echo "Revert: bash $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/vkbd-on.sh"
