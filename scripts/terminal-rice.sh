#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[1/5] Installing Starship..."
if ! command -v starship >/dev/null 2>&1; then
  sudo dnf copr enable -y atim/starship
  sudo dnf install -y starship
fi

echo "[2/5] Checking JetBrainsMono Nerd Font..."
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd"
if [[ ! -d "$FONT_DIR" ]]; then
  mkdir -p "$FONT_DIR"
  TMP_ZIP="$(mktemp --suffix=.zip)"
  trap 'rm -f "$TMP_ZIP"' EXIT
  curl -fLo "$TMP_ZIP" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  unzip -oq "$TMP_ZIP" -d "$FONT_DIR"
  rm -f "$TMP_ZIP"
  fc-cache -f
fi

echo "[3/5] Applying Kitty Tokyo Night config..."
mkdir -p "$HOME/.config/kitty"
if [[ -f "$HOME/.config/kitty/kitty.conf" && ! -f "$HOME/.config/kitty/kitty.conf.rice.bak" ]]; then
  cp -f "$HOME/.config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf.rice.bak"
fi
cp -f "$REPO_ROOT/configs/kitty/tokyo-night.conf" "$HOME/.config/kitty/tokyo-night.conf"
touch "$HOME/.config/kitty/kitty.conf"
if ! grep -qxF "include tokyo-night.conf" "$HOME/.config/kitty/kitty.conf"; then
  printf '\ninclude tokyo-night.conf\n' >> "$HOME/.config/kitty/kitty.conf"
fi

echo "[4/5] Applying Konsole / Dolphin F4 bottom panel Tokyo Night theme..."
KONSOLE_DIR="$HOME/.local/share/konsole"
KONSOLE_STATE="$HOME/.config/.rice-konsole-prev"
mkdir -p "$KONSOLE_DIR"
cp -f "$REPO_ROOT/configs/konsole/TokyoNight.colorscheme" "$KONSOLE_DIR/TokyoNight.colorscheme"
cp -f "$REPO_ROOT/configs/konsole/TokyoNight.profile" "$KONSOLE_DIR/TokyoNight.profile"
if [[ ! -f "$KONSOLE_STATE" ]]; then
  if command -v kreadconfig6 >/dev/null 2>&1; then
    PREV_KONSOLE_PROF="$(kreadconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile 2>/dev/null || true)"
  else
    PREV_KONSOLE_PROF="$(python3 -c 'import configparser, os; c=configparser.ConfigParser(interpolation=None, strict=False); c.optionxform=str; c.read(os.path.expanduser("~/.config/konsolerc"), encoding="utf-8"); print(c.get("Desktop Entry", "DefaultProfile", fallback=""))')"
  fi
  printf 'PREV_KONSOLE_PROF=%q\n' "$PREV_KONSOLE_PROF" > "$KONSOLE_STATE"
fi
if command -v kwriteconfig6 >/dev/null 2>&1; then
  kwriteconfig6 --file konsolerc --group "Desktop Entry" --key DefaultProfile TokyoNight.profile
else
  python3 - "$HOME/.config/konsolerc" <<'PY'
import configparser, os, sys
p = sys.argv[1]
c = configparser.ConfigParser(interpolation=None, strict=False)
c.optionxform = str
if os.path.exists(p):
    c.read(p, encoding="utf-8")
if not c.has_section("Desktop Entry"):
    c.add_section("Desktop Entry")
c.set("Desktop Entry", "DefaultProfile", "TokyoNight.profile")
os.makedirs(os.path.dirname(p), exist_ok=True)
with open(p, "w", encoding="utf-8") as f:
    c.write(f, space_around_delimiters=False)
PY
fi

echo "[5/5] Adding Starship config and bashrc integration..."
mkdir -p "$HOME/.config"
cp -f "$REPO_ROOT/configs/starship/starship.toml" "$HOME/.config/starship.toml"
if ! grep -q 'starship init bash' "$HOME/.bashrc"; then
  printf '\neval "$(starship init bash)"\n' >> "$HOME/.bashrc"
fi
if ! grep -q 'alias ssh="kitten ssh"' "$HOME/.bashrc"; then
  printf '[ "$TERM" = "xterm-kitty" ] && alias ssh="kitten ssh"\n' >> "$HOME/.bashrc"
fi

pkill -USR1 -x kitty 2>/dev/null || true
echo "Done. New Kitty tabs/windows and Dolphin F4 bottom panel will open with Tokyo Night (or run: source ~/.bashrc)."
