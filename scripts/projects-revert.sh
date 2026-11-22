#!/usr/bin/env bash
set -euo pipefail

ZEN_PROFILE_ROOTS=(
  "$HOME/.zen"
  "$HOME/.var/app/app.zen_browser.zen/.zen"
  "$HOME/.var/app/io.github.zen_browser.zen/.zen"
)

zen_running=false
if pgrep -x zen >/dev/null 2>&1 || pgrep -f 'zen-bin' >/dev/null 2>&1; then
  zen_running=true
fi

restored=0

for root in "${ZEN_PROFILE_ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  for prof in "$root"/*; do
    [[ -d "$prof/extensions" ]] || continue
    for bak in "$prof/extensions/"*.xpi.rice.bak; do
      [[ -e "$bak" ]] || continue
      orig="${bak%.rice.bak}"
      mv -f "$bak" "$orig"
      if [[ "$zen_running" == false && -d "$prof/startupCache" ]]; then
        rm -rf "$prof/startupCache"
      fi
      echo "[REVERTED] $orig"
      restored=$((restored + 1))
    done
  done
done

BIN_DIR="$HOME/.local/bin"

if [[ -e "$BIN_DIR/kquicklook.rice.bak" ]]; then
  mv -f "$BIN_DIR/kquicklook.rice.bak" "$BIN_DIR/kquicklook"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user try-restart kquicklook-dolphin.service >/dev/null 2>&1 || true
  fi
  echo "[REVERTED] $BIN_DIR/kquicklook"
  restored=$((restored + 1))
fi

if [[ -e "$BIN_DIR/kzapret.rice.bak" ]]; then
  mv -f "$BIN_DIR/kzapret.rice.bak" "$BIN_DIR/kzapret"
  echo "[REVERTED] $BIN_DIR/kzapret"
  restored=$((restored + 1))
fi

if [[ "$restored" -eq 0 ]]; then
  echo "No .rice.bak backups found to revert."
else
  echo "Restored $restored file(s) from backup."
  if [[ "$zen_running" == true ]]; then
    echo "NOTE: If Zen Browser is open, restart it for changes to take effect."
  fi
fi
