#!/usr/bin/env bash
# Archives a URL into a single self-contained HTML file using single-file-cli or monolith
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Kullanım: $0 <URL> [cikti-dosyasi.html] [--fast]"
  exit 1
fi

URL="$1"
DATE_PREFIX="$(date +%Y-%m-%d)"
SLUG="$(echo "$URL" | sed -E 's|^https?://||; s|[^a-zA-Z0-9._-]+|-|g; s|^-+||; s|-+$||' | cut -c1-60)"
if [ "${2:-}" = "--fast" ]; then
  OUT_FILE="archives/${DATE_PREFIX}-${SLUG}.html"
  MODE="--fast"
else
  OUT_FILE="${2:-archives/${DATE_PREFIX}-${SLUG}.html}"
  MODE="${3:-}"
fi

mkdir -p "$(dirname "$OUT_FILE")"

if [ "$MODE" = "--fast" ] && command -v monolith &>/dev/null; then
  echo "[monolith] Statik tek-dosya arşivleniyor: $URL -> $OUT_FILE"
  monolith "$URL" -o "$OUT_FILE" --isolate
elif command -v single-file &>/dev/null; then
  echo "[single-file] Headless tarayıcı ile arşivleniyor: $URL -> $OUT_FILE"
  single-file "$URL" "$OUT_FILE" --browser-headless=true --remove-unused-styles=true
else
  echo "[npx single-file-cli] Headless tarayıcı ile arşivleniyor: $URL -> $OUT_FILE"
  npx -y single-file-cli "$URL" "$OUT_FILE" --browser-headless=true --remove-unused-styles=true
fi

echo "Tamamlandı: $OUT_FILE ($(du -h "$OUT_FILE" | cut -f1))"
