#!/usr/bin/env bash
set -euo pipefail

echo "[1/3] Removing git-delta..."
sudo dnf remove -y git-delta
sudo dnf autoremove -y

echo "[2/3] Restoring Git config..."
if [[ -f "$HOME/.gitconfig.rice.bak" ]]; then
  mv -f "$HOME/.gitconfig.rice.bak" "$HOME/.gitconfig"
else
  git config --global --unset-all core.pager 2>/dev/null || true
  git config --global --unset-all interactive.diffFilter 2>/dev/null || true
  git config --global --unset-all diff.algorithm 2>/dev/null || true
  git config --global --unset-all fetch.prune 2>/dev/null || true
  git config --global --unset-all push.autoSetupRemote 2>/dev/null || true
  git config --global --unset-all rerere.enabled 2>/dev/null || true
  git config --global --unset-all merge.conflictstyle 2>/dev/null || true
  git config --global --remove-section delta 2>/dev/null || true
fi

echo "[3/3] Restoring keyboard repeat rate..."
if [[ -f "$HOME/.config/kcminputrc.rice.bak" ]]; then
  mv -f "$HOME/.config/kcminputrc.rice.bak" "$HOME/.config/kcminputrc"
else
  kwriteconfig6 --file kcminputrc --group Keyboard --key RepeatDelay --delete --notify 2>/dev/null || true
  kwriteconfig6 --file kcminputrc --group Keyboard --key RepeatRate --delete --notify 2>/dev/null || true
fi
kcminit keyboard >/dev/null 2>&1 || true

echo "git-delta and keyboard repeat settings reverted."
