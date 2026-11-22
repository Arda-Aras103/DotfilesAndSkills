#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_OC="/root/.opencode/bin/opencode"
CONTAINER_CFG_SRC="/workspace/configs/opencode/opencode.json"
CONTAINER_CFG_DST="/root/.config/opencode/opencode.json"

find_container() {
  local rt cand
  for rt in docker podman; do
    command -v "$rt" >/dev/null 2>&1 || continue
    while IFS= read -r cand; do
      [[ -n "$cand" ]] || continue
      if "$rt" exec "$cand" test -x "$CONTAINER_OC" >/dev/null 2>&1; then
        printf '%s %s\n' "$rt" "$cand"
        return 0
      fi
    done < <("$rt" ps --format '{{.Names}}' 2>/dev/null)
  done
  return 1
}

if [[ -f /.dockerenv ]]; then
  OC_BIN="$CONTAINER_OC"
  if [[ ! -x "$OC_BIN" ]]; then
    OC_BIN="$(command -v opencode || true)"
  fi
  [[ -n "$OC_BIN" ]] || { echo "Error: opencode CLI not found in container." >&2; exit 1; }
  ln -sfn "$OC_BIN" /usr/local/bin/opencode
  mkdir -p "$(dirname "$CONTAINER_CFG_DST")"
  ln -sfn "$CONTAINER_CFG_SRC" "$CONTAINER_CFG_DST"

  echo "[1/2] Logging into GitHub Copilot inside Docker container..."
  "$OC_BIN" auth login github-copilot

  echo "[2/2] Verifying available GitHub Copilot models..."
  "$OC_BIN" --standalone models 2>/dev/null | grep -i copilot || "$OC_BIN" auth list
else
  RT=""
  CNAME=""
  if read -r RT CNAME < <(find_container || true); then
    :
  fi
  if [[ -z "$RT" || -z "$CNAME" ]]; then
    echo "Error: Running Docker container with OpenCode ($CONTAINER_OC) not found." >&2
    echo "Start your Antigravity Docker container first and re-run this script." >&2
    exit 1
  fi

  echo "[1/3] Ensuring Docker OpenCode symlinks inside $CNAME ($RT)..."
  "$RT" exec "$CNAME" sh -c "ln -sfn '$CONTAINER_OC' /usr/local/bin/opencode && mkdir -p /root/.config/opencode && ln -sfn '$CONTAINER_CFG_SRC' '$CONTAINER_CFG_DST'"

  echo "[2/3] Launching GitHub Copilot OAuth Device Login inside Docker ($CNAME)..."
  "$RT" exec -it "$CNAME" "$CONTAINER_OC" auth login github-copilot

  echo "[3/3] Checking GitHub Copilot models inside Docker ($CNAME)..."
  "$RT" exec "$CNAME" "$CONTAINER_OC" --standalone models 2>/dev/null | grep -i copilot || "$RT" exec "$CNAME" "$CONTAINER_OC" auth list
fi

echo ""
echo "Clean logout / revert:"
echo "  bash $SCRIPT_DIR/copilot-subagent-revert.sh"
