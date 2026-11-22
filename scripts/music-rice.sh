#!/usr/bin/env bash
set -euo pipefail

APPLET_RC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

echo "[1/4] Backing up panel config..."
if [[ -f "$APPLET_RC" && ! -f "$APPLET_RC.music.bak" ]]; then
  cp -f "$APPLET_RC" "$APPLET_RC.music.bak"
fi

echo "[2/4] Installing Plasmusic Toolbar..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
git clone --depth 1 https://github.com/ccatterina/plasmusic-toolbar.git "$TMP_DIR/plasmusic-toolbar"
if kpackagetool6 --type Plasma/Applet --show plasmusic-toolbar >/dev/null 2>&1; then
  kpackagetool6 --type Plasma/Applet --upgrade "$TMP_DIR/plasmusic-toolbar/src/"
else
  kpackagetool6 --type Plasma/Applet --install "$TMP_DIR/plasmusic-toolbar/src/"
fi

echo "[3/4] Restarting Plasma Shell..."
systemctl --user restart plasma-plasmashell.service
for _ in $(seq 1 20); do
  if dbus-send --session --print-reply --dest=org.kde.plasmashell /PlasmaShell org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

echo "[4/4] Adding Plasmusic Toolbar to top panel..."
JS_SCRIPT='
var p = panels()[0];
if (p) {
  var musicId = null;
  var trayId = null;
  p.widgets().forEach(function(w) {
    if (w.type === "plasmusic-toolbar") {
      musicId = w.id;
    }
    if (w.type === "org.kde.plasma.systemtray") {
      trayId = w.id;
      w.currentConfigGroup = ["General"];
      var hidden = String(w.readConfig("hiddenItems") || "").split(",").filter(Boolean);
      if (hidden.indexOf("org.kde.plasma.mediacontroller") === -1) {
        hidden.push("org.kde.plasma.mediacontroller");
      }
      w.writeConfig("hiddenItems", hidden.join(","));
      var shown = String(w.readConfig("shownItems") || "").split(",").filter(function(x) {
        return x && x !== "org.kde.plasma.mediacontroller";
      });
      w.writeConfig("shownItems", shown.join(","));
    }
  });
  if (musicId === null) {
    var m = p.addWidget("plasmusic-toolbar");
    musicId = m.id;
  }
  if (trayId !== null) {
    p.currentConfigGroup = ["General"];
    var orderStr = String(p.readConfig("AppletOrder") || "");
    var order = orderStr ? orderStr.split(";").filter(Boolean) : p.widgetIds.map(String);
    var mStr = String(musicId);
    var tStr = String(trayId);
    order = order.filter(function(id) { return id !== mStr; });
    var idx = order.indexOf(tStr);
    if (idx === -1) {
      order.push(mStr);
    } else {
      order.splice(idx, 0, mStr);
    }
    p.writeConfig("AppletOrder", order.join(";"));
  }
}
'
dbus-send --session --type=method_call --dest=org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "string:$JS_SCRIPT"
systemctl --user restart plasma-plasmashell.service

echo "Done. (Now playing track appears on the top bar; click to open compact player.)"
