#!/usr/bin/env bash
set -euo pipefail

APPLET_RC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
HIDE_MODE="autohide"
if [[ "${1:-}" == "--dodge" ]]; then
  HIDE_MODE="dodgewindows"
fi

echo "[1/3] Backing up panel config..."
if [[ -f "$APPLET_RC" && ! -f "$APPLET_RC.dropdown.bak" ]]; then
  cp -f "$APPLET_RC" "$APPLET_RC.dropdown.bak"
fi

echo "[2/3] Switching top panel to centered island + top dropdown ($HIDE_MODE) mode..."
JS_SCRIPT="
var p = panels()[0];
if (p) {
  p.location = 'top';
  p.floating = true;
  p.height = 34;
  p.lengthMode = 'fit';
  p.alignment = 'center';
  p.hiding = '$HIDE_MODE';

  var toRemove = [];
  p.widgets().forEach(function(w) {
    if (w.type === 'org.kde.plasma.panelspacer') {
      toRemove.push(w);
    } else if (w.type === 'plasmusic-toolbar') {
      w.currentConfigGroup = ['General'];
      w.writeConfig('maxSongWidthInPanel', 240);
    }
  });
  toRemove.forEach(function(w) { w.remove(); });
}
"

dbus-send --session --type=method_call --dest=org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "string:$JS_SCRIPT"

echo "[3/3] Restarting Plasma Shell..."
systemctl --user restart plasma-plasmashell.service
echo "Done. (Top panel is now a centered compact island; move pointer to top edge to reveal.)"
echo "(Note: To keep panel visible on empty desktop and hide only for windows, run: $0 --dodge)"
