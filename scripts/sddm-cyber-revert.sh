#!/usr/bin/env bash
set -euo pipefail

THEME_DST="/usr/share/sddm/themes/cyber-wireframe"
SDDM_DROPIN_DIR="/etc/sddm.conf.d"
SDDM_CONF="$SDDM_DROPIN_DIR/cyber-wireframe.conf"
STATE_FILE="$SDDM_DROPIN_DIR/.cyber-wireframe-state"

REMOVE_SDDM=0
LOCK_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --remove-sddm)
      REMOVE_SDDM=1
      shift
      ;;
    --lock-only)
      LOCK_ONLY=1
      shift
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--remove-sddm] [--lock-only]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$LOCK_ONLY" -eq 0 ]]; then
echo "[1/3] Removing cyber-wireframe SDDM theme directory..."
if sudo test -d "$THEME_DST"; then
  sudo rm -rf "$THEME_DST"
fi

echo "[2/3] Restoring SDDM configuration backups..."
if sudo test -f "$SDDM_CONF.rice.bak"; then
  if sudo grep -qE '^[[:space:]]*Current=cyber-wireframe$' "$SDDM_CONF.rice.bak" 2>/dev/null; then
    sudo rm -f "$SDDM_CONF" "$SDDM_CONF.rice.bak"
  else
    sudo mv -f "$SDDM_CONF.rice.bak" "$SDDM_CONF"
  fi
elif sudo test -f "$SDDM_CONF"; then
  sudo rm -f "$SDDM_CONF"
fi

if sudo test -f /etc/sddm.conf.rice.bak; then
  sudo mv -f /etc/sddm.conf.rice.bak /etc/sddm.conf
fi

for bak in "$SDDM_DROPIN_DIR"/*.conf.rice.bak; do
  sudo test -f "$bak" || continue
  [[ "$bak" == "$SDDM_CONF.rice.bak" ]] && continue
  orig="${bak%.rice.bak}"
  sudo mv -f "$bak" "$orig"
done

echo "[3/3] Restoring previous display manager state (if recorded)..."
INSTALLED_SDDM=0
PREV_DM=""
if sudo test -f "$STATE_FILE"; then
  STATE_CONTENT="$(sudo cat "$STATE_FILE" 2>/dev/null || true)"
  INSTALLED_SDDM="$(printf '%s\n' "$STATE_CONTENT" | awk -F= '/^INSTALLED_SDDM=/{print $2; exit}')"
  PREV_DM="$(printf '%s\n' "$STATE_CONTENT" | awk -F= '/^PREV_DM=/{print $2; exit}')"
  INSTALLED_SDDM="${INSTALLED_SDDM:-0}"
fi

if [[ -n "$PREV_DM" && "$PREV_DM" != "sddm.service" ]]; then
  if command -v systemctl >/dev/null 2>&1; then
    echo "  -> Re-enabling previous display manager: $PREV_DM"
    sudo systemctl enable --force "$PREV_DM"
  fi
fi

if [[ "$INSTALLED_SDDM" == "1" || "$REMOVE_SDDM" -eq 1 ]]; then
  if [[ -z "$PREV_DM" || "$PREV_DM" == "sddm.service" ]] && command -v systemctl >/dev/null 2>&1; then
    if systemctl list-unit-files plasmalogin.service 2>/dev/null | grep -qE '^plasmalogin\.service'; then
      echo "  -> Re-enabling plasmalogin.service before removing SDDM..."
      sudo systemctl enable --force plasmalogin.service || true
    fi
  fi
  DM_TARGET=""
  if [[ -L /etc/systemd/system/display-manager.service || -e /etc/systemd/system/display-manager.service ]]; then
    DM_TARGET="$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)")"
  fi
  if [[ "$DM_TARGET" == "sddm.service" || -z "$DM_TARGET" ]]; then
    echo "  -> Warning: display-manager.service still points to '${DM_TARGET:-none}'; skipping SDDM package removal to keep a working display manager."
  else
    echo "  -> Removing SDDM packages (active display manager target: $DM_TARGET)..."
    TO_REMOVE=()
    for pkg in sddm sddm-kcm sddm-x11 sddm-wayland-plasma sddm-wayland-generic; do
      if rpm -q "$pkg" >/dev/null 2>&1; then
        TO_REMOVE+=("$pkg")
      fi
    done
    if (( ${#TO_REMOVE[@]} > 0 )); then
      sudo dnf remove -y "${TO_REMOVE[@]}"
      sudo dnf autoremove -y
    fi
  fi
fi

if sudo test -f "$STATE_FILE"; then
  sudo rm -f "$STATE_FILE"
fi

if command -v restorecon >/dev/null 2>&1; then
  sudo restorecon -R "$SDDM_DROPIN_DIR" /etc/sddm.conf >/dev/null 2>&1 || true
fi
fi

LOCK_RC="$HOME/.config/kscreenlockerrc"
ORGANIZED_LOCK_BAK="$HOME/.local/state/rice-backups/config/kscreenlockerrc.rice.bak"
if [[ -f "$LOCK_RC.rice.bak" ]]; then
  mv -f "$LOCK_RC.rice.bak" "$LOCK_RC"
  rm -f "$LOCK_RC.rice.created"
elif [[ -f "$ORGANIZED_LOCK_BAK" ]]; then
  mv -f "$ORGANIZED_LOCK_BAK" "$LOCK_RC"
  rm -f "$LOCK_RC.rice.created"
elif [[ -f "$LOCK_RC.rice.created" ]]; then
  rm -f "$LOCK_RC" "$LOCK_RC.rice.created"
elif [[ -f "$LOCK_RC" ]] && grep -q 'cyber-lockscreen\.' "$LOCK_RC" 2>/dev/null; then
  python3 - "$LOCK_RC" <<'PY'
import configparser
import pathlib
import sys

p = pathlib.Path(sys.argv[1])
cfg = configparser.ConfigParser(interpolation=None, strict=False)
cfg.optionxform = str
cfg.read(p, encoding="utf-8")
sec = "Greeter][Wallpaper][org.kde.image][General"
if cfg.has_section(sec):
    for key in ("Image", "PreviewImage"):
        if "cyber-lockscreen." in cfg.get(sec, key, fallback=""):
            cfg.remove_option(sec, key)
    if not cfg.options(sec):
        cfg.remove_section(sec)
with p.open("w", encoding="utf-8") as fh:
    cfg.write(fh, space_around_delimiters=False)
PY
fi
rm -f "$HOME/.local/share/wallpapers/cyber-lockscreen.svg" "$HOME/.local/share/wallpapers/cyber-lockscreen.png"

if [[ "$LOCK_ONLY" -eq 1 ]]; then
  echo "KDE lock screen reverted (display manager untouched)."
else
  echo "SDDM cyber-wireframe theme and KDE lock screen reverted."
fi
