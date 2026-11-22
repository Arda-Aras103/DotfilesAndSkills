#!/usr/bin/env bash
set -euo pipefail

echo "[1/3] Installing git-delta..."
sudo dnf install -y git-delta

echo "[2/3] Writing Git diff/delta Tokyo Night integration..."
if [[ -f "$HOME/.gitconfig" && ! -f "$HOME/.gitconfig.rice.bak" ]]; then
  cp -f "$HOME/.gitconfig" "$HOME/.gitconfig.rice.bak"
fi

git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.syntax-theme ansi
git config --global delta.dark true
git config --global delta.line-numbers true
git config --global delta.navigate true
git config --global delta.side-by-side true
git config --global delta.minus-style "syntax #3f2d3d"
git config --global delta.minus-emph-style "syntax #5c3448"
git config --global delta.plus-style "syntax #283b4d"
git config --global delta.plus-emph-style "syntax #315372"
git config --global diff.algorithm histogram
git config --global fetch.prune true
git config --global push.autoSetupRemote true
git config --global rerere.enabled true
git config --global merge.conflictstyle zdiff3

echo "[3/3] Increasing keyboard repeat speed (250ms delay / 45 cps)..."
if [[ -f "$HOME/.config/kcminputrc" && ! -f "$HOME/.config/kcminputrc.rice.bak" ]]; then
  cp -f "$HOME/.config/kcminputrc" "$HOME/.config/kcminputrc.rice.bak"
fi
kwriteconfig6 --file kcminputrc --group Keyboard --key RepeatDelay 250 --notify
kwriteconfig6 --file kcminputrc --group Keyboard --key RepeatRate 45 --notify
kcminit keyboard >/dev/null 2>&1 || true

echo "Done. (If keyboard repeat rate does not apply immediately, it will take effect on next login.)"
