#!/usr/bin/env bash
set -euo pipefail

SELF_PATH="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OVERLAY_SRC="$REPO_ROOT/configs/hypr/overlays/ActivateLinux.qml"

THEME_HOME="${HYPR_THEME_HOME:-$HOME}"
QS_OVERLAY_DIR="$THEME_HOME/.config/quickshell/overlays"
QS_OVERLAY="$QS_OVERLAY_DIR/ActivateLinux.qml"
STATE_FILE="$THEME_HOME/.local/state/hypr-themes/state.json"
CLI_BIN="$THEME_HOME/.local/bin/activate-linux"

ACTION="${1:-toggle}"

usage() {
  cat <<EOF
Usage: $(basename "$0") [toggle|on|off|status|--install-cli|--uninstall]

Manually control the "Activate Linux" watermark overlay:
  toggle         Toggle watermark overlay on/off (default)
  on             Start "Activate Linux" watermark overlay
  off            Stop "Activate Linux" watermark overlay
  status         Show current overlay state
  --install-cli  Install ~/.local/bin/activate-linux symlink
  --uninstall    Stop overlay and remove CLI symlink + staged QML
  -h, --help     Show this help message
EOF
}

is_running() {
  pgrep -f "qs -p $QS_OVERLAY" >/dev/null 2>&1
}

sync_state_json() {
  local enabled="$1"
  [[ -f "$STATE_FILE" ]] || return 0
  python3 - "$STATE_FILE" "$enabled" <<'PY'
import json
import pathlib
import sys

p = pathlib.Path(sys.argv[1])
enabled = (sys.argv[2] == "true")
try:
    data = json.loads(p.read_text(encoding="utf-8"))
except Exception:
    return
if isinstance(data, dict):
    data["activate_linux"] = enabled
    p.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
}

read_state_flag() {
  [[ -f "$STATE_FILE" ]] || { echo "unset"; return 0; }
  python3 - "$STATE_FILE" <<'PY'
import json
import pathlib
import sys

try:
    data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
    print("on" if data.get("activate_linux") else "off")
except Exception:
    print("unset")
PY
}

stop_overlay() {
  pkill -f "qs -p $QS_OVERLAY" >/dev/null 2>&1 || true
  sync_state_json "false"
}

start_overlay() {
  [[ -f "$OVERLAY_SRC" ]] || { echo "Missing overlay QML: $OVERLAY_SRC" >&2; exit 1; }
  command -v qs >/dev/null 2>&1 || {
    echo "Error: quickshell ('qs') not found in PATH." >&2
    exit 1
  }
  mkdir -p "$QS_OVERLAY_DIR"
  cp -f "$OVERLAY_SRC" "$QS_OVERLAY"
  pkill -f "qs -p $QS_OVERLAY" >/dev/null 2>&1 || true
  nohup qs -p "$QS_OVERLAY" >/dev/null 2>&1 &
  sync_state_json "true"
}

case "$ACTION" in
  -h|--help)
    usage
    exit 0
    ;;
  status)
    live="off"
    is_running && live="on"
    echo "running=$live"
    echo "state_file=$(read_state_flag)"
    echo "cli_installed=$([[ -L "$CLI_BIN" || -f "$CLI_BIN" ]] && echo yes || echo no)"
    ;;
  on)
    start_overlay
    echo "Activate Linux: on"
    ;;
  off)
    stop_overlay
    echo "Activate Linux: off"
    ;;
  toggle)
    if is_running; then
      stop_overlay
      echo "Activate Linux: off"
    else
      start_overlay
      echo "Activate Linux: on"
    fi
    ;;
  --install-cli)
    mkdir -p "$(dirname "$CLI_BIN")"
    ln -sfn "$SELF_PATH" "$CLI_BIN"
    echo "Installed CLI shortcut: $CLI_BIN -> $SELF_PATH"
    echo "You can now run: activate-linux | activate-linux on | activate-linux off"
    ;;
  --uninstall)
    stop_overlay
    rm -f "$CLI_BIN"
    rm -f "$QS_OVERLAY"
    rmdir --ignore-fail-on-non-empty "$QS_OVERLAY_DIR" 2>/dev/null || true
    echo "Activate Linux overlay stopped and uninstalled cleanly."
    ;;
  *)
    echo "Unknown option: $ACTION" >&2
    usage >&2
    exit 1
    ;;
esac
