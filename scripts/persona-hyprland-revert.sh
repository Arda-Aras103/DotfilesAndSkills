#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HYPR_DIR="$HOME/.config/hypr"
QS_DIR="$HOME/.config/quickshell"
PERSONA_DIR="$QS_DIR/persona"
HYPR_LUA="$HYPR_DIR/hyprland.lua"
PORTAL_DIR="$HOME/.config/xdg-desktop-portal"
CAVA_QML_DIR="$HOME/.local/lib/qt6/qml/CavaMonitor"
STATE_FILE="$HOME/.config/.persona-hyprland-state.json"
HYPR_THEMES_STATE_DIR="$HOME/.local/state/hypr-themes"
HYPR_REVERT_SANDBOX="${HYPR_REVERT_SANDBOX:-0}"

KEEP_PKGS=0
RESTORE_KDE=0
for arg in "$@"; do
  case "$arg" in
    --keep-pkgs) KEEP_PKGS=1 ;;
    --restore-kde) RESTORE_KDE=1 ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--keep-pkgs] [--restore-kde]"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

state_get() {
  local key="$1"
  local default="${2:-}"
  [[ -f "$STATE_FILE" ]] || { printf '%s\n' "$default"; return 0; }
  python3 - "$STATE_FILE" "$key" "$default" <<'PY'
import json
import sys

path, key, default = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(path, encoding="utf-8") as fh:
        val = json.load(fh).get(key, default)
except Exception:
    val = default
if isinstance(val, bool):
    print("1" if val else "0")
elif val is None:
    print(default)
else:
    print(val)
PY
}

rpm_was_present() {
  local pkg="$1"
  [[ -f "$STATE_FILE" ]] || return 1
  python3 - "$STATE_FILE" "$pkg" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
raise SystemExit(0 if sys.argv[2] in set(data.get("rpm_before", [])) else 1)
PY
}

echo "[1/4] Removing Persona-Quickshell, Hyprland themes/overlays, and user runtime configs..."
if [[ "$HYPR_REVERT_SANDBOX" != "1" ]]; then
  pkill -f "qs -c $QS_DIR/" >/dev/null 2>&1 || true
  pkill -f "qs -p $QS_DIR/" >/dev/null 2>&1 || true
fi

rm -rf \
  "$PERSONA_DIR" \
  "$QS_DIR/balatro" \
  "$QS_DIR/minflair" \
  "$QS_DIR/carpet" \
  "$QS_DIR/minecraft" \
  "$QS_DIR/desk" \
  "$QS_DIR/overlays"
if [[ -e "$PERSONA_DIR.persona.bak" ]]; then
  mv -f "$PERSONA_DIR.persona.bak" "$PERSONA_DIR"
fi

if [[ -f "$HYPR_LUA.persona.bak" ]]; then
  mv -f "$HYPR_LUA.persona.bak" "$HYPR_LUA"
  rm -f "$HYPR_LUA.rice.bak"
elif [[ -f "$HYPR_LUA.rice.bak" ]]; then
  if [[ -f "$STATE_FILE" && "$(state_get "had_hypr_lua" "0")" == "0" ]]; then
    rm -f "$HYPR_LUA" "$HYPR_LUA.rice.bak"
  else
    mv -f "$HYPR_LUA.rice.bak" "$HYPR_LUA"
  fi
else
  rm -f "$HYPR_LUA"
fi

rm -f "$HYPR_DIR/minflair-kitty.conf" "$HOME/.local/bin/activate-linux"
rm -rf "$HYPR_THEMES_STATE_DIR" "$HOME/.cache/quickshell" "$HOME/.cache/hyprland"

for pair in "kde-portals.conf:had_kde_portals" "hyprland-portals.conf:had_hypr_portals"; do
  f="${pair%%:*}"
  key="${pair#*:}"
  if [[ -f "$PORTAL_DIR/$f.persona.bak" ]]; then
    mv -f "$PORTAL_DIR/$f.persona.bak" "$PORTAL_DIR/$f"
    rm -f "$PORTAL_DIR/$f.rice.bak"
  elif [[ -f "$PORTAL_DIR/$f.rice.bak" ]]; then
    mv -f "$PORTAL_DIR/$f.rice.bak" "$PORTAL_DIR/$f"
  elif [[ "$(state_get "$key" "0")" == "0" ]]; then
    rm -f "$PORTAL_DIR/$f"
  fi
done

if [[ -d "$CAVA_QML_DIR" && "$(state_get "had_cava_qml" "0")" == "0" ]]; then
  rm -rf "$CAVA_QML_DIR"
fi

rmdir --ignore-fail-on-non-empty "$QS_DIR" "$HYPR_DIR" "$PORTAL_DIR" 2>/dev/null || true

echo "[2/4] Removing newly installed packages, COPR repos, and stale user units..."
if [[ "$KEEP_PKGS" -eq 0 && "$HYPR_REVERT_SANDBOX" != "1" ]]; then
  sudo -v
  HYPR_EXCLUSIVE=(
    hyprland
    hyprland-uwsm
    uwsm
    hyprland-guiutils
    hyprpicker
    hyprpaper
    hyprlock
    hypridle
    hyprcursor
    hyprpolkitagent
    hyprland-qt-support
    hyprland-qtutils
    aquamarine
    quickshell
    quickshell-git
    xdg-desktop-portal-hyprland
  )

  if [[ -f "$STATE_FILE" ]]; then
    CANDIDATES=(
      "${HYPR_EXCLUSIVE[@]}"
      wofi
      nwg-panel
      grim
      slurp
      wlr-randr
      qt6-qtmultimedia
      qt6-qtshadertools
      xdg-desktop-portal-gtk
      brightnessctl
      playerctl
      cmake
      gcc-c++
      qt6-qtbase-devel
      qt6-qtdeclarative-devel
      pipewire-devel
      fftw-devel
    )
  else
    CANDIDATES=("${HYPR_EXCLUSIVE[@]}")
  fi

  TO_REMOVE=()
  for pkg in "${CANDIDATES[@]}"; do
    rpm -q "$pkg" >/dev/null 2>&1 || continue
    if rpm_was_present "$pkg" 2>/dev/null; then
      continue
    fi
    TO_REMOVE+=("$pkg")
  done

  if (( ${#TO_REMOVE[@]} > 0 )); then
    sudo dnf remove -y "${TO_REMOVE[@]}"
    sudo dnf autoremove -y
  else
    echo "  -> No newly installed packages to remove."
  fi

  if [[ "$(state_get "had_copr_hyprland" "0")" == "0" ]]; then
    sudo dnf copr remove -y sdegler/hyprland >/dev/null 2>&1 || true
    for repo_file in /etc/yum.repos.d/_copr:*sdegler*hyprland*.repo; do
      [[ -f "$repo_file" ]] || continue
      sudo rm -f "$repo_file"
    done
  fi
  if [[ "$(state_get "had_copr_quickshell" "0")" == "0" ]]; then
    sudo dnf copr remove -y errornointernet/quickshell >/dev/null 2>&1 || true
    for repo_file in /etc/yum.repos.d/_copr:*errornointernet*quickshell*.repo; do
      [[ -f "$repo_file" ]] || continue
      sudo rm -f "$repo_file"
    done
  fi

  # Only unmask fumon.service once uwsm is confirmed absent so KDE isn't affected.
  if [[ -L "$HOME/.config/systemd/user/fumon.service" ]] && ! rpm -q uwsm >/dev/null 2>&1; then
    systemctl --user unmask fumon.service >/dev/null 2>&1 || rm -f "$HOME/.config/systemd/user/fumon.service"
  fi
elif [[ "$KEEP_PKGS" -eq 1 ]]; then
  echo "  -> --keep-pkgs specified; keeping installed packages and fumon.service mask intact."
else
  echo "  -> Sandbox mode; skipping package and systemd unit changes."
fi

if [[ "$HYPR_REVERT_SANDBOX" != "1" ]]; then
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  systemctl --user try-restart xdg-desktop-portal.service >/dev/null 2>&1 || true
fi

echo "[3/4] Optional KDE backup restore..."
if [[ "$RESTORE_KDE" -eq 1 ]]; then
  backup_dir="$(state_get "backup_dir" "")"
  if [[ -n "$backup_dir" && -f "$backup_dir/kde-configs.tar.gz" ]]; then
    tar -xzf "$backup_dir/kde-configs.tar.gz" -C "$HOME"
    echo "  -> Restored KDE/user configs from $backup_dir/kde-configs.tar.gz"
  else
    echo "  -> No backup tarball recorded in state file."
  fi
fi

echo "[4/4] Cleaning state file (backups in ~/Backups remain intact)..."
rm -f "$STATE_FILE"
echo "Revert complete. (Workspace source files in $REPO_ROOT/configs/hypr were kept intact.)"
