#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_RC="$HOME/.config/kscreenlockerrc"

if [[ -f "$SCRIPT_DIR/sddm-cyber-revert.sh" ]]; then
  if sudo test -d /usr/share/sddm/themes/cyber-wireframe || sudo test -f /etc/sddm.conf.d/.cyber-wireframe-state; then
    echo "[0/2] Reverting cyber-wireframe SDDM theme and display manager state..."
    bash "$SCRIPT_DIR/sddm-cyber-revert.sh" "$@"
  fi
fi

echo "[1/2] Restoring lock screen config..."
if [[ -f "$LOCK_RC.rice.bak" ]]; then
  mv -f "$LOCK_RC.rice.bak" "$LOCK_RC"
  rm -f "$LOCK_RC.rice.created"
elif [[ -f "$LOCK_RC.rice.created" ]]; then
  rm -f "$LOCK_RC" "$LOCK_RC.rice.created"
fi

echo "[2/2] Cleaning up SDDM theme.conf.user and copied wallpaper..."
for dir in /usr/share/sddm/themes/*; do
  [[ -d "$dir" ]] || continue
  [[ "$(basename "$dir")" == "cyber-wireframe" ]] && continue
  sudo rm -f "$dir"/rice-wallpaper.* 2>/dev/null || true
  if sudo test -f "$dir/theme.conf.user.rice.bak"; then
    sudo mv -f "$dir/theme.conf.user.rice.bak" "$dir/theme.conf.user"
    sudo rm -f "$dir/theme.conf.user.rice.created" 2>/dev/null || true
  elif sudo test -f "$dir/theme.conf.user.rice.created" || sudo grep -qE 'rice-wallpaper|#1a1b26' "$dir/theme.conf.user" 2>/dev/null; then
    sudo rm -f "$dir/theme.conf.user" "$dir/theme.conf.user.rice.created" 2>/dev/null || true
  fi
done

rm -f "$HOME/.local/share/wallpapers/cyber-lockscreen.svg" "$HOME/.local/share/wallpapers/cyber-lockscreen.png"
echo "Lock screen and SDDM settings reverted."
