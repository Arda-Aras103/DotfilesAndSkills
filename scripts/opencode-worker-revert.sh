#!/usr/bin/env bash
set -euo pipefail

BIN_PATH="$HOME/.local/bin/opencode"
CFG_DST="$HOME/.config/opencode/opencode.json"
MCP_CFG="$HOME/.gemini/config/mcp_config.json"

echo "[1/3] Stopping running opencode background service..."
if command -v opencode >/dev/null 2>&1; then
  opencode service stop >/dev/null 2>&1 || true
elif [[ -x "$BIN_PATH" ]]; then
  "$BIN_PATH" service stop >/dev/null 2>&1 || true
fi

echo "[2/3] Cleaning up Antigravity MCP registration..."
if [[ -f "$MCP_CFG" ]]; then
  python3 - "$MCP_CFG" <<'PY'
import json
import sys

mcp_path = sys.argv[1]
with open(mcp_path, "r", encoding="utf-8") as f:
    data = json.load(f)

servers = data.get("mcpServers")
if isinstance(servers, dict):
    servers.pop("opencode-worker", None)

with open(mcp_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
fi

echo "[3/3] Removing OpenCode binary, config, and caches..."
if [[ -L "$CFG_DST" ]]; then
  rm -f "$CFG_DST"
fi
if [[ -e "${CFG_DST}.opencode.bak" ]]; then
  mv -f "${CFG_DST}.opencode.bak" "$CFG_DST"
else
  rm -rf "$HOME/.config/opencode"
fi

rm -f "$BIN_PATH"
rm -rf \
  "$HOME/.opencode" \
  "$HOME/.local/share/opencode" \
  "$HOME/.cache/opencode" \
  "$HOME/.local/state/opencode"

echo "OpenCode worker installation completely removed."
