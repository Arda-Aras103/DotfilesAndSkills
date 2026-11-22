#!/usr/bin/env bash
set -euo pipefail

echo "[1/5] Reverting Kitty config..."
if [[ -f "$HOME/.config/kitty/kitty.conf.rice.bak" ]]; then
  mv -f "$HOME/.config/kitty/kitty.conf.rice.bak" "$HOME/.config/kitty/kitty.conf"
elif [[ -f "$HOME/.config/kitty/kitty.conf" ]]; then
  sed -i '/^include tokyo-night\.conf$/d' "$HOME/.config/kitty/kitty.conf"
fi
rm -f "$HOME/.config/kitty/tokyo-night.conf"

echo "[2/5] Reverting Konsole / Dolphin F4 bottom panel Tokyo Night theme..."
rm -f "$HOME/.local/share/konsole/TokyoNight.colorscheme" "$HOME/.local/share/konsole/TokyoNight.profile"
KONSOLE_STATE="$HOME/.config/.rice-konsole-prev"
if [[ -f "$KONSOLE_STATE" ]]; then
  PREV_KONSOLE_PROF=""
  # shellcheck disable=SC1090
  source "$KONSOLE_STATE"
  rm -f "$KONSOLE_STATE"
  if command -v kwriteconfig6 >/dev/null 2>&1; then
    if [[ -n "$PREV_KONSOLE_PROF" ]]; then
      kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile "$PREV_KONSOLE_PROF"
    else
      kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile --delete 2>/dev/null || true
    fi
  elif [[ -f "$HOME/.config/konsolerc" ]]; then
    python3 - "$HOME/.config/konsolerc" "$PREV_KONSOLE_PROF" <<'PY'
import configparser, sys
p, prev = sys.argv[1], sys.argv[2]
c = configparser.ConfigParser(interpolation=None, strict=False)
c.optionxform = str
c.read(p, encoding="utf-8")
if c.has_section("Desktop Entry"):
    if prev:
        c.set("Desktop Entry", "DefaultProfile", prev)
    else:
        c.remove_option("Desktop Entry", "DefaultProfile")
    with open(p, "w", encoding="utf-8") as f:
        c.write(f, space_around_delimiters=False)
PY
  fi
fi

echo "[3/5] Removing Starship config and bashrc lines..."
rm -f "$HOME/.config/starship.toml"
if [[ -f "$HOME/.bashrc" ]]; then
  sed -i '/starship init bash/d; /alias ssh="kitten ssh"/d' "$HOME/.bashrc"
fi

echo "[4/5] Removing JetBrainsMono Nerd Font..."
rm -rf "$HOME/.local/share/fonts/JetBrainsMonoNerd"
fc-cache -f

echo "[5/5] Removing Starship package and COPR..."
sudo dnf remove -y starship || true
sudo dnf copr disable -y atim/starship || true
sudo dnf autoremove -y

pkill -USR1 -x kitty 2>/dev/null || true
echo "Cleanup complete. (Run exec bash to reload your current shell.)"
