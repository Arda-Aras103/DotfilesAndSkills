#!/usr/bin/env bash
set -euo pipefail

echo "[1/4] Removing ~/.bashrc CLI block..."
if [[ -f "$HOME/.bashrc" ]]; then
  sed -i '/^# >>> rice-cli >>>$/,/^# <<< rice-cli <<<$/d' "$HOME/.bashrc"
fi

echo "[2/4] Removing bat config..."
rm -rf "$HOME/.config/bat"

echo "[3/4] Removing git delta config..."
git config --global --unset core.pager 2>/dev/null || true
git config --global --unset interactive.diffFilter 2>/dev/null || true
git config --global --unset delta.navigate 2>/dev/null || true
git config --global --unset delta.side-by-side 2>/dev/null || true
git config --global --unset delta.syntax-theme 2>/dev/null || true

echo "[4/4] Removing eza, bat, git-delta, and duf..."
sudo dnf remove -y eza bat git-delta duf || true
sudo dnf copr disable -y alternateved/eza 2>/dev/null || true
sudo dnf autoremove -y

echo "CLI cleanup complete. (Run exec bash to reload your current shell.)"
