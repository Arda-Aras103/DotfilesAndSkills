#!/usr/bin/env bash
set -euo pipefail

LOGO_DIR="$HOME/.config/fastfetch/logos"
IDX_FILE="$HOME/.cache/fastfetch-logo-idx"

mapfile -t LOGOS < <(find "$LOGO_DIR" -maxdepth 1 -type f \( -name '*.txt' -o -name '*.png' -o -name '*.jpg' \) | sort)
COUNT=${#LOGOS[@]}
if [[ $COUNT -eq 0 ]]; then
  exec /usr/bin/fastfetch "$@"
fi

PREV=-1
if [[ -f "$IDX_FILE" ]]; then
  PREV=$(cat "$IDX_FILE" 2>/dev/null || echo -1)
fi

IDX=$(( RANDOM % COUNT ))
if [[ $COUNT -gt 1 && "$PREV" =~ ^[0-9]+$ && $IDX -eq $PREV ]]; then
  IDX=$(( (IDX + 1 + (RANDOM % (COUNT - 1))) % COUNT ))
fi

mkdir -p "$(dirname "$IDX_FILE")"
echo "$IDX" > "$IDX_FILE"

CHOSEN="${LOGOS[$IDX]}"
if [[ "$CHOSEN" == *.png || "$CHOSEN" == *.jpg ]]; then
  exec /usr/bin/fastfetch --logo-type kitty --logo "$CHOSEN" --logo-width 28 "$@"
else
  exec /usr/bin/fastfetch --logo-type file --logo "$CHOSEN" "$@"
fi
