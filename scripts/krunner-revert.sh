#!/usr/bin/env bash
set -euo pipefail

KRUNNER_RC="$HOME/.config/krunnerrc"

echo "[1/2] Restoring KRunner config..."
if [[ -f "$KRUNNER_RC.rice.bak" ]]; then
  mv -f "$KRUNNER_RC.rice.bak" "$KRUNNER_RC"
else
  rm -f "$KRUNNER_RC"
fi

echo "[2/2] Reloading KRunner..."
kquitapp6 krunner >/dev/null 2>&1 || pkill -x krunner >/dev/null 2>&1 || true
echo "KRunner settings reverted."
