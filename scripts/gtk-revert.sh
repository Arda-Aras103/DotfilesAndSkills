#!/usr/bin/env bash
set -euo pipefail

echo "[1/4] Removing Flatpak GTK overrides and theme package..."
if command -v flatpak >/dev/null 2>&1; then
  flatpak override --user --unset-env=GTK_THEME 2>/dev/null || true
  flatpak override --user --nofilesystem=xdg-config/gtk-3.0 2>/dev/null || true
  flatpak override --user --nofilesystem=xdg-config/gtk-4.0 2>/dev/null || true
  flatpak uninstall -y --noninteractive org.gtk.Gtk3theme.adw-gtk3-dark 2>/dev/null || true
fi

echo "[2/4] Reverting GTK3 & GTK4 CSS overrides and settings.ini..."
for ver in gtk-3.0 gtk-4.0; do
  DIR="$HOME/.config/$ver"
  if [[ -f "$DIR/gtk.css.rice.bak" ]]; then
    mv -f "$DIR/gtk.css.rice.bak" "$DIR/gtk.css"
  else
    rm -f "$DIR/gtk.css"
  fi
  if [[ -f "$DIR/settings.ini.rice.bak" ]]; then
    mv -f "$DIR/settings.ini.rice.bak" "$DIR/settings.ini"
  else
    rm -f "$DIR/settings.ini"
  fi
done

echo "[3/4] Resetting gsettings and KDE gtkTheme to Breeze..."
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface gtk-theme "Breeze" || true
fi
if command -v kwriteconfig6 >/dev/null 2>&1; then
  kwriteconfig6 --file kdeglobals --group General --key gtkTheme "Breeze" || true
fi

echo "[4/4] Removing adw-gtk3-theme..."
sudo dnf remove -y adw-gtk3-theme || true
sudo dnf autoremove -y

echo "GTK/Flatpak cleanup complete."
