#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="$HOME/.config/.rice-kwin-clean-prev"

echo "[1/5] Backing up existing settings..."
for f in ksplashrc ksmserverrc klaunchrc kaccessrc plasmaparc; do
  if [[ -f "$HOME/.config/$f" && ! -f "$HOME/.config/$f.clean.bak" ]]; then
    cp -f "$HOME/.config/$f" "$HOME/.config/$f.clean.bak"
  fi
done

if [[ ! -f "$STATE_FILE" ]]; then
  {
    printf 'PREV_SHAKE=%q\n' "$(kreadconfig6 --file kwinrc --group Plugins --key shakecursorEnabled 2>/dev/null || true)"
    printf 'PREV_LOGIN=%q\n' "$(kreadconfig6 --file kwinrc --group Plugins --key loginEnabled 2>/dev/null || true)"
    printf 'PREV_LOGOUT=%q\n' "$(kreadconfig6 --file kwinrc --group Plugins --key logoutEnabled 2>/dev/null || true)"
    printf 'PREV_FOCUS=%q\n' "$(kreadconfig6 --file kwinrc --group Windows --key FocusStealingPreventionLevel 2>/dev/null || true)"
  } > "$STATE_FILE"
fi

echo "[2/5] Disabling startup splash (KSplash) and previous session restore..."
kwriteconfig6 --file ksplashrc --group KSplash --key Engine none
kwriteconfig6 --file ksplashrc --group KSplash --key Theme None
kwriteconfig6 --file ksmserverrc --group General --key loginMode emptySession

echo "[3/5] Disabling bouncing launch cursor, login/logout effects, and shake-to-find cursor..."
kwriteconfig6 --file klaunchrc --group FeedbackStyle --key BusyCursor --type bool false
kwriteconfig6 --file kwinrc --group Plugins --key shakecursorEnabled --type bool false
kwriteconfig6 --file kwinrc --group Plugins --key loginEnabled --type bool false
kwriteconfig6 --file kwinrc --group Plugins --key logoutEnabled --type bool false
kwriteconfig6 --file kwinrc --group Windows --key FocusStealingPreventionLevel 2

echo "[4/5] Disabling system bell and volume change audio feedback..."
kwriteconfig6 --file kaccessrc --group Beeper --key Enabled --type bool false
kwriteconfig6 --file plasmaparc --group General --key AudioFeedback --type bool false

echo "[5/5] Reloading KWin and Plasma Shell..."
dbus-send --session --type=method_call --dest=org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect string:"shakecursor" >/dev/null 2>&1 || true
dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true
systemctl --user restart plasma-plasmashell.service

echo "Done. (Splash/session restore, bouncing cursor, shake-cursor, and audio feedback disabled.)"
