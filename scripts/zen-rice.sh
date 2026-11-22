#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CSS_SRC="$ROOT_DIR/configs/zen/userChrome.css"
CONTENT_SRC="$ROOT_DIR/configs/zen/userContent.css"

echo "[1/2] Locating Zen Browser profile..."
PROFILES=$(python3 - <<'EOF'
import configparser
import os

bases = [
    os.path.expanduser("~/.zen"),
    os.path.expanduser("~/.var/app/app.zen_browser.zen/.zen"),
    os.path.expanduser("~/.var/app/io.github.zen_browser.zen/.zen"),
]

found = []
for base in bases:
    ini = os.path.join(base, "profiles.ini")
    if not os.path.isfile(ini):
        continue
    cfg = configparser.ConfigParser(interpolation=None, strict=False)
    cfg.optionxform = str
    cfg.read(ini, encoding="utf-8")
    for sec in cfg.sections():
        if not sec.startswith("Profile"):
            continue
        p = cfg.get(sec, "Path", fallback="").strip()
        if not p:
            continue
        is_rel = cfg.get(sec, "IsRelative", fallback="1").strip() == "1"
        full = os.path.join(base, p) if is_rel else os.path.expanduser(p)
        if os.path.isdir(full) and full not in found:
            found.append(full)

for p in found:
    print(p)
EOF
)

if [[ -z "$PROFILES" ]]; then
  echo "Error: Zen Browser profile not found (~/.zen or Flatpak .zen). Launch Zen once and close it." >&2
  exit 1
fi

echo "[2/2] Applying Tokyo Night userChrome.css, userContent.css, and accent setting..."
while IFS= read -r prof; do
  [[ -n "$prof" ]] || continue
  echo "  -> Profile: $prof"

  USER_JS="$prof/user.js"
  if [[ -f "$USER_JS" && ! -f "$USER_JS.rice.bak" ]]; then
    cp -f "$USER_JS" "$USER_JS.rice.bak"
  fi
  touch "$USER_JS"
  sed -i '/^\/\/ >>> rice-zen >>>$/,/^\/\/ <<< rice-zen <<<$/d' "$USER_JS"
  cat <<'EOF' >> "$USER_JS"

// >>> rice-zen >>>
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("zen.theme.accent-color", "#7aa2f7");
user_pref("toolkit.telemetry.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("extensions.pocket.enabled", false);
user_pref("gfx.webrender.all", true);
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("widget.wayland.fractional-scale.enabled", true);
// <<< rice-zen <<<
EOF

  mkdir -p "$prof/chrome"
  for pair in "userChrome.css:$CSS_SRC" "userContent.css:$CONTENT_SRC"; do
    name="${pair%%:*}"
    src="${pair#*:}"
    dst="$prof/chrome/$name"
    if [[ -f "$dst" && ! -f "$dst.rice.bak" ]]; then
      cp -f "$dst" "$dst.rice.bak"
    fi
    touch "$dst"
    sed -i '/^\/\* >>> rice-zen >>> \*\/$/,/^\/\* <<< rice-zen <<< \*\/$/d' "$dst"
    {
      echo ""
      echo "/* >>> rice-zen >>> */"
      cat "$src"
      echo "/* <<< rice-zen <<< */"
    } >> "$dst"
  done
done <<< "$PROFILES"

echo "Done. Fully close and reopen Zen Browser to see changes."
