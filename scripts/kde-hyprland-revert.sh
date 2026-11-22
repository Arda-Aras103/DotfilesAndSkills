#!/usr/bin/env bash
set -euo pipefail

echo "[1/4] Removing Krohnkite (if present)..."
if command -v kpackagetool6 >/dev/null 2>&1; then
  kpackagetool6 -t KWin/Script -r krohnkite 2>/dev/null || true
fi
rm -rf "$HOME/.local/share/kwin/scripts/krohnkite"

echo "[2/4] Restoring backed up configs..."
for f in kdeglobals kwinrc kglobalshortcutsrc; do
  if [[ -f "$HOME/.config/$f.rice.bak" ]]; then
    mv -f "$HOME/.config/$f.rice.bak" "$HOME/.config/$f"
    echo "  -> $f.rice.bak restored."
  fi
done

echo "[3/4] Cleaning up remaining overrides..."
python3 - <<'EOF'
import configparser
import os

def clean_ini(path, removals):
    full_path = os.path.expanduser(path)
    if not os.path.exists(full_path):
        return
    cfg = configparser.ConfigParser(interpolation=None, strict=False)
    cfg.optionxform = str
    cfg.read(full_path)
    for section, keys in removals.items():
        if not cfg.has_section(section):
            continue
        if keys is None:
            cfg.remove_section(section)
        else:
            for k in keys:
                cfg.remove_option(section, k)
            if not cfg.options(section):
                cfg.remove_section(section)
    with open(full_path, "w") as f:
        cfg.write(f, space_around_delimiters=False)

clean_ini("~/.config/kdeglobals", {
    "KDE": ["AnimationDurationFactor"]
})

clean_ini("~/.config/kwinrc", {
    "Plugins": ["krohnkiteEnabled"],
    "Script-krohnkite": None,
    "Effect-blur": ["BlurStrength", "NoiseStrength"],
})
EOF

echo "[4/4] Re-enabling Baloo, reloading KWin and shortcuts..."
if command -v balooctl6 >/dev/null 2>&1; then
  balooctl6 enable >/dev/null 2>&1 || true
fi

dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure
systemctl --user restart plasma-kglobalaccel.service >/dev/null 2>&1 || true
echo "Revert complete."
