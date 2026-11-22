#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="$HOME/.config/.rice-kwin-clean-prev"

echo "[1/2] Restoring System Settings cleanup options..."
for f in ksplashrc ksmserverrc klaunchrc kaccessrc plasmaparc; do
  if [[ -f "$HOME/.config/$f.clean.bak" ]]; then
    mv -f "$HOME/.config/$f.clean.bak" "$HOME/.config/$f"
  else
    rm -f "$HOME/.config/$f"
  fi
done

restore_kwin_key() {
  local group="$1" key="$2" val="$3"
  if [[ -n "$val" ]]; then
    kwriteconfig6 --file kwinrc --group "$group" --key "$key" "$val"
  else
    kwriteconfig6 --file kwinrc --group "$group" --key "$key" --delete 2>/dev/null || true
  fi
}

PREV_SHAKE="" PREV_LOGIN="" PREV_LOGOUT="" PREV_FOCUS=""
if [[ -f "$STATE_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$STATE_FILE"
  rm -f "$STATE_FILE"
fi
restore_kwin_key Plugins shakecursorEnabled "$PREV_SHAKE"
restore_kwin_key Plugins loginEnabled "$PREV_LOGIN"
restore_kwin_key Plugins logoutEnabled "$PREV_LOGOUT"
restore_kwin_key Windows FocusStealingPreventionLevel "$PREV_FOCUS"

echo "[2/2] Reloading KWin and Plasma Shell..."
dbus-send --session --type=method_call --dest=org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect string:"shakecursor" >/dev/null 2>&1 || true
dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true
systemctl --user restart plasma-plasmashell.service
echo "Settings cleanup reverted."
