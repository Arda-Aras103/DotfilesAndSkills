#!/usr/bin/env bash
set -euo pipefail

echo "[1/3] Restoring window rules..."
KWIN_RULES="$HOME/.config/kwinrulesrc"
if [[ -f "$KWIN_RULES.rice.bak" ]]; then
  mv -f "$KWIN_RULES.rice.bak" "$KWIN_RULES"
elif [[ -f "$KWIN_RULES" ]]; then
  python3 - <<'EOF'
import configparser, os
path = os.path.expanduser("~/.config/kwinrulesrc")
cfg = configparser.ConfigParser(interpolation=None, strict=False)
cfg.optionxform = str
cfg.read(path)
removed = []
for sec in list(cfg.sections()):
    if sec != "General" and cfg.get(sec, "Description", fallback="") == "Rice: No Titlebar":
        cfg.remove_section(sec)
        removed.append(sec)
if cfg.has_section("General"):
    if cfg.has_option("General", "Order"):
        existing = [r for r in cfg.get("General", "Order", fallback="").split(",") if r and r not in removed]
        cfg.set("General", "Order", ",".join(existing))
    if cfg.has_option("General", "rules"):
        existing = [r for r in cfg.get("General", "rules", fallback="").split(",") if r and r not in removed]
        cfg.set("General", "rules", ",".join(existing))
        cfg.set("General", "count", str(len(existing)))
with open(path, "w", encoding="utf-8") as f:
    cfg.write(f, space_around_delimiters=False)
EOF
fi

echo "[2/3] Restoring Dolphin menu bar..."
pkill -x dolphin 2>/dev/null || true
DOLPHIN_RC="$HOME/.config/dolphinrc"
if [[ -f "$DOLPHIN_RC.rice.bak" ]]; then
  mv -f "$DOLPHIN_RC.rice.bak" "$DOLPHIN_RC"
fi

echo "[3/3] Reloading KWin..."
dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure
echo "Window and Dolphin cleanup complete."
