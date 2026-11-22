#!/usr/bin/env bash
set -euo pipefail

echo "[1/3] Backing up window rules and adding 'No Titlebar' rule..."
KWIN_RULES="$HOME/.config/kwinrulesrc"
if [[ -f "$KWIN_RULES" && ! -f "$KWIN_RULES.rice.bak" ]]; then
  cp -f "$KWIN_RULES" "$KWIN_RULES.rice.bak"
fi

python3 - <<'EOF'
import configparser, os, uuid

path = os.path.expanduser("~/.config/kwinrulesrc")
cfg = configparser.ConfigParser(interpolation=None, strict=False)
cfg.optionxform = str
if os.path.exists(path):
    cfg.read(path)

rule_id = None
for sec in cfg.sections():
    if sec != "General" and cfg.get(sec, "Description", fallback="") == "Rice: No Titlebar":
        rule_id = sec
        break

if rule_id is None:
    rule_id = str(uuid.uuid4())

if not cfg.has_section(rule_id):
    cfg.add_section(rule_id)

cfg.set(rule_id, "Description", "Rice: No Titlebar")
cfg.set(rule_id, "types", "1")
cfg.set(rule_id, "wmclassmatch", "0")
cfg.set(rule_id, "wmclasscomplete", "false")

if not cfg.has_section("General"):
    cfg.add_section("General")

if cfg.has_option("General", "Order") or not cfg.has_option("General", "rules"):
    existing = [r for r in cfg.get("General", "Order", fallback="").split(",") if r]
    if rule_id not in existing:
        existing.append(rule_id)
    cfg.set("General", "Order", ",".join(existing))
    cfg.set(rule_id, "decorationpolicy", "none")
    cfg.set(rule_id, "decorationpolicyrule", "2")
else:
    existing = [r for r in cfg.get("General", "rules", fallback="").split(",") if r]
    if rule_id not in existing:
        existing.append(rule_id)
    cfg.set("General", "rules", ",".join(existing))
    cfg.set("General", "count", str(len(existing)))
    cfg.set(rule_id, "noborder", "true")
    cfg.set(rule_id, "noborderrule", "2")

with open(path, "w", encoding="utf-8") as f:
    cfg.write(f, space_around_delimiters=False)
EOF

echo "[2/3] Simplifying Dolphin menu bar..."
pkill -x dolphin 2>/dev/null || true
sleep 0.5
rm -f "$HOME/.config/session/dolphin_"* 2>/dev/null || true

DOLPHIN_RC="$HOME/.config/dolphinrc"
if [[ -f "$DOLPHIN_RC" && ! -f "$DOLPHIN_RC.rice.bak" ]]; then
  cp -f "$DOLPHIN_RC" "$DOLPHIN_RC.rice.bak"
fi

python3 - <<'EOF'
import configparser, os
path = os.path.expanduser("~/.config/dolphinrc")
cfg = configparser.ConfigParser(interpolation=None, strict=False)
cfg.optionxform = str
if os.path.exists(path):
    cfg.read(path)
if not cfg.has_section("MainWindow"):
    cfg.add_section("MainWindow")
cfg.set("MainWindow", "MenuBar", "Disabled")
with open(path, "w", encoding="utf-8") as f:
    cfg.write(f, space_around_delimiters=False)
EOF

echo "[3/3] Reloading KWin rules..."
dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure
echo "Done. (Move borderless windows with Meta+Left Click, resize with Meta+Right Click, close with Meta+Q.)"
