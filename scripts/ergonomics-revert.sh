#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="$HOME/.config/.rice-minimizeall-prev"

shortcut_variant() {
  case "$1" in
    none) printf '[]\n' ;;
    Meta+D) printf '[([268435524, 0, 0, 0],)]\n' ;;
    Meta+Shift+D) printf '[([301989956, 0, 0, 0],)]\n' ;;
    *) printf '%s\n' "$2" ;;
  esac
}

echo "[1/3] Reverting notification and KWin ergonomics settings..."
if [[ -f "$HOME/.config/plasmanotifyrc.ergo.bak" ]]; then
  mv -f "$HOME/.config/plasmanotifyrc.ergo.bak" "$HOME/.config/plasmanotifyrc"
else
  rm -f "$HOME/.config/plasmanotifyrc"
fi

PREV_MINIMIZE_ALL_PLUGIN=""
PREV_SHOW_DESKTOP_SC=""
PREV_MINIMIZE_ALL_SC=""
if [[ -f "$STATE_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$STATE_FILE"
  rm -f "$STATE_FILE"
fi

if [[ -f "$HOME/.config/kwinrc.ergo.bak" ]]; then
  mv -f "$HOME/.config/kwinrc.ergo.bak" "$HOME/.config/kwinrc"
elif command -v kwriteconfig6 >/dev/null 2>&1; then
  if [[ -n "$PREV_MINIMIZE_ALL_PLUGIN" ]]; then
    kwriteconfig6 --file kwinrc --group Plugins --key minimizeallEnabled "$PREV_MINIMIZE_ALL_PLUGIN"
  else
    kwriteconfig6 --file kwinrc --group Plugins --key minimizeallEnabled --delete 2>/dev/null || true
  fi
fi

echo "[2/3] Restoring Meta+D shortcut to previous Peek at Desktop state..."
MIN_KEYS="$(shortcut_variant "$PREV_MINIMIZE_ALL_SC" "[]")"
SHOW_KEYS="$(shortcut_variant "$PREV_SHOW_DESKTOP_SC" "[([268435524, 0, 0, 0],)]")"
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setShortcutKeys \
  "['kwin', 'MinimizeAll', 'KWin', 'Minimize all windows']" "$MIN_KEYS" 4 >/dev/null 2>&1 || true
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setShortcutKeys \
  "['kwin', 'Show Desktop', 'KWin', 'Peek at Desktop']" "$SHOW_KEYS" 4 >/dev/null 2>&1 || true

echo "[3/3] Reloading KWin and Plasma Shell..."
dbus-send --session --print-reply --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true
systemctl --user restart plasma-plasmashell.service
echo "Ergonomics and notification settings reverted."
