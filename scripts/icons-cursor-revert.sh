#!/usr/bin/env bash
set -euo pipefail

ICON_DIR="$HOME/.local/share/icons"
STATE_FILE="$HOME/.config/.rice-icons-prev"

PREV_CURSOR="breeze"
if [[ -f "$STATE_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$STATE_FILE"
fi

echo "[1/3] Removing Bibata-Modern-Ice cursor (and Papirus-Dark if present)..."
if rpm -q papirus-icon-theme >/dev/null 2>&1; then
  sudo dnf remove -y papirus-icon-theme
  sudo dnf autoremove -y
fi
rm -rf "$ICON_DIR/Bibata-Modern-Ice"

echo "[2/3] Restoring previous KDE and GTK cursor settings..."
if command -v plasma-apply-cursortheme >/dev/null 2>&1; then
  plasma-apply-cursortheme "$PREV_CURSOR" --size 24 || true
else
  kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme "$PREV_CURSOR" --notify
fi

if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface cursor-theme "$PREV_CURSOR" || true
fi

for ver in gtk-3.0 gtk-4.0; do
  INI="$HOME/.config/$ver/settings.ini"
  if [[ -f "$INI.cursor.bak" ]]; then
    mv -f "$INI.cursor.bak" "$INI"
  elif [[ -f "$INI.icons.bak" ]]; then
    mv -f "$INI.icons.bak" "$INI"
  else
    rm -f "$INI"
  fi
done
rm -f "$STATE_FILE"

echo "[3/3] Refreshing cache and restarting Plasma Shell..."
rm -f "$HOME/.cache/icon-cache.kcache"
systemctl --user restart plasma-plasmashell.service
echo "Cursor settings reverted."
