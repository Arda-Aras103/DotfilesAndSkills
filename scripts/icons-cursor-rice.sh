#!/usr/bin/env bash
set -euo pipefail

ICON_DIR="$HOME/.local/share/icons"
STATE_FILE="$HOME/.config/.rice-icons-prev"

echo "[1/4] Saving current cursor setting..."
PREV_ICON="breeze-dark"
PREV_CURSOR="$(kreadconfig6 --file kcminputrc --group Mouse --key cursorTheme 2>/dev/null || true)"
if [[ -f "$STATE_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$STATE_FILE"
else
  printf 'PREV_CURSOR=%q\n' "${PREV_CURSOR:-breeze}" > "$STATE_FILE"
fi

echo "[2/4] Removing Papirus-Dark if present and installing Bibata-Modern-Ice cursor..."
if rpm -q papirus-icon-theme >/dev/null 2>&1; then
  sudo dnf remove -y papirus-icon-theme
  sudo dnf autoremove -y
fi

mkdir -p "$ICON_DIR"
if [[ ! -d "$ICON_DIR/Bibata-Modern-Ice" ]]; then
  TMP_TAR="$(mktemp --suffix=.tar.xz)"
  trap 'rm -f "$TMP_TAR"' EXIT
  curl -fsSL "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz" -o "$TMP_TAR"
  tar -xJf "$TMP_TAR" -C "$ICON_DIR"
  rm -f "$TMP_TAR"
fi

echo "[3/4] Preserving Breeze icons and applying Bibata-Modern-Ice cursor..."
if [[ "$(kreadconfig6 --file kdeglobals --group Icons --key Theme 2>/dev/null || true)" == "Papirus-Dark" ]]; then
  kwriteconfig6 --file kdeglobals --group Icons --key Theme "${PREV_ICON:-breeze-dark}"
fi

if command -v plasma-apply-cursortheme >/dev/null 2>&1; then
  plasma-apply-cursortheme Bibata-Modern-Ice --size 24 || true
else
  kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme "Bibata-Modern-Ice" --notify
  kwriteconfig6 --file kcminputrc --group Mouse --key cursorSize 24 --notify
fi

if command -v gsettings >/dev/null 2>&1; then
  if [[ "$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null || true)" == "'Papirus-Dark'" ]]; then
    gsettings set org.gnome.desktop.interface icon-theme "${PREV_ICON:-breeze-dark}" || true
  fi
  gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice" || true
fi

for ver in gtk-3.0 gtk-4.0; do
  INI="$HOME/.config/$ver/settings.ini"
  mkdir -p "$HOME/.config/$ver"
  if [[ -f "$INI.icons.bak" ]]; then
    mv -f "$INI.icons.bak" "$INI"
  fi
  if [[ -f "$INI" && ! -f "$INI.cursor.bak" ]]; then
    cp -f "$INI" "$INI.cursor.bak"
  fi
  kwriteconfig6 --file "$INI" --group Settings --key gtk-cursor-theme-name "Bibata-Modern-Ice"
done

echo "[4/4] Refreshing icon cache and restarting Plasma Shell..."
rm -f "$HOME/.cache/icon-cache.kcache"
systemctl --user restart plasma-plasmashell.service

echo "Done. (Bibata-Modern-Ice cursor active, Breeze icons preserved.)"
