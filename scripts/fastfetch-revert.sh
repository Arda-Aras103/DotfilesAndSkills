#!/usr/bin/env bash
set -euo pipefail

echo "[1/2] Cleaning up Fastfetch config, logos, and alias..."
if [[ -f "$HOME/.config/fastfetch/config.jsonc.rice.bak" ]]; then
  mv -f "$HOME/.config/fastfetch/config.jsonc.rice.bak" "$HOME/.config/fastfetch/config.jsonc"
else
  rm -f "$HOME/.config/fastfetch/config.jsonc"
fi
rm -rf "$HOME/.config/fastfetch/logos" "$HOME/.config/fastfetch/fastfetch-rotate.sh" "$HOME/.config/fastfetch/rei.txt" "$HOME/.cache/fastfetch-logo-idx"
if [[ -f "$HOME/.bashrc" ]]; then
  sed -i '/fastfetch-rotate\.sh/d' "$HOME/.bashrc"
fi

echo "[2/2] Removing Fastfetch package..."
sudo dnf remove -y fastfetch || true
sudo dnf autoremove -y
echo "Fastfetch cleanup complete."
