#!/usr/bin/env bash
set -euo pipefail

CONTAINER_OC="/root/.opencode/bin/opencode"

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
  echo "[1/1] Logging out github-copilot inside Docker container..."
  if [[ -x "$CONTAINER_OC" ]]; then
    "$CONTAINER_OC" auth logout github-copilot >/dev/null 2>&1 || true
  elif command -v opencode >/dev/null 2>&1; then
    opencode auth logout github-copilot >/dev/null 2>&1 || true
  fi
else
  RT=""
  CNAME=""
  if read -r RT CNAME < <(find_container || true); then
    echo "[1/1] Logging out github-copilot inside Docker container: $CNAME ($RT)..."
    "$RT" exec "$CNAME" "$CONTAINER_OC" auth logout github-copilot >/dev/null 2>&1 || true
  else
    echo "No running Docker container with OpenCode found; nothing to remove on host."
  fi
fi

echo "GitHub Copilot subagent credentials removed from Docker."
