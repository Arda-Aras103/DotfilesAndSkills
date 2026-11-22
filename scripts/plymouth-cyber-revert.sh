#!/usr/bin/env bash
set -euo pipefail

THEME_DST="/usr/share/plymouth/themes/cyber-tokyo"
STATE_FILE="/etc/plymouth/.cyber-tokyo-state"

PREV_THEME=""
INSTALLED_PLUGIN=0
if sudo test -f "$STATE_FILE"; then
  PREV_THEME="$(sudo awk -F= '/^PREV_THEME=/{print $2; exit}' "$STATE_FILE" 2>/dev/null || true)"
  INSTALLED_PLUGIN="$(sudo awk -F= '/^INSTALLED_PLUGIN=/{print $2; exit}' "$STATE_FILE" 2>/dev/null || echo 0)"
fi

AVAILABLE_THEMES="$(plymouth-set-default-theme -l 2>/dev/null || true)"
theme_exists() {
  local target="$1"
  [[ -n "$target" && "$target" != "cyber-tokyo" ]] || return 1
  printf '%s\n' "$AVAILABLE_THEMES" | grep -Fxq "$target"
}

if ! theme_exists "$PREV_THEME"; then
  PREV_THEME=""
  for cand in bgrt spinner details; do
    if theme_exists "$cand"; then
      PREV_THEME="$cand"
      break
    fi
  done
  PREV_THEME="${PREV_THEME:-bgrt}"
fi

echo "[1/3] Restoring Plymouth theme ($PREV_THEME) and rebuilding initramfs..."
sudo plymouth-set-default-theme "$PREV_THEME" -R

echo "[2/3] Removing cyber-tokyo Plymouth theme files..."
sudo rm -rf "$THEME_DST"
sudo rm -f "$STATE_FILE"

if [[ "${INSTALLED_PLUGIN:-0}" == "1" ]]; then
  echo "[3/3] Removing plymouth-plugin-script..."
  sudo dnf remove -y plymouth-plugin-script || true
  sudo dnf autoremove -y || true
else
  echo "[3/3] Keeping pre-existing plymouth-plugin-script."
fi

ACTIVE_THEME="$(plymouth-set-default-theme 2>/dev/null || true)"
echo "Plymouth boot theme reverted to $PREV_THEME (active: ${ACTIVE_THEME:-unknown})."
