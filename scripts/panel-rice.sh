#!/usr/bin/env bash
set -euo pipefail

APPLET_RC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

echo "[1/5] Backing up existing panel config..."
if [[ -f "$APPLET_RC" && ! -f "$APPLET_RC.rice.bak" ]]; then
  cp -f "$APPLET_RC" "$APPLET_RC.rice.bak"
fi

echo "[2/5] Ensuring 4 virtual desktops (1x4)..."
python3 - <<'EOF'
import configparser, os
p = os.path.expanduser("~/.config/kwinrc")
c = configparser.ConfigParser(interpolation=None, strict=False)
c.optionxform = str
if os.path.exists(p):
    c.read(p)
if not c.has_section("Desktops"):
    c.add_section("Desktops")
c.set("Desktops", "Number", "4")
c.set("Desktops", "Rows", "1")
with open(p, "w") as f:
    c.write(f, space_around_delimiters=False)
EOF
dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure

echo "[3/5] Installing/updating Panel Colorizer..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
git clone --depth 1 https://github.com/luisbocanegra/plasma-panel-colorizer.git "$TMP_DIR/plasma-panel-colorizer"
if kpackagetool6 --type Plasma/Applet --show luisbocanegra.panel.colorizer >/dev/null 2>&1; then
  kpackagetool6 --type Plasma/Applet --upgrade "$TMP_DIR/plasma-panel-colorizer/package" >/dev/null 2>&1 || true
else
  kpackagetool6 --type Plasma/Applet --install "$TMP_DIR/plasma-panel-colorizer/package"
fi

echo "[4/5] Restarting Plasma Shell..."
systemctl --user restart plasma-plasmashell.service
for _ in $(seq 1 20); do
  if dbus-send --session --print-reply --dest=org.kde.plasmashell /PlasmaShell org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

echo "[5/5] Configuring panel (left Pager, single-line 24h clock, hidden Colorizer icon)..."
JS_SCRIPT='
var p = panels()[0];
if (p) {
  p.location = "top";
  p.floating = true;
  p.height = 34;

  var pagerId = null;
  var hasColorizer = false;

  p.widgets().forEach(function(w) {
    if (w.type === "org.kde.plasma.pager") {
      pagerId = w.id;
      w.currentConfigGroup = ["General"];
      w.writeConfig("displayedText", 1);
      w.writeConfig("showWindowIcons", false);
    }
    if (w.type === "org.kde.plasma.digitalclock") {
      w.currentConfigGroup = ["Appearance"];
      w.writeConfig("showDate", false);
      w.writeConfig("use24hFormat", 2);
    }
    if (w.type === "luisbocanegra.panel.colorizer") {
      hasColorizer = true;
      w.currentConfigGroup = ["General"];
      w.writeConfig("hideWidget", true);
    }
  });

  if (pagerId === null) {
    var pager = p.addWidget("org.kde.plasma.pager");
    pagerId = pager.id;
    pager.currentConfigGroup = ["General"];
    pager.writeConfig("displayedText", 1);
    pager.writeConfig("showWindowIcons", false);
  }

  if (!hasColorizer) {
    var col = p.addWidget("luisbocanegra.panel.colorizer");
    col.currentConfigGroup = ["General"];
    col.writeConfig("hideWidget", true);
  }

  p.currentConfigGroup = ["General"];
  var orderStr = String(p.readConfig("AppletOrder") || "");
  var order = orderStr ? orderStr.split(";").filter(Boolean) : p.widgetIds.map(String);
  var pagerStr = String(pagerId);
  order = order.filter(function(id) { return id !== pagerStr; });
  order.splice(Math.min(1, order.length), 0, pagerStr);
  p.writeConfig("AppletOrder", order.join(";"));
}
'
dbus-send --session --type=method_call --dest=org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "string:$JS_SCRIPT"
systemctl --user restart plasma-plasmashell.service

echo "Done. (To select a Colorizer preset/pill style: Edit Mode -> Panel Colorizer -> Configure)"
