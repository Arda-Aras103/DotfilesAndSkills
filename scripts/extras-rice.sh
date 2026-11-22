#!/usr/bin/env bash
set -euo pipefail

echo "[1/5] Updating 'cr' command to clear scrollback as well..."
BASHRC="$HOME/.bashrc"
if [[ -f "$BASHRC" && ! -f "$BASHRC.cr.bak" ]]; then
  cp -f "$BASHRC" "$BASHRC.cr.bak"
fi
touch "$BASHRC"
if grep -qE '^alias cr=' "$BASHRC"; then
  sed -i -E 's|^alias cr=.*$|alias cr="printf '\''\\033[2J\\033[3J\\033[H'\''"|' "$BASHRC"
else
  printf '\nalias cr="printf '\''\\033[2J\\033[3J\\033[H'\''"\n' >> "$BASHRC"
fi

echo "[2/5] Clearing conflicting Krohnkite Meta+Return and registering Win+Enter (Kitty) and Win+E (Dolphin)..."
KGLOBAL="$HOME/.config/kglobalshortcutsrc"
if [[ -f "$KGLOBAL" && ! -f "$KGLOBAL.extras.bak" ]]; then
  cp -f "$KGLOBAL" "$KGLOBAL.extras.bak"
fi

# Clean up temporary desktop file from older attempt
if [[ -f "$HOME/.local/share/applications/kitty-shortcut.desktop" ]]; then
  gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
    --method org.kde.KGlobalAccel.setShortcutKeys \
    "['kitty-shortcut.desktop', '_launch', 'Kitty Shortcut', '']" "[]" 4 >/dev/null 2>&1 || true
  rm -f "$HOME/.local/share/applications/kitty-shortcut.desktop"
fi

# Remove KrohnkiteSetMaster Meta+Return conflict
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setShortcutKeys \
  "['kwin', 'KrohnkiteSetMaster', 'KWin', 'Krohnkite: Set master']" "[]" 4 >/dev/null 2>&1 || true

# Meta+Return (0x10000000 + 0x01000004 = 285212676) -> kitty.desktop
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setShortcutKeys \
  "['kitty.desktop', '_launch', 'kitty', 'Launch Kitty']" "[([285212676, 0, 0, 0],)]" 4 >/dev/null 2>&1 || true

# Meta+E (0x10000000 + 0x45 = 268435525) -> org.kde.dolphin.desktop
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setShortcutKeys \
  "['org.kde.dolphin.desktop', '_launch', 'Dolphin', 'Dolphin']" "[([268435525, 0, 0, 0],)]" 4 >/dev/null 2>&1 || true

echo "[3/5] Setting Kitty as default external terminal (keeps Dolphin F4 bottom panel; Shift+F4 opens Kitty)..."
DOLPHIN_TERM_STATE="$HOME/.config/.rice-dolphin-term-prev"

if [[ ! -f "$DOLPHIN_TERM_STATE" ]]; then
  if command -v kreadconfig6 >/dev/null 2>&1; then
    PREV_TERM_APP="$(kreadconfig6 --file kdeglobals --group General --key TerminalApplication 2>/dev/null || true)"
    PREV_TERM_SVC="$(kreadconfig6 --file kdeglobals --group General --key TerminalService 2>/dev/null || true)"
  else
    PREV_TERM_APP="$(python3 -c 'import configparser, os; c=configparser.ConfigParser(interpolation=None, strict=False); c.optionxform=str; c.read(os.path.expanduser("~/.config/kdeglobals"), encoding="utf-8"); print(c.get("General", "TerminalApplication", fallback=""))')"
    PREV_TERM_SVC="$(python3 -c 'import configparser, os; c=configparser.ConfigParser(interpolation=None, strict=False); c.optionxform=str; c.read(os.path.expanduser("~/.config/kdeglobals"), encoding="utf-8"); print(c.get("General", "TerminalService", fallback=""))')"
  fi
  python3 - "$DOLPHIN_TERM_STATE" "$PREV_TERM_APP" "$PREV_TERM_SVC" <<'PY'
import json
import os
import sys

state_path, prev_app, prev_svc = sys.argv[1:4]
os.makedirs(os.path.dirname(state_path), exist_ok=True)
with open(state_path, "w", encoding="utf-8") as f:
    json.dump({"TerminalApplication": prev_app, "TerminalService": prev_svc}, f, indent=2)
PY
fi

if command -v kwriteconfig6 >/dev/null 2>&1; then
  kwriteconfig6 --file kdeglobals --group General --key TerminalApplication kitty
  kwriteconfig6 --file kdeglobals --group General --key TerminalService kitty.desktop
else
  python3 - "$HOME/.config/kdeglobals" <<'PY'
import configparser
import os
import sys

path = sys.argv[1]
cfg = configparser.ConfigParser(interpolation=None, strict=False)
cfg.optionxform = str
if os.path.exists(path):
    cfg.read(path, encoding="utf-8")
if not cfg.has_section("General"):
    cfg.add_section("General")
cfg.set("General", "TerminalApplication", "kitty")
cfg.set("General", "TerminalService", "kitty.desktop")
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as f:
    cfg.write(f, space_around_delimiters=False)
PY
fi

command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 --noincremental >/dev/null 2>&1 || true

echo "[4/5] Writing Electron/Wayland crispness config (~/.config/environment.d/)..."
mkdir -p "$HOME/.config/environment.d"
cat <<'EOF' > "$HOME/.config/environment.d/90-wayland-rice.conf"
ELECTRON_OZONE_PLATFORM_HINT=auto
EOF

echo "[5/5] Done. To activate: exec bash"
echo "(Win+Enter -> Kitty, Win+E -> Dolphin, Dolphin F4 -> Tokyo Night bottom panel, Shift+F4 -> external Kitty.)"
