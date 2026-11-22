#!/usr/bin/env bash
set -euo pipefail

YAZI_DIR="$HOME/.config/yazi"

echo "[1/3] Removing yazi and COPR repository..."
sudo dnf remove -y yazi
sudo dnf copr remove -y lihaohong/yazi 2>/dev/null || sudo dnf copr disable -y lihaohong/yazi 2>/dev/null || true
sudo dnf autoremove -y

echo "[2/3] Cleaning up yazi configs, plugins, and flavor..."
if [[ -d "$YAZI_DIR" ]]; then
  rm -rf "$YAZI_DIR/flavors/tokyo-night.yazi" \
         "$YAZI_DIR/plugins/git.yazi" \
         "$YAZI_DIR/plugins/full-border.yazi" \
         "$YAZI_DIR/plugins/smart-enter.yazi"
  for f in yazi.toml theme.toml package.toml init.lua keymap.toml; do
    if [[ -f "$YAZI_DIR/$f.rice.bak" ]]; then
      mv -f "$YAZI_DIR/$f.rice.bak" "$YAZI_DIR/$f"
    else
      rm -f "$YAZI_DIR/$f"
    fi
  done
  rmdir "$YAZI_DIR/plugins" "$YAZI_DIR/flavors" "$YAZI_DIR" 2>/dev/null || true
fi

echo "[3/3] Removing 'y' function from ~/.bashrc..."
if [[ -f "$HOME/.bashrc" ]]; then
  sed -i '/^# >>> rice-yazi >>>$/,/^# <<< rice-yazi <<<$/d' "$HOME/.bashrc"
  rm -f "$HOME/.bashrc.yazi.bak"
fi

echo "yazi cleanup complete. To reload shell: exec bash"
