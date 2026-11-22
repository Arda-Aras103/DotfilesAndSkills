#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LUA_TEMPLATE="$REPO_ROOT/configs/hypr/persona-hyprland.lua"

PERSONA_DIR="$HOME/.config/quickshell/persona"
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"
PORTAL_DIR="$HOME/.config/xdg-desktop-portal"
CAVA_QML_DIR="$HOME/.local/lib/qt6/qml/CavaMonitor"
STATE_FILE="$HOME/.config/.persona-hyprland-state.json"

PERSONA_REPO="https://github.com/Yujonpradhananga/Persona-Quickshell.git"
CAVA_REPO="https://github.com/Yujonpradhananga/Qt6-Cava-plugin.git"
QUICKSHELL_PKG="${PERSONA_QUICKSHELL_PKG:-quickshell}"

WITH_CAVA=0
WITH_PORTALS=0
for arg in "$@"; do
  case "$arg" in
    --with-cava) WITH_CAVA=1 ;;
    --with-portals) WITH_PORTALS=1 ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--with-cava] [--with-portals]"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

[[ -f "$LUA_TEMPLATE" ]] || { echo "Missing template: $LUA_TEMPLATE" >&2; exit 1; }

sudo -v

if [[ ! -f "$STATE_FILE" ]]; then
  TS="$(date +%Y%m%d-%H%M%S)"
  BACKUP_DIR="$HOME/Backups/persona-hyprland-$TS"
  mkdir -p "$BACKUP_DIR"

  echo "[1/5] Backing up system package state, Btrfs snapshot (if snapper), and KDE/user configs..."
  if command -v snapper >/dev/null 2>&1; then
    sudo snapper create --description "pre-persona-hyprland-$TS" >/dev/null 2>&1 \
      && echo "  -> Snapper Btrfs snapshot created." \
      || echo "  -> Snapper present but no root snapshot created (continuing)."
  fi

  rpm -qa --qf '%{NAME}\n' | sort -u > "$BACKUP_DIR/rpm-names-before.txt"
  rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort > "$BACKUP_DIR/rpm-full-before.txt"
  dnf repolist --enabled 2>/dev/null > "$BACKUP_DIR/repos-enabled-before.txt" || true

  (
    cd "$HOME"
    ITEMS=()
    for p in \
      .config/kdeglobals \
      .config/kwinrc \
      .config/kglobalshortcutsrc \
      .config/kscreenlockerrc \
      .config/kxkbrc \
      .config/plasmashellrc \
      .config/plasma-org.kde.plasma.desktop-appletsrc \
      .config/konsolerc \
      .config/environment.d \
      .config/gtk-3.0 \
      .config/gtk-4.0 \
      .config/kitty \
      .config/xdg-desktop-portal \
      .config/hypr \
      .config/quickshell \
      .bashrc; do
      [[ -e "$p" ]] && ITEMS+=("$p")
    done
    if (( ${#ITEMS[@]} > 0 )); then
      tar -czf "$BACKUP_DIR/kde-configs.tar.gz" "${ITEMS[@]}"
    fi
  )
  echo "  -> Backup saved at: $BACKUP_DIR"

  mkdir -p "$(dirname "$STATE_FILE")"
  python3 - "$STATE_FILE" "$BACKUP_DIR" <<'PY'
import json
import os
import pathlib
import sys

state_path, backup_dir = sys.argv[1], sys.argv[2]
repos = (pathlib.Path(backup_dir) / "repos-enabled-before.txt").read_text(encoding="utf-8")
rpms = set((pathlib.Path(backup_dir) / "rpm-names-before.txt").read_text(encoding="utf-8").splitlines())

def exists(rel):
    return os.path.exists(os.path.expanduser(rel))

state = {
    "backup_dir": backup_dir,
    "had_copr_hyprland": ("sdegler" in repos and "hyprland" in repos),
    "had_copr_quickshell": ("errornointernet" in repos and "quickshell" in repos),
    "rpm_before": sorted(rpms),
    "had_hypr_lua": exists("~/.config/hypr/hyprland.lua"),
    "had_persona_dir": exists("~/.config/quickshell/persona"),
    "had_kde_portals": exists("~/.config/xdg-desktop-portal/kde-portals.conf"),
    "had_hypr_portals": exists("~/.config/xdg-desktop-portal/hyprland-portals.conf"),
    "had_cava_qml": exists("~/.local/lib/qt6/qml/CavaMonitor"),
}
pathlib.Path(state_path).write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
PY
else
  echo "[1/5] Baseline backup already exists ($STATE_FILE); skipping duplicate backup."
fi

echo "[2/5] Enabling COPRs and installing Hyprland + Quickshell packages..."
sudo dnf copr enable -y sdegler/hyprland
sudo dnf copr enable -y errornointernet/quickshell

PKGS=(
  hyprland
  "$QUICKSHELL_PKG"
  qt6-qtmultimedia
  qt6-qtshadertools
  brightnessctl
  playerctl
)
if [[ "$WITH_PORTALS" -eq 1 ]]; then
  PKGS+=(xdg-desktop-portal-hyprland xdg-desktop-portal-gtk)
fi
if [[ "$WITH_CAVA" -eq 1 ]]; then
  PKGS+=(cmake gcc-c++ qt6-qtbase-devel qt6-qtdeclarative-devel pipewire-devel fftw-devel)
fi

if ! sudo dnf install -y --exclude=hyprland-uwsm,uwsm "${PKGS[@]}"; then
  echo ""
  echo "[ERROR] Package installation failed (if Qt_6.1x_PRIVATE_API mismatch occurred, retry with:"
  echo "  PERSONA_QUICKSHELL_PKG=quickshell-git bash $SCRIPT_DIR/persona-hyprland-setup.sh"
  echo "or revert everything with:"
  echo "  bash $SCRIPT_DIR/persona-hyprland-revert.sh)"
  exit 1
fi

# Stop/mask uwsm's FUMonitor if uwsm got pulled in earlier so KDE isn't spammed.
if systemctl --user is-active --quiet fumon.service 2>/dev/null || [[ -e /etc/systemd/user/graphical-session.target.wants/fumon.service ]]; then
  systemctl --user mask --now fumon.service >/dev/null 2>&1 || true
fi

echo "[3/5] Installing Persona-Quickshell into $PERSONA_DIR..."
mkdir -p "$(dirname "$PERSONA_DIR")"
if [[ -d "$PERSONA_DIR/.git" ]]; then
  git -C "$PERSONA_DIR" checkout -- Widgets/ Layers/ >/dev/null 2>&1 || true
  git -C "$PERSONA_DIR" pull --ff-only
else
  if [[ -e "$PERSONA_DIR" && ! -e "$PERSONA_DIR.persona.bak" ]]; then
    mv -f "$PERSONA_DIR" "$PERSONA_DIR.persona.bak"
  fi
  git clone --depth 1 "$PERSONA_REPO" "$PERSONA_DIR"
fi

if [[ "$WITH_CAVA" -eq 1 ]]; then
  echo "  -> Building Qt6-Cava-plugin into $CAVA_QML_DIR..."
  TMP_BUILD="$(mktemp -d)"
  trap 'rm -rf "$TMP_BUILD"' EXIT
  git clone --depth 1 "$CAVA_REPO" "$TMP_BUILD/Qt6-Cava-plugin"
  cmake -S "$TMP_BUILD/Qt6-Cava-plugin" -B "$TMP_BUILD/build" -DCMAKE_INSTALL_PREFIX="$HOME/.local/lib/qt6/qml"
  cmake --build "$TMP_BUILD/build" -j"$(nproc)"
  cmake --install "$TMP_BUILD/build"
else
  echo "  -> Disabling optional CavaVisualizer per upstream README..."
  rm -f "$PERSONA_DIR/Widgets/CavaVisualizer.qml"
  python3 - "$PERSONA_DIR/Widgets/WallpaperEngine.qml" <<'PY'
import pathlib
import re
import sys

p = pathlib.Path(sys.argv[1])
src = p.read_text(encoding="utf-8")
updated = re.sub(r"\n\s*CavaVisualizer\s*\{[^{}]*\{[^}]*\}[^{}]*\}", "", src, count=1)
if updated == src:
    raise SystemExit("Failed to strip CavaVisualizer block from WallpaperEngine.qml")
p.write_text(updated, encoding="utf-8")
PY
fi

echo "  -> Patching upstream QML bugs (missing fonts, AppDrawer slide, Calendar/Options QML errors)..."
python3 - "$PERSONA_DIR" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])

def patch_file(rel, fn):
    p = root / rel
    if p.exists():
        p.write_text(fn(p.read_text(encoding="utf-8")), encoding="utf-8")

# 1. Capsule.qml: replace Material Symbols ligatures with JetBrainsMono Nerd Font glyphs
def fix_capsule(s):
    s = s.replace('text: "skip_previous"', 'text: "󰒮"')
    s = s.replace('text: "skip_next"', 'text: "󰒭"')
    s = s.replace('font.family: "Material Symbols Rounded"', 'font.family: "JetBrainsMono Nerd Font"')
    s = s.replace('font.pixelSize: 30', 'font.pixelSize: 22')
    return s
patch_file("Layers/Capsule.qml", fix_capsule)

# 2. AppDrawer.qml: keep :3 circle on-screen while drawer blades are expanded
patch_file(
    "Layers/AppDrawer.qml",
    lambda s: s.replace(
        "property real ballX: toolskiRoot.isHovered ? 10 : -150",
        "property real ballX: (toolskiRoot.isHovered || toolskiRoot.isExpanded) ? 10 : -150",
    ),
)

# 3. Options.qml & OptionsList.qml: avoid missing repo TTF FontLoaders and undefined bebasNeue
patch_file(
    "Layers/Options.qml",
    lambda s: s.replace("font.family: bebasNeue.name", 'font.family: "sans-serif"'),
)
def fix_options_list(s):
    s = re.sub(r"\n\s*FontLoader\s*\{[^{}]*BebasNeue-Regular\.ttf[^}]*\}", "", s)
    s = re.sub(r"\n\s*FontLoader\s*\{[^{}]*Montserrat-Light\.ttf[^}]*\}", "", s)
    s = s.replace("font.family: bebasNeue.name", 'font.family: "sans-serif"')
    s = s.replace("font.family: montserrat.name", 'font.family: "sans-serif"')
    return s
patch_file("Layers/OptionsList.qml", fix_options_list)

# 4. Calendar.qml: fix Rotation parent ReferenceError and invalid QQuickAnchorLine arithmetic
def fix_calendar(s):
    s = s.replace(
        '                Rectangle {\n                    width: parent.width * 2\n                    height: parent.height * 0.2\n                    x: -parent.width * 0.2\n                    y: parent.height * -0.1\n                    color: "#1a4fa8"\n                    transform: Rotation {\n                        origin.x: parent.width / 2\n                        origin.y: parent.height / 2',
        '                Rectangle {\n                    id: blueBand\n                    width: parent.width * 2\n                    height: parent.height * 0.2\n                    x: -parent.width * 0.2\n                    y: parent.height * -0.1\n                    color: "#1a4fa8"\n                    transform: Rotation {\n                        origin.x: blueBand.width / 2\n                        origin.y: blueBand.height / 2',
    )
    s = s.replace(
        '                Rectangle {\n                    width: parent.width * 200\n                    height: 5\n                    x: -parent.width * 0.2\n                    y: parent.height * 0.99\n                    color: "white"\n                    transform: Rotation {\n                        origin.x: parent.width / 2\n                        origin.y: parent.height / 2',
        '                Rectangle {\n                    id: whiteLine\n                    width: parent.width * 200\n                    height: 5\n                    x: -parent.width * 0.2\n                    y: parent.height * 0.99\n                    color: "white"\n                    transform: Rotation {\n                        origin.x: whiteLine.width / 2\n                        origin.y: whiteLine.height / 2',
    )
    s = s.replace(
        "            anchors.left: parent.left - 109\n            anchors.verticalCenter: parent.verticalCenter * -10",
        "            anchors.left: parent.left\n            anchors.leftMargin: -109\n            anchors.verticalCenter: parent.verticalCenter\n            anchors.verticalCenterOffset: -10",
    )
    return s
patch_file("Layers/Calendar.qml", fix_calendar)
PY

echo "[4/5] Writing isolated Hyprland Lua config ($HYPR_LUA)..."
mkdir -p "$(dirname "$HYPR_LUA")"
if [[ -f "$HYPR_LUA" && ! -f "$HYPR_LUA.persona.bak" ]]; then
  cp -f "$HYPR_LUA" "$HYPR_LUA.persona.bak"
fi

KB_LAYOUT="$(python3 - <<'PY'
import configparser
import os

kxkb = os.path.expanduser("~/.config/kxkbrc")
if os.path.exists(kxkb):
    cfg = configparser.ConfigParser(interpolation=None, strict=False)
    cfg.optionxform = str
    cfg.read(kxkb, encoding="utf-8")
    raw = cfg.get("Layout", "LayoutList", fallback="")
    layouts = ",".join(part.strip() for part in raw.split(",") if part.strip())
    if layouts:
        print(layouts)
        raise SystemExit(0)
print("us")
PY
)"

python3 - "$LUA_TEMPLATE" "$HYPR_LUA" "$KB_LAYOUT" <<'PY'
import pathlib
import sys

src, dst, kb = sys.argv[1], sys.argv[2], sys.argv[3]
text = pathlib.Path(src).read_text(encoding="utf-8").replace("__KB_LAYOUT__", kb)
pathlib.Path(dst).write_text(text, encoding="utf-8")
PY

if [[ "$WITH_PORTALS" -eq 1 ]]; then
  echo "  -> Writing per-desktop portal routing to prevent KDE/Hyprland clashes..."
  mkdir -p "$PORTAL_DIR"
  for f in kde-portals.conf hyprland-portals.conf; do
    if [[ -f "$PORTAL_DIR/$f" && ! -f "$PORTAL_DIR/$f.persona.bak" ]]; then
      cp -f "$PORTAL_DIR/$f" "$PORTAL_DIR/$f.persona.bak"
    fi
  done
  printf '[preferred]\ndefault=kde\n' > "$PORTAL_DIR/kde-portals.conf"
  printf '[preferred]\ndefault=hyprland;gtk\norg.freedesktop.impl.portal.FileChooser=kde\n' > "$PORTAL_DIR/hyprland-portals.conf"
fi

echo "[5/5] Setup complete. KDE Plasma files were not modified."
echo ""
echo "Test inside KDE first (windowed):  Hyprland --verify-config && Hyprland"
echo "Or switch at SDDM login screen:    Select 'Hyprland' (Super+R: Launcher, Super+Enter: Kitty, Super+M: Exit)"
echo "Full clean uninstall/revert:       bash $SCRIPT_DIR/persona-hyprland-revert.sh"
