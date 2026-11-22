#!/usr/bin/env bash
set -euo pipefail

ZED_CFG="$HOME/.config/zed/settings.json"

echo "[1/1] Restoring Zed settings..."
if [[ -f "$ZED_CFG.rice.bak" ]]; then
  mv -f "$ZED_CFG.rice.bak" "$ZED_CFG"
else
  rm -f "$ZED_CFG"
fi

echo "Zed settings reverted."
