#!/usr/bin/env bash
set -euo pipefail

echo "[1/3] Removing btop, fzf, zoxide, fd-find, ripgrep, gdu, and procs..."
sudo dnf remove -y btop fzf zoxide fd-find ripgrep gdu procs || true
sudo dnf autoremove -y
rm -rf "$HOME/.local/share/zoxide" "$HOME/.cache/zoxide"

echo "[2/3] Cleaning up btop settings and theme..."
rm -f "$HOME/.config/btop/themes/tokyo-night.theme"
if [[ -f "$HOME/.config/btop/btop.conf.rice.bak" ]]; then
  mv -f "$HOME/.config/btop/btop.conf.rice.bak" "$HOME/.config/btop/btop.conf"
else
  rm -rf "$HOME/.config/btop"
fi

echo "[3/3] Removing fzf block from ~/.bashrc..."
if [[ -f "$HOME/.bashrc" ]]; then
  sed -i '/^# >>> rice-tui >>>$/,/^# <<< rice-tui <<<$/d' "$HOME/.bashrc"
  rm -f "$HOME/.bashrc.tui.bak"
fi

echo "TUI (btop + fzf + zoxide + fd + rg + gdu) cleanup complete. To activate: source ~/.bashrc"
