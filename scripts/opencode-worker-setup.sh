#!/usr/bin/env bash
set -euo pipefail

BIN_PATH="$HOME/.local/bin/opencode"
CFG_SRC="/workspace/configs/opencode/opencode.json"
CFG_DST="$HOME/.config/opencode/opencode.json"
MCP_CFG="$HOME/.gemini/config/mcp_config.json"
WORKER_SCRIPT="/workspace/scripts/opencode_worker.py"

UPDATE_BINARY=false
if [[ "${1:-}" == "--update" ]]; then
  UPDATE_BINARY=true
fi

install_opencode_binary() {
  local raw_arch arch needs_baseline is_musl target meta version pkg_scope pkg_name pkg_base url tmp_dir tgz
  raw_arch="$(uname -m)"
  case "$raw_arch" in
    x86_64|amd64) arch="x64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      echo "[Error] Unsupported architecture: $raw_arch" >&2
      exit 1
      ;;
  esac

  needs_baseline=false
  if [[ "$arch" == "x64" ]] && ! grep -qwi avx2 /proc/cpuinfo 2>/dev/null; then
    needs_baseline=true
  fi

  is_musl=false
  if [[ -f /etc/alpine-release ]] || ldd --version 2>&1 | grep -qi musl; then
    is_musl=true
  fi

  target="linux-${arch}"
  if [[ "$needs_baseline" == true ]]; then
    target="${target}-baseline"
  fi
  if [[ "$is_musl" == true ]]; then
    target="${target}-musl"
  fi

  meta="$(curl -fsSL https://opencode.ai/update/api/latest/cli/npm)"
  read -r version pkg_scope pkg_base < <(
    python3 -c '
import json, sys
d = json.load(sys.stdin)
pkg = d["metadata"]["package"]
scope, name = pkg.split("/", 1)
print(d["version"], scope, name)
' <<< "$meta"
  )

  pkg_name="${pkg_scope}/${pkg_base}-${target}"
  url="https://registry.npmjs.org/${pkg_name}/-/${pkg_base}-${target}-${version}.tgz"

  mkdir -p "$(dirname "$BIN_PATH")"
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN
  tgz="$tmp_dir/opencode.tgz"
  curl -fsSL "$url" -o "$tgz"
  tar -xzf "$tgz" -C "$tmp_dir"
  install -m 0755 "$tmp_dir/package/bin/opencode" "$BIN_PATH"
  echo "[1/3] opencode v${version} (${target}) installed -> $BIN_PATH"
}

if [[ ! -x "$BIN_PATH" || "$UPDATE_BINARY" == true ]]; then
  install_opencode_binary
else
  echo "[1/3] opencode already installed ($("$BIN_PATH" --version 2>/dev/null || echo ok)) -> $BIN_PATH"
fi

echo "[2/3] Linking OpenCode v2 config -> $CFG_DST"
mkdir -p "$(dirname "$CFG_DST")"
if [[ -e "$CFG_DST" && ! -L "$CFG_DST" && ! -e "${CFG_DST}.opencode.bak" ]]; then
  cp -a "$CFG_DST" "${CFG_DST}.opencode.bak"
fi
ln -sfn "$CFG_SRC" "$CFG_DST"

echo "[3/3] Registering Antigravity MCP server -> $MCP_CFG"
mkdir -p "$(dirname "$MCP_CFG")"
if [[ -f "$MCP_CFG" && ! -f "${MCP_CFG}.opencode.bak" ]]; then
  cp -a "$MCP_CFG" "${MCP_CFG}.opencode.bak"
fi

python3 - "$MCP_CFG" "$WORKER_SCRIPT" <<'PY'
import json
import os
import sys

mcp_path, worker_script = sys.argv[1:3]
data = {}
if os.path.exists(mcp_path):
    with open(mcp_path, "r", encoding="utf-8") as f:
        data = json.load(f)

servers = data.setdefault("mcpServers", {})
servers["opencode-worker"] = {
    "command": "python3",
    "args": [worker_script, "mcp"],
}

with open(mcp_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY

echo "Setup complete. To verify: $BIN_PATH --standalone debug config >/dev/null && python3 $WORKER_SCRIPT models"
