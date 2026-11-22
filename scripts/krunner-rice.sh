#!/usr/bin/env bash
set -euo pipefail

KRUNNER_RC="$HOME/.config/krunnerrc"

echo "[1/4] Backing up KRunner config..."
if [[ -f "$KRUNNER_RC" && ! -f "$KRUNNER_RC.rice.bak" ]]; then
  cp -f "$KRUNNER_RC" "$KRUNNER_RC.rice.bak"
fi

echo "[2/4] Checking Baloo status (disabled by default; set KRUNNER_ENABLE_BALOO=1 to enable)..."
if [[ "${KRUNNER_ENABLE_BALOO:-0}" == "1" ]] && command -v balooctl6 >/dev/null 2>&1; then
  balooctl6 enable >/dev/null 2>&1 || true
fi

echo "[3/4] Streamlining KRunner (centered floating + disabling unused plugins)..."
python3 - <<'EOF'
import configparser
import glob
import os

path = os.path.expanduser("~/.config/krunnerrc")
cfg = configparser.ConfigParser(interpolation=None, strict=False)
cfg.optionxform = str
if os.path.exists(path):
    cfg.read(path, encoding="utf-8")

if not cfg.has_section("General"):
    cfg.add_section("General")
cfg.set("General", "FreeFloating", "true")
cfg.set("General", "RetainPriorSearch", "false")

if not cfg.has_section("Plugins"):
    cfg.add_section("Plugins")

keep = {
    "services",
    "krunner_services",
    "applications",
    "krunner_applications",
    "places",
    "krunner_places",
    "recentdocuments",
    "krunner_recentdocuments",
    "calculator",
    "krunner_calculator",
    "shell",
    "krunner_shell",
    "commandline",
    "krunner_commandline",
    "unitconverter",
    "krunner_unitconverter",
    "powerdevil",
    "krunner_powerdevil",
    "sessions",
    "krunner_sessions",
}

discovered = set()
for pattern in (
    "/usr/lib64/qt6/plugins/kf6/krunner/*.so",
    "/usr/lib/qt6/plugins/kf6/krunner/*.so",
    "/usr/share/krunner/dbusplugins/*.desktop",
):
    for p in glob.glob(pattern):
        discovered.add(os.path.splitext(os.path.basename(p))[0])

fallback_disable = {
    "krunner_webshortcuts",
    "webshortcuts",
    "krunner_bookmarksrunner",
    "bookmarks",
    "krunner_bookmarks",
    "locations",
    "krunner_locations",
    "krunner_appstream",
    "appstream",
    "helprunner",
    "krunner_kill",
    "krunner_dictionary",
    "krunner_spellcheck",
    "krunner_charrunner",
    "browserhistory",
    "browsertabs",
    "baloosearch",
}

if os.environ.get("KRUNNER_ENABLE_BALOO") == "1":
    keep.add("baloosearch")

for name in sorted(discovered | keep | fallback_disable):
    key = name if name.endswith("Enabled") else f"{name}Enabled"
    stem = name[:-7] if name.endswith("Enabled") else name
    cfg.set("Plugins", key, "true" if stem in keep else "false")

with open(path, "w", encoding="utf-8") as f:
    cfg.write(f, space_around_delimiters=False)
EOF

echo "[4/4] Restarting KRunner background process..."
kquitapp6 krunner >/dev/null 2>&1 || pkill -x krunner >/dev/null 2>&1 || true

echo "Done. (Open streamlined KRunner with Alt+Space or Meta.)"
