#!/usr/bin/env bash
# Fetches YouTube channel RSS feed safely to bypass anti-bot challenges on web pages
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Kullanım: $0 <CHANNEL_ID_veya_RSS_URL>"
  echo "Örnek: $0 UC_x5XG1OV2P6uZZ5FSM9Ttw"
  echo "       $0 https://www.youtube.com/feeds/videos.xml?channel_id=UC_x5XG1OV2P6uZZ5FSM9Ttw"
  exit 1
fi

INPUT="$1"
if [[ "$INPUT" =~ ^https?:// ]]; then
  FEED_URL="$INPUT"
else
  FEED_URL="https://www.youtube.com/feeds/videos.xml?channel_id=${INPUT}"
fi

curl -sL "$FEED_URL"
