#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEME_SRC="$(cd "$SCRIPT_DIR/../configs/kde" && pwd)"
SCHEME_DST="$HOME/.local/share/color-schemes"

THEMES=(TokyoNight RosePine CatppuccinMocha GruvboxDark Nord Kanagawa)

mkdir -p "$SCHEME_DST"
for t in "${THEMES[@]}"; do
  if [[ -f "$SCHEME_SRC/$t.colors" ]]; then
    cp -f "$SCHEME_SRC/$t.colors" "$SCHEME_DST/$t.colors"
  fi
done

CURRENT=$(python3 -c '
import configparser, os
c = configparser.ConfigParser(interpolation=None, strict=False)
c.read(os.path.expanduser("~/.config/kdeglobals"))
print(c.get("General", "ColorScheme", fallback=""))
')

case "${1:-cycle}" in
  tokyo)      TARGET="TokyoNight" ;;
  rose)       TARGET="RosePine" ;;
  catppuccin) TARGET="CatppuccinMocha" ;;
  gruvbox)    TARGET="GruvboxDark" ;;
  nord)       TARGET="Nord" ;;
  kanagawa)   TARGET="Kanagawa" ;;
  list)
    printf '%s\n' "${THEMES[@]}"
    exit 0
    ;;
  cycle|toggle)
    TARGET="${THEMES[0]}"
    for i in "${!THEMES[@]}"; do
      if [[ "${THEMES[$i]}" == "$CURRENT" ]]; then
        NEXT_IDX=$(( (i + 1) % ${#THEMES[@]} ))
        TARGET="${THEMES[$NEXT_IDX]}"
        break
      fi
    done
    ;;
  *)
    echo "Usage: $0 [tokyo|rose|catppuccin|gruvbox|nord|kanagawa|cycle|list]" >&2
    exit 1
    ;;
esac

plasma-apply-colorscheme "$TARGET"
command -v notify-send >/dev/null 2>&1 && notify-send -t 1500 "Theme Changed" "$TARGET" || true
echo "Active theme: $TARGET"
