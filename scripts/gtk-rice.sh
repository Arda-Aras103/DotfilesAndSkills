#!/usr/bin/env bash
set -euo pipefail

echo "[1/4] Installing adw-gtk3-theme (Fedora + Flatpak)..."
sudo dnf install -y adw-gtk3-theme
if command -v flatpak >/dev/null 2>&1; then
  flatpak install -y --noninteractive flathub org.gtk.Gtk3theme.adw-gtk3-dark || true
fi

echo "[2/4] Configuring GTK dark theme and KDE gtkTheme sync..."
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark" || true
  gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" || true
fi
if command -v kwriteconfig6 >/dev/null 2>&1; then
  kwriteconfig6 --file kdeglobals --group General --key gtkTheme "adw-gtk3-dark" || true
fi

echo "[3/4] Writing GTK3 & GTK4 Tokyo Night color overrides and settings.ini..."
for ver in gtk-3.0 gtk-4.0; do
  DIR="$HOME/.config/$ver"
  mkdir -p "$DIR"
  if [[ -f "$DIR/gtk.css" && ! -f "$DIR/gtk.css.rice.bak" ]]; then
    cp -f "$DIR/gtk.css" "$DIR/gtk.css.rice.bak"
  fi
  cat <<'EOF' > "$DIR/gtk.css"
@define-color accent_color #7aa2f7;
@define-color accent_bg_color #7aa2f7;
@define-color accent_fg_color #1a1b26;
@define-color window_bg_color #1a1b26;
@define-color window_fg_color #c0caf5;
@define-color view_bg_color #1a1b26;
@define-color view_fg_color #c0caf5;
@define-color headerbar_bg_color #16161e;
@define-color headerbar_fg_color #c0caf5;
@define-color card_bg_color #24283b;
@define-color card_fg_color #c0caf5;
@define-color popover_bg_color #16161e;
@define-color popover_fg_color #c0caf5;
@define-color sidebar_bg_color #16161e;
@define-color sidebar_fg_color #c0caf5;
@define-color dialog_bg_color #16161e;
@define-color dialog_fg_color #c0caf5;
@define-color shade_color rgba(0, 0, 0, 0.36);
EOF

  if [[ -f "$DIR/settings.ini" && ! -f "$DIR/settings.ini.rice.bak" ]]; then
    cp -f "$DIR/settings.ini" "$DIR/settings.ini.rice.bak"
  fi
  cat <<'EOF' > "$DIR/settings.ini"
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=adw-gtk3-dark
EOF
done

echo "[4/4] Granting Flatpak apps GTK theme access..."
if command -v flatpak >/dev/null 2>&1; then
  flatpak override --user --env=GTK_THEME=adw-gtk3-dark
  flatpak override --user --filesystem=xdg-config/gtk-3.0:ro
  flatpak override --user --filesystem=xdg-config/gtk-4.0:ro
fi

echo "Done. Restart open GTK/Flatpak apps to apply Tokyo Night dark theme."
