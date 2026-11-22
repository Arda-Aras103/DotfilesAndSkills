#!/usr/bin/env bash
set -euo pipefail

REAL_HOME="$HOME"
THEME_HOME="${HYPR_THEME_HOME:-$HOME}"
IS_SANDBOX=0
if [[ "$THEME_HOME" != "$REAL_HOME" ]]; then
  IS_SANDBOX=1
fi

HYPR_DIR="${HYPR_CONFIG_HOME:-$THEME_HOME/.config/hypr}"
QS_DIR="$THEME_HOME/.config/quickshell"
STATE_DIR="$THEME_HOME/.local/state/hypr-themes"
HYPR_LUA="$HYPR_DIR/hyprland.lua"

INCLUDE_PERSONA=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --include-persona)
      INCLUDE_PERSONA=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--include-persona] [--dry-run]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] Would stop theme overlays and restore $HYPR_LUA"
  echo "[dry-run] Would remove $QS_DIR/{balatro,minflair,carpet,minecraft,desk,overlays}"
  [[ "$INCLUDE_PERSONA" -eq 1 ]] && echo "[dry-run] Would also remove $QS_DIR/persona"
  echo "[dry-run] Would remove $HYPR_DIR/minflair-kitty.conf and $STATE_DIR"
  exit 0
fi

if [[ "$IS_SANDBOX" -eq 0 ]]; then
  for p in balatro minflair carpet minecraft desk; do
    pkill -f "qs -c $QS_DIR/$p" >/dev/null 2>&1 || true
  done
  pkill -f "qs -p $QS_DIR/overlays/ActivateLinux.qml" >/dev/null 2>&1 || true
  pkill -f "qs -p $QS_DIR/overlays/CyberLock.qml" >/dev/null 2>&1 || true
  if [[ "$INCLUDE_PERSONA" -eq 1 ]]; then
    pkill -f "qs -c $QS_DIR/persona" >/dev/null 2>&1 || true
  fi
fi

if [[ -f "$HYPR_LUA.rice.bak" ]]; then
  mv -f "$HYPR_LUA.rice.bak" "$HYPR_LUA"
elif [[ -f "$STATE_DIR/managed-hypr-lua" ]]; then
  rm -f "$HYPR_LUA"
fi

rm -f "$HYPR_DIR/minflair-kitty.conf"
rm -rf "$QS_DIR/balatro" "$QS_DIR/minflair" "$QS_DIR/carpet" "$QS_DIR/minecraft" "$QS_DIR/desk" "$QS_DIR/overlays"
if [[ "$INCLUDE_PERSONA" -eq 1 ]]; then
  rm -rf "$QS_DIR/persona"
fi
rm -rf "$STATE_DIR"

rmdir --ignore-fail-on-non-empty "$QS_DIR" 2>/dev/null || true
rmdir --ignore-fail-on-non-empty "$HYPR_DIR" 2>/dev/null || true

echo "Hyprland themes and overlays reverted (KDE Plasma untouched)."
