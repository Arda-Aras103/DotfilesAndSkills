#!/usr/bin/env bash
set -euo pipefail

PRESET_DIR="$HOME/.config/panel-colorizer/presets/TokyoNight"

echo "[1/4] Checking Pager 'Desktop number' value..."
PAGER_NUM_VAL=$(python3 - <<'EOF'
import xml.etree.ElementTree as ET, os
p = "/usr/share/plasma/plasmoids/org.kde.plasma.pager/contents/config/main.xml"
val = 2
if os.path.exists(p):
    tree = ET.parse(p)
    for entry in tree.findall(".//{*}entry[@name='displayedText']"):
        choices = [c.attrib.get("name", "") for c in entry.findall(".//{*}choice")]
        for i, name in enumerate(choices):
            if "number" in name.lower():
                val = i
                break
print(val)
EOF
)

echo "[2/4] Preparing Panel Colorizer base preset..."
BASE_JSON=$(find "$HOME/.local/share/plasma/plasmoids/luisbocanegra.panel.colorizer" /usr/share/plasma/plasmoids/luisbocanegra.panel.colorizer -type f -name "settings.json" 2>/dev/null | grep -Ei 'island|pill|waybar|float|blur' | head -n1 || true)
if [[ -z "$BASE_JSON" ]]; then
  BASE_JSON=$(find "$HOME/.local/share/plasma/plasmoids/luisbocanegra.panel.colorizer" /usr/share/plasma/plasmoids/luisbocanegra.panel.colorizer -type f -name "settings.json" 2>/dev/null | head -n1 || true)
fi

if [[ -z "$BASE_JSON" ]]; then
  echo "Error: Panel Colorizer does not appear to be installed. Run ./scripts/panel-rice.sh first." >&2
  exit 1
fi

echo "  -> Base template: $(basename "$(dirname "$BASE_JSON")")"
mkdir -p "$PRESET_DIR"
cp -f "$BASE_JSON" "$PRESET_DIR/settings.json"

python3 - "$PRESET_DIR/settings.json" <<'EOF'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

def patch_section(obj, bg="#16161e", border="#414868", fg="#c0caf5"):
    if not isinstance(obj, dict):
        return
    if "nativePanelBackground" in obj and isinstance(obj["nativePanelBackground"], dict):
        obj["nativePanelBackground"]["enabled"] = False
        if "opacity" in obj["nativePanelBackground"]:
            obj["nativePanelBackground"]["opacity"] = 0

    for key in ("widgets", "panel"):
        sec = obj.get(key)
        if not isinstance(sec, dict):
            continue
        norm = sec.get("normal") if isinstance(sec.get("normal"), dict) else sec
        if not isinstance(norm, dict):
            continue
        if "enabled" in norm:
            norm["enabled"] = (key == "widgets")
        if "backgroundColor" in norm and isinstance(norm["backgroundColor"], dict):
            bc = norm["backgroundColor"]
            bc["enabled"] = (key == "widgets")
            if "alpha" in bc:
                bc["alpha"] = 0.92 if key == "widgets" else 0.0
            if "custom" in bc:
                bc["custom"] = bg
            if "sourceType" in bc:
                bc["sourceType"] = 1
        if "foregroundColor" in norm and isinstance(norm["foregroundColor"], dict):
            fc = norm["foregroundColor"]
            fc["enabled"] = (key == "widgets")
            if "alpha" in fc:
                fc["alpha"] = 1.0
            if "custom" in fc:
                fc["custom"] = fg
            if "sourceType" in fc:
                fc["sourceType"] = 1
        if "border" in norm and isinstance(norm["border"], dict):
            bd = norm["border"]
            bd["enabled"] = (key == "widgets")
            if "width" in bd:
                bd["width"] = 1
            if isinstance(bd.get("color"), dict):
                bd["color"]["enabled"] = True
                if "alpha" in bd["color"]:
                    bd["color"]["alpha"] = 0.9
                if "custom" in bd["color"]:
                    bd["color"]["custom"] = border
                if "sourceType" in bd["color"]:
                    bd["color"]["sourceType"] = 1
        if key == "widgets" and "radius" in norm and isinstance(norm["radius"], dict):
            norm["radius"]["enabled"] = True
            if "corner" in norm["radius"] and isinstance(norm["radius"]["corner"], dict):
                for c in norm["radius"]["corner"]:
                    norm["radius"]["corner"][c] = 10

if "globalSettings" in data and isinstance(data["globalSettings"], dict):
    patch_section(data["globalSettings"])
else:
    patch_section(data)

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
EOF

echo "[3/4] Enabling Panel Colorizer, exposing D-Bus, and numbering Pager..."
JS_SCRIPT="
var p = panels()[0];
if (p) {
  p.widgets().forEach(function(w) {
    if (w.type === 'org.kde.plasma.pager') {
      w.currentConfigGroup = ['General'];
      w.writeConfig('displayedText', $PAGER_NUM_VAL);
      w.writeConfig('showWindowIcons', false);
    }
    if (w.type === 'luisbocanegra.panel.colorizer') {
      w.currentConfigGroup = ['General'];
      w.writeConfig('isEnabled', true);
      w.writeConfig('hideWidget', true);
      w.writeConfig('enableDBusService', true);
    }
  });
}
"
dbus-send --session --type=method_call --dest=org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "string:$JS_SCRIPT"

systemctl --user restart plasma-plasmashell.service
for _ in $(seq 1 20); do
  if dbus-send --session --print-reply --dest=org.kde.plasmashell /PlasmaShell org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done
sleep 2

echo "[4/4] Applying Tokyo Night preset over D-Bus..."
dbus-send --session --type=signal /preset luisbocanegra.panel.colorizer.all.preset string:"$PRESET_DIR"
echo "Done. (If changes do not appear, open Panel Colorizer -> Configure -> Presets, select 'TokyoNight', and click Load.)"
