#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_VAULT="$(cd "$SCRIPT_DIR/.." && pwd)/notes"
TARGET_VAULT="${1:-$DEFAULT_VAULT}"
APP_ID="md.obsidian.Obsidian"

echo "[1/3] Resetting Flatpak overrides for $APP_ID..."
if command -v flatpak >/dev/null 2>&1; then
  flatpak override --user --reset "$APP_ID" || true
fi

echo "[2/3] Reverting Tokyo Night snippet from Obsidian vaults..."
python3 - "$TARGET_VAULT" <<'EOF'
import json
import os
import shutil
import sys

explicit_vault = sys.argv[1]
vaults = set()
if explicit_vault and os.path.isdir(explicit_vault):
    vaults.add(os.path.abspath(explicit_vault))

for p in [
    os.path.expanduser("~/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json"),
    os.path.expanduser("~/.config/obsidian/obsidian.json"),
]:
    if os.path.isfile(p):
        try:
            data = json.load(open(p, "r", encoding="utf-8"))
            for v in data.get("vaults", {}).values():
                vp = v.get("path")
                if vp and os.path.isdir(vp):
                    vaults.add(vp)
        except Exception:
            pass

for vp in sorted(vaults):
    obs_dir = os.path.join(vp, ".obsidian")
    for fname in ("snippets/tokyo-night.css", "appearance.json", "app.json", "core-plugins.json", "hotkeys.json"):
        fpath = os.path.join(obs_dir, fname)
        if os.path.isfile(fpath):
            os.chmod(fpath, 0o644)

    dst_css = os.path.join(obs_dir, "snippets", "tokyo-night.css")
    if os.path.isfile(dst_css + ".rice.bak"):
        shutil.move(dst_css + ".rice.bak", dst_css)
    elif os.path.isfile(dst_css):
        os.remove(dst_css)

    app_cfg = os.path.join(obs_dir, "appearance.json")
    if os.path.isfile(app_cfg + ".rice.bak"):
        shutil.move(app_cfg + ".rice.bak", app_cfg)
    elif os.path.isfile(app_cfg):
        try:
            cfg = json.load(open(app_cfg, "r", encoding="utf-8"))
            snippets = [s for s in cfg.get("enabledCssSnippets", []) if s != "tokyo-night"]
            cfg["enabledCssSnippets"] = snippets
            with open(app_cfg, "w", encoding="utf-8") as f:
                json.dump(cfg, f, indent=2)
        except Exception:
            pass

    for fname in ("app.json", "core-plugins.json", "hotkeys.json"):
        fpath = os.path.join(obs_dir, fname)
        if os.path.isfile(fpath + ".rice.bak"):
            shutil.move(fpath + ".rice.bak", fpath)

    print(f"Reverted Tokyo Night snippet & settings in vault: {vp}")
EOF

echo "[3/3] Removing KWin Obsidian Fullscreen rule..."
python3 - <<'EOF'
import configparser, os

path = os.path.expanduser("~/.config/kwinrulesrc")
if not os.path.exists(path):
    raise SystemExit(0)

cfg = configparser.ConfigParser(interpolation=None, strict=False)
cfg.optionxform = str
cfg.read(path)

removed = []
for sec in list(cfg.sections()):
    if sec != "General" and cfg.get(sec, "Description", fallback="") == "Rice: Obsidian Fullscreen":
        cfg.remove_section(sec)
        removed.append(sec)

if removed and cfg.has_section("General"):
    for key in ("Order", "rules"):
        if cfg.has_option("General", key):
            items = [r for r in cfg.get("General", key).split(",") if r and r not in removed]
            cfg.set("General", key, ",".join(items))
            if key == "rules":
                cfg.set("General", "count", str(len(items)))

with open(path, "w", encoding="utf-8") as f:
    cfg.write(f, space_around_delimiters=False)
EOF

if command -v dbus-send >/dev/null 2>&1; then
  dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure || true
fi

echo "Done."
