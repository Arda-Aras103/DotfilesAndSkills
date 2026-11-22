#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_FILE="$REPO_ROOT/reports/session-crash-diag.txt"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--out <path>] [-h|--help]

Read-only Fedora / KDE Plasma session-crash and Hyprland/Plymouth/SDDM diagnostic collector.
Default output: $REPO_ROOT/reports/session-crash-diag.txt
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      [[ $# -ge 2 ]] || { echo "Missing value for --out" >&2; exit 1; }
      OUT_FILE="$2"
      shift 2
      ;;
    --out=*)
      OUT_FILE="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

mkdir -p "$(dirname "$OUT_FILE")"

section() {
  printf '\n================================================================================\n'
  printf '## %s\n' "$1"
  printf '================================================================================\n'
}

run_ro() {
  local bin="$1"
  if ! command -v "$bin" >/dev/null 2>&1; then
    printf '[not available: %s]\n' "$bin"
    return 0
  fi
  "$@" 2>&1 || true
}

show_noncomment() {
  local path="$1"
  local max_lines="${2:-120}"
  printf -- '--- %s ---\n' "$path"
  if [[ -r "$path" ]]; then
    grep -vE '^[[:space:]]*(#|$)' "$path" 2>/dev/null | head -n "$max_lines" || true
  else
    printf '[missing or unreadable: %s]\n' "$path"
  fi
}

show_env_conf() {
  local path="$1"
  printf -- '--- %s ---\n' "$path"
  if [[ -r "$path" ]]; then
    sed -E 's/^([^#]*(TOKEN|KEY|SECRET|PASSWORD|PASSWD|COOKIE|AUTH|PRIVATE)[^=]*=).*/\1<REDACTED>/I' "$path" 2>/dev/null | head -n 60 || true
  else
    printf '[missing or unreadable: %s]\n' "$path"
  fi
}

show_dir() {
  local dir="$1"
  printf -- '--- ls -la %s ---\n' "$dir"
  if [[ -d "$dir" ]]; then
    ls -la "$dir" 2>&1 || true
  else
    printf '[absent]\n'
  fi
}

collect_report() {
  printf 'Session Crash & Desktop State Diagnostic Report\n'
  printf 'Generated: %s\n' "$(date -Is 2>/dev/null || date)"
  printf 'User: %s | UID: %s\n' "${USER:-$(id -un 2>/dev/null || echo unknown)}" "$(id -u 2>/dev/null || echo unknown)"

  section "1. OS, Session & Display Manager"
  if [[ -r /etc/os-release ]]; then
    grep -E '^(PRETTY_NAME|VERSION_ID)=' /etc/os-release 2>/dev/null || true
  else
    echo "[/etc/os-release unreadable]"
  fi
  printf 'Kernel: %s\n' "$(uname -r 2>/dev/null || echo unknown)"
  printf 'XDG_SESSION_TYPE=%s | XDG_CURRENT_DESKTOP=%s | DESKTOP_SESSION=%s\n' \
    "${XDG_SESSION_TYPE:-unset}" "${XDG_CURRENT_DESKTOP:-unset}" "${DESKTOP_SESSION:-unset}"
  if [[ -L /etc/systemd/system/display-manager.service || -e /etc/systemd/system/display-manager.service ]]; then
    printf 'display-manager.service -> %s\n' "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || echo unknown)"
  else
    echo "display-manager.service -> [absent]"
  fi
  if command -v systemctl >/dev/null 2>&1; then
    for svc in sddm.service plasmalogin.service; do
      printf '%s: enabled=%s active=%s\n' \
        "$svc" \
        "$(systemctl is-enabled "$svc" 2>/dev/null || true)" \
        "$(systemctl is-active "$svc" 2>/dev/null || true)"
    done
  else
    echo "[not available: systemctl]"
  fi
  echo "--- loginctl list-sessions ---"
  run_ro loginctl list-sessions --no-pager

  section "2. Core Dumps (Last 72h)"
  if command -v coredumpctl >/dev/null 2>&1; then
    local cd_out
    cd_out="$(coredumpctl list --since "72 hours ago" --no-pager 2>&1 || true)"
    printf '%s\n' "$cd_out"
    local latest_pid
    latest_pid="$(printf '%s\n' "$cd_out" | grep -E 'kwin_wayland|plasmashell|sddm|kscreenlocker|Xwayland|quickshell|\bqs\b|xdg-desktop-portal' | tail -n 1 | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+$/){print $i; break}}' || true)"
    if [[ -n "$latest_pid" ]]; then
      echo ""
      echo "--- coredumpctl info (PID $latest_pid, first 45 lines) ---"
      coredumpctl info "$latest_pid" --no-pager 2>&1 | head -n 45 || true
    fi
  else
    echo "[not available: coredumpctl]"
  fi

  section "3. User Session & KDE Service Logs"
  echo "--- systemctl --user --failed ---"
  run_ro systemctl --user --failed --no-pager
  echo "--- journalctl --user (current boot -b 0, warnings/errors, last 24h) ---"
  if command -v journalctl >/dev/null 2>&1; then
    journalctl --user -b 0 \
      -u plasma-kwin_wayland.service \
      -u plasma-plasmashell.service \
      -u plasma-ksmserver.service \
      -u plasma-powerdevil.service \
      -u 'xdg-desktop-portal*' \
      -u fumon.service \
      --since "24 hours ago" -p warning..emerg -n 80 --no-pager 2>&1 || true
    echo "--- journalctl --user (previous boot -b -1, errors) ---"
    journalctl --user -b -1 -p err..emerg -n 40 --no-pager 2>&1 || true
  else
    echo "[not available: journalctl]"
  fi

  section "4. System DM / Logind / OOMD / Kernel GPU & OOM Logs"
  if command -v journalctl >/dev/null 2>&1; then
    echo "--- DM / logind / oomd (-b 0, last 24h) ---"
    journalctl -b 0 -u sddm.service -u plasmalogin.service -u systemd-logind.service -u systemd-oomd.service \
      --since "24 hours ago" -n 80 --no-pager 2>&1 || true
    echo "--- Kernel OOM / GPU / DRM / segfault (-b 0) ---"
    journalctl -b 0 -k \
      --grep='oom|killed process|out of memory|amdgpu|i915|xe |nvidia|drm|gpu reset|ring .* timeout|segfault|traps:' \
      -n 60 --no-pager 2>&1 || true
    echo "--- DM / logind / oomd (previous boot -b -1) ---"
    journalctl -b -1 -u sddm.service -u plasmalogin.service -u systemd-logind.service -u systemd-oomd.service \
      -n 40 --no-pager 2>&1 || true
  else
    echo "[not available: journalctl]"
  fi

  section "5. Hyprland / Quickshell / UWSM / COPR / Portals / Plasmoids"
  echo "--- Matching RPMs ---"
  if command -v rpm >/dev/null 2>&1; then
    rpm -qa --qf '%{NAME}-%{VERSION}\n' 2>/dev/null | grep -iE 'hypr|quickshell|uwsm|aquamarine|sddm|plasma-login|cava|plymouth' | sort || true
  else
    echo "[not available: rpm]"
  fi
  echo "--- Enabled Hypr/Quickshell COPRs ---"
  if command -v dnf >/dev/null 2>&1; then
    dnf repolist --enabled 2>/dev/null | grep -iE 'copr|hypr|quickshell' || true
  else
    echo "[not available: dnf]"
  fi
  for d in \
    "$HOME/.config/hypr" \
    "$HOME/.config/quickshell" \
    "$HOME/.config/xdg-desktop-portal" \
    "$HOME/.config/environment.d" \
    "$HOME/.config/autostart" \
    "$HOME/.config/systemd/user" \
    "$HOME/.local/lib/qt6/qml" \
    "$HOME/.local/share/plasma/plasmoids" \
    "$HOME/.local/state/hypr-themes"; do
    show_dir "$d"
  done
  for f in "$HOME/.config/xdg-desktop-portal/"*.conf; do
    [[ -f "$f" ]] || continue
    show_noncomment "$f" 40
  done
  for f in "$HOME/.config/environment.d/"*.conf; do
    [[ -f "$f" ]] || continue
    show_env_conf "$f"
  done
  echo "--- Running processes (qs|hypr|uwsm|fumon|cava|kurve|kwin|plasmashell) ---"
  if command -v pgrep >/dev/null 2>&1; then
    pgrep -af 'qs|quickshell|hypr|uwsm|fumon|cava|kurve|kwin|plasmashell' 2>&1 || true
  else
    echo "[not available: pgrep]"
  fi

  section "6. Plymouth (SYSTEM // BOOTING) & SDDM State"
  if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    printf 'plymouth-set-default-theme: %s\n' "$(plymouth-set-default-theme 2>/dev/null || echo unknown)"
  else
    echo "[not available: plymouth-set-default-theme]"
  fi
  show_noncomment /etc/plymouth/plymouthd.conf 40
  show_noncomment /etc/plymouth/.cyber-tokyo-state 20
  echo "--- /etc/sddm.conf & /etc/sddm.conf.d ---"
  ls -la /etc/sddm.conf /etc/sddm.conf.d/ 2>&1 || true
  for f in /etc/sddm.conf.d/*.conf; do
    [[ -f "$f" ]] || continue
    printf -- '--- %s (head -n 30) ---\n' "$f"
    head -n 30 "$f" 2>&1 || true
  done

  section "7. Power / Idle / Lock / Backup State"
  show_noncomment /etc/systemd/logind.conf 60
  for f in /etc/systemd/logind.conf.d/*.conf; do
    [[ -f "$f" ]] || continue
    show_noncomment "$f" 60
  done
  for f in "$HOME/.config/kscreenlockerrc" "$HOME/.config/ksmserverrc" "$HOME/.config/powerdevilrc"; do
    show_noncomment "$f" 60
  done
  if [[ -f "$HOME/.local/state/organize-home-moves.tsv" ]]; then
    echo "organize-home-moves.tsv: PRESENT ($HOME/.local/state/organize-home-moves.tsv)"
  else
    echo "organize-home-moves.tsv: absent"
  fi
}

collect_report > "$OUT_FILE"

ACTIVE_DM="unavailable"
if [[ -L /etc/systemd/system/display-manager.service || -e /etc/systemd/system/display-manager.service ]]; then
  ACTIVE_DM="$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || echo unknown)")"
elif command -v systemctl >/dev/null 2>&1; then
  for svc in sddm.service plasmalogin.service; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      ACTIVE_DM="$svc"
      break
    fi
  done
fi

PLYMOUTH_THEME="unavailable"
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  PLYMOUTH_THEME="$(plymouth-set-default-theme 2>/dev/null || echo unknown)"
fi

FAILED_USER_UNITS="unavailable"
if command -v systemctl >/dev/null 2>&1; then
  FAILED_USER_UNITS="$(systemctl --user --failed --no-legend --plain 2>/dev/null | grep -c . || true)"
fi

RECENT_COREDUMPS="unavailable"
if command -v coredumpctl >/dev/null 2>&1; then
  RECENT_COREDUMPS="$(coredumpctl list --since "72 hours ago" --no-pager --no-legend 2>/dev/null | grep -c . || true)"
fi

HYPR_RPMS="unavailable"
if command -v rpm >/dev/null 2>&1; then
  HYPR_RPMS="$(rpm -qa --qf '%{NAME}\n' 2>/dev/null | grep -iEc '^(hypr|quickshell|uwsm|aquamarine)' || true)"
fi

echo "=== Session Crash Diagnostic Summary ==="
echo "Active DM:                   $ACTIVE_DM"
echo "Plymouth theme:              $PLYMOUTH_THEME"
echo "Failed user systemd units:   $FAILED_USER_UNITS"
echo "Core dumps (last 72h):       $RECENT_COREDUMPS"
echo "Hypr/Quickshell/UWSM RPMs:   $HYPR_RPMS"
echo "Saved full report:           $OUT_FILE"
