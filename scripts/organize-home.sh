#!/usr/bin/env bash
# Categorizes home directory items; logs each move for reversible undo.
# Usage:
#   organize-home.sh --dry-run   # preview planned actions
#   organize-home.sh --apply     # apply moves and create undo log
#   organize-home.sh --revert    # exactly revert the last --apply run
set -euo pipefail

MODE="${1:---dry-run}"
LOG_DIR="$HOME/.local/state"
MOVE_LOG="$LOG_DIR/organize-home-moves.tsv"
APPLETS_RC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
APPLETS_BAK="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc.organize.bak"

case "$MODE" in
  --dry-run|--apply|--revert) ;;
  *)
    echo "Usage: $0 [--dry-run|--apply|--revert]" >&2
    exit 1
    ;;
esac

if [[ "$MODE" == "--revert" ]]; then
  if [[ ! -f "$MOVE_LOG" ]]; then
    echo "No log found to revert: $MOVE_LOG"
    exit 0
  fi
  tac "$MOVE_LOG" | while IFS=$'\t' read -r src dst; do
    if [[ -e "$dst" && ! -e "$src" ]]; then
      mkdir -p "$(dirname "$src")"
      mv -- "$dst" "$src"
      echo "REVERT: $dst -> $src"
    fi
  done
  if [[ -f "$APPLETS_BAK" ]]; then
    mv -f -- "$APPLETS_BAK" "$APPLETS_RC"
    echo "RESTORE: $APPLETS_RC"
  fi
  rmdir --ignore-fail-on-non-empty \
    "$HOME/videos/Series/Digital-Circus" "$HOME/videos/Series" \
    "$HOME/videos/Anime/ReZero" "$HOME/videos/Anime" \
    "$HOME/videos/AI" "$HOME/videos/Tech-Dev" "$HOME/videos/Gaming" "$HOME/videos/General" \
    "$HOME/Pictures/Wallpapers/Live" "$HOME/Pictures/Wallpapers/Static" "$HOME/Pictures/Wallpapers" \
    "$HOME/Pictures/Misc" "$HOME/Pictures/Screenshots" \
    "$HOME/.local/state/rice-backups/config/btop" \
    "$HOME/.local/state/rice-backups/config/fastfetch" \
    "$HOME/.local/state/rice-backups/config/gtk-3.0" \
    "$HOME/.local/state/rice-backups/config/gtk-4.0" \
    "$HOME/.local/state/rice-backups/config/zed" \
    "$HOME/.local/state/rice-backups/config" \
    "$HOME/.local/state/rice-backups/home" \
    "$HOME/.local/state/rice-backups" 2>/dev/null || true
  rm -f -- "$MOVE_LOG"
  echo "Revert complete."
  exit 0
fi

if [[ "$MODE" == "--apply" ]]; then
  mkdir -p "$LOG_DIR"
  : > "$MOVE_LOG"
fi

do_move() {
  local src="$1"
  local dst="$2"
  [[ -e "$src" ]] || return 0
  if [[ "$src" == "$dst" ]]; then
    return 0
  fi
  if [[ -e "$dst" ]]; then
    echo "SKIP (destination already exists): $src -> $dst"
    return 0
  fi
  if [[ "$MODE" == "--dry-run" ]]; then
    echo "DRY-RUN: $src -> $dst"
  else
    mkdir -p "$(dirname "$dst")"
    mv -- "$src" "$dst"
    printf '%s\t%s\n' "$src" "$dst" >> "$MOVE_LOG"
    echo "MOVED: $src -> $dst"
  fi
}

cleanup_empty_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  if [[ -z "$(ls -A "$dir")" ]]; then
    if [[ "$MODE" == "--dry-run" ]]; then
      echo "DRY-RUN rmdir: $dir"
    else
      rmdir -- "$dir"
      echo "RMDIR: $dir"
    fi
  fi
}

# 1. ~/downloads -> ~/videos/Anime/Konosuba + ~/Downloads
if [[ -d "$HOME/downloads" ]]; then
  if [[ -d "$HOME/downloads/konosuba" ]]; then
    do_move "$HOME/downloads/konosuba" "$HOME/videos/Anime/Konosuba"
  fi
  shopt -s nullglob dotglob
  for item in "$HOME/downloads/"*; do
    base="$(basename "$item")"
    do_move "$item" "$HOME/Downloads/$base"
  done
  shopt -u nullglob dotglob
  cleanup_empty_dir "$HOME/downloads"
fi

# 2. ~/Screenshots -> ~/Pictures/Screenshots
if [[ -d "$HOME/Screenshots" ]]; then
  if [[ "$MODE" == "--apply" ]]; then
    mkdir -p "$HOME/Pictures/Screenshots"
  fi
  shopt -s nullglob dotglob
  for item in "$HOME/Screenshots/"*; do
    base="$(basename "$item")"
    do_move "$item" "$HOME/Pictures/Screenshots/$base"
  done
  shopt -u nullglob dotglob
  cleanup_empty_dir "$HOME/Screenshots"
fi

# 3. ~/Wallpaper -> ~/Pictures/Wallpapers/{Live,Static} and ~/Pictures/Misc
if [[ -d "$HOME/Wallpaper" ]]; then
  shopt -s nullglob
  for item in "$HOME/Wallpaper/"*; do
    base="$(basename "$item")"
    lower="${base,,}"
    if [[ "$lower" == oip-* ]]; then
      do_move "$item" "$HOME/Pictures/Misc/$base"
    elif [[ "$lower" == *.webm || "$lower" == *.mkv || "$lower" == *.mp4 ]]; then
      do_move "$item" "$HOME/Pictures/Wallpapers/Live/$base"
    else
      do_move "$item" "$HOME/Pictures/Wallpapers/Static/$base"
    fi
  done
  shopt -u nullglob
  cleanup_empty_dir "$HOME/Wallpaper"

  if [[ "$MODE" == "--apply" && -f "$APPLETS_RC" ]] && grep -q "$HOME/Wallpaper/" "$APPLETS_RC"; then
    cp -a "$APPLETS_RC" "$APPLETS_BAK"
    python3 - "$APPLETS_RC" "$HOME" <<'PY'
import pathlib, re, sys
rc = pathlib.Path(sys.argv[1])
home = sys.argv[2]
text = rc.read_text(encoding="utf-8", errors="replace")
def repl(m):
    name = m.group(1)
    low = name.lower()
    sub = "Live" if low.endswith((".webm", ".mkv", ".mp4")) else "Static"
    return f"{home}/Pictures/Wallpapers/{sub}/{name}"
updated = re.sub(re.escape(home) + r"/Wallpaper/([^\n]+)", repl, text)
rc.write_text(updated, encoding="utf-8")
PY
    echo "UPDATED wallpaper paths in: $APPLETS_RC"
  fi
fi

# 4. ~/videos subfolders (keep ~/videos name and .download-archive.txt for yt-dl compatibility)
classify_video() {
  local lower="${1,,}"
  if [[ "$lower" == *"amazing digital circus"* ]]; then
    echo "Series/Digital-Circus"
  elif [[ "$lower" == *"re：zero"* || "$lower" == *"re:zero"* || "$lower" == *"subaru"* ]]; then
    echo "Anime/ReZero"
  elif [[ "$lower" == *"anime"* ]]; then
    echo "Anime"
  elif [[ "$lower" == *"claude"* || "$lower" == *"openai"* || "$lower" == *"deepseek"* || "$lower" == *"yapay zeka"* || "$lower" == *"yapay zekâ"* || "$lower" == *"ai firmaları"* || "$lower" == *"every ai"* || "$lower" == *"fable 5.2"* || "$lower" == *"promptlara"* || "$lower" == *"nvidia"* || "$lower" == *"jensen huang"* ]]; then
    echo "AI"
  elif [[ "$lower" == "aws" || "$lower" == *"rust"* || "$lower" == *"coding language"* || "$lower" == *"physics engine"* || "$lower" == *"computer viruses"* || "$lower" == *"turkish letter"* || "$lower" == *"qwerty"* || "$lower" == *"routers"* || "$lower" == *"smart tvs"* || "$lower" == *"tv setup"* || "$lower" == *"laptop"* || "$lower" == *"microphone"* || "$lower" == *"stewie griffin usb"* || "$lower" == *"herdr"* || "$lower" == *"steam games now"* || "$lower" == *"türkticaret"* || "$lower" == *"razer"* || "$lower" == *"kutu açılışı"* ]]; then
    echo "Tech-Dev"
  elif [[ "$lower" == *"minecraft"* || "$lower" == *"deltarune"* || "$lower" == *"gta 6"* || "$lower" == *"büyük araba soygunu"* || "$lower" == *"phantom blade"* || "$lower" == *"poop killer"* || "$lower" == *"erratic deck"* || "$lower" == *"destemle"* || "$lower" == *"seeok"* || "$lower" == *"rest stop"* || "$lower" == *"postpartum"* || "$lower" == *"paranormal activity"* || "$lower" == *"suzy says"* || "$lower" == *"board game"* || "$lower" == *"pickaxes"* ]]; then
    echo "Gaming"
  else
    echo "General"
  fi
}

if [[ -d "$HOME/videos" ]]; then
  KNOWN_CATS=("Anime" "Series" "AI" "Tech-Dev" "Gaming" "General")
  shopt -s nullglob
  for entry in "$HOME/videos/"*; do
    [[ -d "$entry" ]] || continue
    base="$(basename "$entry")"
    skip=false
    for c in "${KNOWN_CATS[@]}"; do
      if [[ "$base" == "$c" ]]; then
        skip=true
        break
      fi
    done
    $skip && continue
    cat_rel="$(classify_video "$base")"
    do_move "$entry" "$HOME/videos/$cat_rel/$base"
  done
  shopt -u nullglob
fi

# 5. Collect .bak / .rice-*-prev backups in ~ and ~/.config under ~/.local/state/rice-backups
# Note: Before using revert-all.sh, run `organize-home.sh --revert` first to restore backups to their original paths.
BACKUP_ROOT="$LOG_DIR/rice-backups"
shopt -s nullglob
for item in "$HOME/"*.bak "$HOME/".*.bak; do
  [[ -f "$item" ]] || continue
  do_move "$item" "$BACKUP_ROOT/home/$(basename "$item")"
done
shopt -u nullglob

if [[ -d "$HOME/.config" ]]; then
  while IFS= read -r -d '' item; do
    rel="${item#"$HOME/.config/"}"
    do_move "$item" "$BACKUP_ROOT/config/$rel"
  done < <(find "$HOME/.config" -maxdepth 2 -type f \( -name '*.bak' -o -name '.rice-*-prev' \) -print0)
fi

if [[ "$MODE" == "--dry-run" ]]; then
  echo "Dry-run finished. To apply: $0 --apply"
else
  echo "Organization complete. To revert: $0 --revert"
fi
