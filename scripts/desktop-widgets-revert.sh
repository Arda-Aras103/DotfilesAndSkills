#!/usr/bin/env bash
set -euo pipefail

REMOVE_PKGS=0
KURVE_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --remove-pkgs) REMOVE_PKGS=1; shift ;;
    --kurve-only) KURVE_ONLY=1; shift ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--kurve-only] [--remove-pkgs]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

echo "[1/3] Removing desktop widget(s) from Plasma desktop..."
if [[ "$KURVE_ONLY" -eq 1 ]]; then
  JS_REMOVE='
  desktops().forEach(function(d) {
    d.widgets().forEach(function(w) {
      if (w.type.indexOf("kurve") !== -1 || w.type.indexOf("audio.visualizer") !== -1) {
        w.remove();
      }
    });
  });
  '
else
  JS_REMOVE='
  desktops().forEach(function(d) {
    d.widgets().forEach(function(w) {
      if (w.type === "org.kde.plasma.cyberclock" || w.type.indexOf("kurve") !== -1 || w.type.indexOf("audio.visualizer") !== -1) {
        w.remove();
      }
    });
  });
  '
fi
dbus-send --session --type=method_call --dest=org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "string:$JS_REMOVE" >/dev/null 2>&1 || true

echo "[2/3] Uninstalling plasmoid package(s)..."
if [[ "$KURVE_ONLY" -eq 0 ]]; then
  kpackagetool6 --type Plasma/Applet --remove org.kde.plasma.cyberclock >/dev/null 2>&1 || true
fi
for id in luisbocanegra.audio.visualizer com.github.luisbocanegra.kurve org.kde.plasma.kurve; do
  kpackagetool6 --type Plasma/Applet --remove "$id" >/dev/null 2>&1 || true
done

if [[ "$REMOVE_PKGS" -eq 1 ]]; then
  echo "[3/3] Removing cava and websocket packages..."
  sudo dnf remove -y cava qt6-qtwebsockets-devel python-websockets || true
  sudo dnf autoremove -y || true
else
  echo "[3/3] Skipping dnf package removal (pass --remove-pkgs to remove cava)."
fi

systemctl --user restart plasma-plasmashell.service >/dev/null 2>&1 || true
echo "Desktop widgets reverted."
