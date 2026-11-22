#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLOCK_SRC="$REPO_ROOT/configs/kde/cyber-clock-plasmoid"
APPLET_RC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

DO_CLOCK=1
DO_KURVE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-kurve) DO_KURVE=1; shift ;;
    --clock-only) DO_KURVE=0; shift ;;
    --kurve-only) DO_CLOCK=0; DO_KURVE=1; shift ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--with-kurve | --clock-only | --kurve-only]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -f "$APPLET_RC" && ! -f "$APPLET_RC.widgets.bak" ]]; then
  cp -f "$APPLET_RC" "$APPLET_RC.widgets.bak"
fi

KURVE_ID=""
if [[ "$DO_CLOCK" -eq 1 ]]; then
  echo "[1/3] Installing Cyber Typographic Clock plasmoid..."
  if kpackagetool6 --type Plasma/Applet --show org.kde.plasma.cyberclock >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --upgrade "$CLOCK_SRC"
  else
    kpackagetool6 --type Plasma/Applet --install "$CLOCK_SRC"
  fi
fi

if [[ "$DO_KURVE" -eq 1 ]]; then
  echo "[2/3] Installing Kurve audio visualizer dependencies & plasmoid..."
  sudo dnf install -y cava qt6-qtwebsockets-devel python-websockets
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  git clone --depth 1 https://github.com/luisbocanegra/kurve.git "$TMP_DIR/kurve"
  KURVE_META="$(find "$TMP_DIR/kurve" -maxdepth 3 -name metadata.json | head -n1)"
  [[ -n "$KURVE_META" ]] || { echo "Error: Kurve metadata.json not found in cloned repo." >&2; exit 1; }
  KURVE_PKG="$(dirname "$KURVE_META")"
  KURVE_ID="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get("KPlugin",{}).get("Id","luisbocanegra.audio.visualizer"))' "$KURVE_META")"
  echo "  -> Detected Kurve plugin ID: $KURVE_ID (from $KURVE_PKG)"
  if kpackagetool6 --type Plasma/Applet --show "$KURVE_ID" >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --upgrade "$KURVE_PKG"
  else
    kpackagetool6 --type Plasma/Applet --install "$KURVE_PKG"
  fi
fi

echo "[3/3] Placing widgets centered on active desktop(s) and restarting Plasma..."
systemctl --user restart plasma-plasmashell.service
for _ in $(seq 1 25); do
  if dbus-send --session --print-reply --dest=org.kde.plasmashell /PlasmaShell org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done
sleep 1

JS_SCRIPT="
var screenW = 1920;
desktops().forEach(function(d) {
  if (d.screen < 0) return;
  var g = screenGeometry(d.screen);
  if (g && g.width > 0) screenW = g.width;
  var hasClock = false;
  var hasKurve = false;
  d.widgets().forEach(function(w) {
    if (w.type === 'org.kde.plasma.cyberclock') hasClock = true;
    if ('$KURVE_ID' && w.type === '$KURVE_ID') hasKurve = true;
  });
  if ($DO_CLOCK === 1 && !hasClock) d.addWidget('org.kde.plasma.cyberclock');
  if ($DO_KURVE === 1 && '$KURVE_ID' && !hasKurve) d.addWidget('$KURVE_ID');
});
print(screenW);
"
SCREEN_W="$(dbus-send --session --print-reply --dest=org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "string:$JS_SCRIPT" | awk -F'"' '/string "/{print $2; exit}')"
SCREEN_W="${SCREEN_W:-1920}"
[[ "$SCREEN_W" =~ ^[0-9]+$ ]] || SCREEN_W=1920

# Stop plasmashell so it flushes new widget IDs to disk and doesn't overwrite our geometry edits
systemctl --user stop plasma-plasmashell.service
sleep 1

python3 - "$APPLET_RC" "$KURVE_ID" "$SCREEN_W" "$DO_CLOCK" "$DO_KURVE" <<'PY'
import configparser
import pathlib
import re
import sys

rc_path, kurve_id, sw_str, do_clock, do_kurve = sys.argv[1:6]
sw = int(sw_str)
p = pathlib.Path(rc_path)
if not p.exists():
    raise SystemExit(0)

cfg = configparser.ConfigParser(interpolation=None, strict=False)
cfg.optionxform = str
cfg.read(p, encoding="utf-8")

# Find desktop containments and their clock / kurve applet IDs
desktop_cids = []
for sec in cfg.sections():
    if sec.startswith("Containments][") and sec.count("][") == 1:
        plugin = cfg.get(sec, "plugin", fallback="")
        if plugin in ("org.kde.desktopcontainment", "org.kde.plasma.folder"):
            desktop_cids.append(sec.split("][", 1)[1])

clock_w, clock_h = 680, 220
kurve_w, kurve_h = 720, 240
clock_x = max(0, (sw - clock_w) // 2)
kurve_x = max(0, (sw - kurve_w) // 2)

for cid in desktop_cids:
    clock_ids = []
    kurve_ids = []
    prefix = f"Containments][{cid}][Applets]["
    for sec in cfg.sections():
        if sec.startswith(prefix) and sec[len(prefix):].count("][") == 0:
            aid = sec[len(prefix):]
            plug = cfg.get(sec, "plugin", fallback="")
            if plug == "org.kde.plasma.cyberclock":
                clock_ids.append(aid)
            elif kurve_id and plug == kurve_id:
                kurve_ids.append(aid)

    c_sec = f"Containments][{cid}"
    geom_keys = [k for k in cfg.options(c_sec) if k.startswith("ItemGeometries")]
    if not geom_keys:
        geom_keys = ["ItemGeometriesHorizontal"]

    for gk in geom_keys:
        raw = cfg.get(c_sec, gk, fallback="")
        entries = [e for e in raw.split(";") if e.strip()]
        filtered = []
        target_ids = set(clock_ids + kurve_ids)
        for e in entries:
            m = re.match(r"Applet-(\d+)=", e)
            if m and m.group(1) in target_ids:
                continue
            filtered.append(e)
        if do_clock == "1":
            for aid in clock_ids:
                filtered.append(f"Applet-{aid}={clock_x},48,{clock_w},{clock_h},0")
        if do_kurve == "1":
            for aid in kurve_ids:
                filtered.append(f"Applet-{aid}={kurve_x},278,{kurve_w},{kurve_h},0")
        cfg.set(c_sec, gk, ";".join(filtered) + (";" if filtered else ""))

with p.open("w", encoding="utf-8") as fh:
    cfg.write(fh, space_around_delimiters=False)
PY

systemctl --user start plasma-plasmashell.service

echo ""
echo "Desktop widgets installed (centered clock + Kurve audio visualizer)."
echo "Clean uninstall / revert:"
echo "  bash $SCRIPT_DIR/desktop-widgets-revert.sh --remove-pkgs"
