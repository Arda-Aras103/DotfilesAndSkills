#!/usr/bin/env bash
set -euo pipefail

echo "[1/4] Restoring 'cr' alias..."
BASHRC="$HOME/.bashrc"
if [[ -f "$BASHRC.cr.bak" ]]; then
  mv -f "$BASHRC.cr.bak" "$BASHRC"
elif [[ -f "$BASHRC" ]]; then
  sed -i -E 's|^alias cr=.*$|alias cr="clear"|' "$BASHRC"
fi

echo "[2/4] Cleaning up application shortcuts and Wayland environment.d file..."
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setShortcutKeys \
  "['kitty.desktop', '_launch', 'kitty', 'Launch Kitty']" "[]" 4 >/dev/null 2>&1 || true
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setShortcutKeys \
  "['org.kde.dolphin.desktop', '_launch', 'Dolphin', 'Dolphin']" "[([268435525, 0, 0, 0],)]" 4 >/dev/null 2>&1 || true

rm -f "$HOME/.local/share/applications/kitty-shortcut.desktop"
if [[ -f "$HOME/.config/kglobalshortcutsrc.extras.bak" ]]; then
  mv -f "$HOME/.config/kglobalshortcutsrc.extras.bak" "$HOME/.config/kglobalshortcutsrc"
fi
rm -f "$HOME/.config/environment.d/90-wayland-rice.conf"
rmdir "$HOME/.config/environment.d" 2>/dev/null || true

echo "[3/4] Restoring default external terminal setting..."
DOLPHIN_RC5="$HOME/.local/share/kxmlgui5/dolphin/dolphinui.rc"
DOLPHIN_RC6="$HOME/.local/share/kxmlgui6/dolphin/dolphinui.rc"
DOLPHIN_TERM_STATE="$HOME/.config/.rice-dolphin-term-prev"

if [[ -f "$DOLPHIN_TERM_STATE" ]]; then
  python3 - "$DOLPHIN_TERM_STATE" "$HOME/.config/kdeglobals" <<'PY'
import configparser
import json
import os
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

state_path, kdeglobals_path = sys.argv[1:3]
with open(state_path, "r", encoding="utf-8") as f:
    state = json.load(f)

kwrite = shutil.which("kwriteconfig6")
for key in ("TerminalApplication", "TerminalService"):
    prev_val = state.get(key, "")
    if kwrite:
        cmd = [kwrite, "--file", "kdeglobals", "--group", "General", "--key", key]
        if prev_val:
            cmd.append(prev_val)
        else:
            cmd.append("--delete")
        subprocess.run(cmd, check=False)
    elif os.path.exists(kdeglobals_path):
        cfg = configparser.ConfigParser(interpolation=None, strict=False)
        cfg.optionxform = str
        cfg.read(kdeglobals_path, encoding="utf-8")
        if cfg.has_section("General"):
            if prev_val:
                cfg.set("General", key, prev_val)
            else:
                cfg.remove_option("General", key)
            with open(kdeglobals_path, "w", encoding="utf-8") as f:
                cfg.write(f, space_around_delimiters=False)

for rc_path, rc_info in state.get("rc_files", {}).items():
    bak_path = f"{rc_path}.extras.bak"
    if os.path.exists(rc_path):
        try:
            root = ET.parse(rc_path).getroot()
        except ET.ParseError:
            root = None
        if root is not None:
            ap = next(
                (el for el in root.findall("ActionProperties") if el.get("scheme") == "Default"),
                None,
            )
            if ap is None:
                ap = root.find("ActionProperties")
            if ap is not None:
                saved_actions = rc_info.get("actions", {})
                for act in list(ap.findall("Action")):
                    name = act.get("name")
                    if name not in {"show_terminal_panel", "open_terminal"}:
                        continue
                    saved = saved_actions.get(name)
                    if isinstance(saved, dict) and saved.get("present"):
                        prev_sc = saved.get("shortcut")
                        if prev_sc is None:
                            act.attrib.pop("shortcut", None)
                        else:
                            act.set("shortcut", prev_sc)
                    else:
                        ap.remove(act)
                if len(ap) == 0:
                    root.remove(ap)
            if not rc_info.get("existed", False) and len(root) == 0:
                os.remove(rc_path)
                try:
                    os.rmdir(os.path.dirname(rc_path))
                except OSError:
                    pass
            else:
                if hasattr(ET, "indent"):
                    ET.indent(root, space=" ")
                body = ET.tostring(root, encoding="unicode")
                with open(rc_path, "w", encoding="utf-8") as f:
                    f.write('<!DOCTYPE gui SYSTEM "kpartgui.dtd">\n')
                    f.write(body)
                    f.write("\n")
    if os.path.exists(bak_path):
        os.remove(bak_path)
PY
  rm -f "$DOLPHIN_TERM_STATE"
else
  for rc_file in "$DOLPHIN_RC5" "$DOLPHIN_RC6"; do
    if [[ -f "$rc_file.extras.bak" ]]; then
      mv -f "$rc_file.extras.bak" "$rc_file"
    fi
  done
fi

command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 --noincremental >/dev/null 2>&1 || true

echo "[4/4] Extra shortcut, terminal, and Wayland settings reverted. To activate: exec bash"
