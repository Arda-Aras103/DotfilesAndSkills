#!/usr/bin/env bash
set -euo pipefail

echo "[1/1] Cleaning up Zen Browser Tokyo Night CSS and user.js settings..."
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

while IFS= read -r prof; do
  [[ -n "$prof" ]] || continue
  USER_JS="$prof/user.js"
  if [[ -f "$USER_JS.rice.bak" ]]; then
    mv -f "$USER_JS.rice.bak" "$USER_JS"
  elif [[ -f "$USER_JS" ]]; then
    sed -i '/^\/\/ >>> rice-zen >>>$/,/^\/\/ <<< rice-zen <<<$/d' "$USER_JS"
    grep -q '[^[:space:]]' "$USER_JS" || rm -f "$USER_JS"
  fi

  for name in userChrome.css userContent.css; do
    USER_CSS="$prof/chrome/$name"
    if [[ -f "$USER_CSS.rice.bak" ]]; then
      mv -f "$USER_CSS.rice.bak" "$USER_CSS"
    elif [[ -f "$USER_CSS" ]]; then
      sed -i '/^\/\* >>> rice-zen >>> \*\/$/,/^\/\* <<< rice-zen <<< \*\/$/d' "$USER_CSS"
      grep -q '[^[:space:]]' "$USER_CSS" || rm -f "$USER_CSS"
    fi
  done
  rmdir "$prof/chrome" 2>/dev/null || true
done <<< "$PROFILES"

echo "Zen Browser cleanup complete. Restart Zen."
