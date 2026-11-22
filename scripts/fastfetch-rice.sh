#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[1/3] Installing Fastfetch..."
if ! command -v fastfetch >/dev/null 2>&1; then
  sudo dnf install -y fastfetch
fi

echo "[2/3] Copying rotating Braille ASCII logos and config..."
mkdir -p "$HOME/.config/fastfetch/logos"
if [[ -f "$HOME/.config/fastfetch/config.jsonc" && ! -f "$HOME/.config/fastfetch/config.jsonc.rice.bak" ]]; then
  cp -f "$HOME/.config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc.rice.bak"
fi
cp -f "$REPO_ROOT/configs/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
cp -f "$REPO_ROOT/configs/fastfetch/logos/"*.txt "$HOME/.config/fastfetch/logos/"
cp -f "$REPO_ROOT/configs/fastfetch/fastfetch-rotate.sh" "$HOME/.config/fastfetch/fastfetch-rotate.sh"
chmod +x "$HOME/.config/fastfetch/fastfetch-rotate.sh"

echo "[3/3] Adding ~/.bashrc alias..."
ALIAS_LINE='alias fastfetch="$HOME/.config/fastfetch/fastfetch-rotate.sh"'
if ! grep -qxF "$ALIAS_LINE" "$HOME/.bashrc"; then
  printf '\n%s\n' "$ALIAS_LINE" >> "$HOME/.bashrc"
fi

"$HOME/.config/fastfetch/fastfetch-rotate.sh"
echo "(To enable immediately in the current tab: source ~/.bashrc)"
