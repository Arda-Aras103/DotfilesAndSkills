#!/usr/bin/env bash
# Helper script to download YouTube videos/playlists/Watch Later or batch lists in 1080p with subtitles
# Output structure: videos/<title> [<id>]/<title>.<ext>
set -euo pipefail

find_zen_profile() {
  local candidates=(
    "$HOME/.zen"
    "$HOME/.var/app/io.github.zen_browser.zen/.zen"
    "$HOME/.var/app/app.zen_browser.zen/.zen"
  )
  for base in "${candidates[@]}"; do
    if [ -d "$base" ]; then
      # 1. profiles.ini içinde Default profili arayalım
      if [ -f "$base/profiles.ini" ]; then
        local prof_rel
        # [Install*] bloğundaki Default=
        prof_rel=$(awk -F= '/^\[Install/ {flag=1} flag && /^Default=/ {print $2; exit}' "$base/profiles.ini" 2>/dev/null || true)
        if [ -n "$prof_rel" ] && [ -d "$base/$prof_rel" ] && [ -f "$base/$prof_rel/cookies.sqlite" ]; then
          echo "$base/$prof_rel"
          return 0
        fi
        # [Profile*] bloğundaki Default=1
        prof_rel=$(awk -F= '/^\[Profile/ {path=""} /^Path=/ {path=$2} /^Default=1/ {print path; exit}' "$base/profiles.ini" 2>/dev/null || true)
        if [ -n "$prof_rel" ] && [ -d "$base/$prof_rel" ] && [ -f "$base/$prof_rel/cookies.sqlite" ]; then
          echo "$base/$prof_rel"
          return 0
        fi
      fi

      # 2. profiles.ini bulunamadıysa doğrudan cookies.sqlite içeren ilk klasörü bulalım
      local found
      found=$({ find "$base" -maxdepth 2 -name "cookies.sqlite" 2>/dev/null || true; } | head -n 1 || true)
      if [ -n "$found" ]; then
        dirname "$found"
        return 0
      fi
    fi
  done
  return 1
}

usage() {
  cat << 'EOF'
Kullanım:
  download.sh [SEÇENEKLER] <URL | DOSYA | watch-later>

Örnekler:
  # 1. Tek video indirme:
  ./download.sh "https://www.youtube.com/watch?v=..."

  # 2. Dosyadaki link listesinden indirme (urls.txt):
  ./download.sh urls.txt
  ./download.sh -f urls.txt

  # 3. Watch Later (Daha Sonra İzle) listesinden indirme (Zen / Firefox / Chrome çerezi):
  ./download.sh --watch-later --browser zen
  ./download.sh wl -b firefox
  ./download.sh :ytwatchlater -b chrome

  # 4. Watch Later'daki linkleri indirmeden sadece bir dosyaya listeleme/çıkarma:
  ./download.sh --watch-later --browser zen --dump-urls > watch_later_links.txt

  # 5. Özel cookies.txt dosyası ile indirme:
  ./download.sh --watch-later --cookies ./cookies.txt

Seçenekler:
  -f, --file <DOSYA>        Linkleri içeren metin dosyasından toplu indir (her satırda 1 link).
  -w, --watch-later, wl     YouTube "Daha Sonra İzle" (Watch Later) listesini hedefler (:ytwatchlater).
  -b, --browser <İSİM>      Çerezlerin okunacağı tarayıcı: zen, firefox, chrome, brave, edge, chromium.
                            (Not: Zen bir Firefox çatalı olduğundan otomatik olarak 'firefox:<zen-profil-yolu>'
                            şekline dönüştürülüp yt-dlp'ye iletilir).
  -c, --cookies <DOSYA>     Netscape formatında cookies.txt dosyası yolu.
  -a, --archive <DOSYA>     Daha önce indirilenleri tekrar indirmemek için arşiv dosyası
                            (Varsayılan: videos/.download-archive.txt).
  --no-archive              İndirme arşiv kaydını devre dışı bırakır.
  --dump-urls               Videoları indirmek yerine sadece URL listesini terminale basar.
  -l, --lang <DİLLER>       Altyazı dilleri / regex (Varsayılan: "en.*,tr.*,.*-orig").
  -h, --help                Bu yardım mesajını gösterir.

Neden "Watch Later" direkt inmez?
  YouTube'da standart herkese açık oynatma listeleri anonim olarak çekilebilir.
  Ancak "Daha Sonra İzle" (WL), Google hesabınıza özel (private) bir sistem listesidir.
  Bu nedenle yt-dlp'nin hesabınıza erişebilmesi için '--browser' veya '--cookies' parametresi şarttır.
EOF
  exit 0
}

TARGET=""
BATCH_FILE=""
BROWSER=""
COOKIES_FILE=""
ARCHIVE_FILE="videos/.download-archive.txt"
USE_ARCHIVE=true
DUMP_URLS=false
SUB_LANG="en.*,tr.*,.*-orig"

# Parametre ayrıştırma
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;
    -f|--file)
      if [[ $# -lt 2 ]]; then echo "Hata: $1 seçeneği bir değer gerektirir." >&2; exit 1; fi
      BATCH_FILE="$2"
      shift 2
      ;;
    -w|--watch-later|wl)
      TARGET=":ytwatchlater"
      shift
      ;;
    -b|--browser)
      if [[ $# -lt 2 ]]; then echo "Hata: $1 seçeneği bir değer gerektirir." >&2; exit 1; fi
      BROWSER="$2"
      shift 2
      ;;
    -c|--cookies)
      if [[ $# -lt 2 ]]; then echo "Hata: $1 seçeneği bir değer gerektirir." >&2; exit 1; fi
      COOKIES_FILE="$2"
      shift 2
      ;;
    -a|--archive)
      if [[ $# -lt 2 ]]; then echo "Hata: $1 seçeneği bir değer gerektirir." >&2; exit 1; fi
      ARCHIVE_FILE="$2"
      shift 2
      ;;
    --no-archive)
      USE_ARCHIVE=false
      shift
      ;;
    --dump-urls|--list-only)
      DUMP_URLS=true
      shift
      ;;
    -l|--lang)
      if [[ $# -lt 2 ]]; then echo "Hata: $1 seçeneği bir değer gerektirir." >&2; exit 1; fi
      SUB_LANG="$2"
      if [[ "$SUB_LANG" =~ ^[a-zA-Z]{2}$ ]]; then
        SUB_LANG="${SUB_LANG}.*"
      fi
      shift 2
      ;;
    *)
      if [ -z "$TARGET" ]; then
        TARGET="$1"
      else
        echo "Bilinmeyen veya fazla argüman: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# Eğer hedef belirtilmemiş ve batch file da yoksa yardım göster
if [ -z "$TARGET" ] && [ -z "$BATCH_FILE" ]; then
  echo "Hata: İndirilecek bir URL, dosya veya '--watch-later' belirtmelisiniz." >&2
  echo "Yardım için: $0 --help" >&2
  exit 1
fi

# Eğer TARGET var ve bu yerel bir dosyaysa otomatik olarak BATCH_FILE yap
if [ -n "$TARGET" ] && [ -f "$TARGET" ] && [ -z "$BATCH_FILE" ]; then
  BATCH_FILE="$TARGET"
  TARGET=""
fi

# Watch later takma adlarını standartlaştır
if [ "$TARGET" = "watch-later" ] || [ "$TARGET" = "wl" ] || [ "$TARGET" = "https://www.youtube.com/playlist?list=WL" ]; then
  TARGET=":ytwatchlater"
fi

# yt-dlp kontrolü
if ! command -v yt-dlp &>/dev/null; then
  echo "Hata: yt-dlp bulunamadı. Lütfen 'sudo dnf install yt-dlp' veya 'pip install yt-dlp' ile kurun." >&2
  exit 1
fi

# Watch Later çerez uyarısı ve otomatik tarayıcı tespiti
if [ "$TARGET" = ":ytwatchlater" ]; then
  if [ -z "$BROWSER" ] && [ -z "$COOKIES_FILE" ]; then
    # Kullanıcının kurulu olabilecek tarayıcılarını tespit etmeye çalış
    if [ -d "$HOME/.zen" ] || [ -d "$HOME/.var/app/io.github.zen_browser.zen/.zen" ] || [ -d "$HOME/.var/app/app.zen_browser.zen/.zen" ]; then
      BROWSER="zen"
      echo "ℹ️  Watch Later için 'zen' tarayıcı profili kullanılacak." >&2
    elif [ -d "$HOME/.mozilla/firefox" ]; then
      BROWSER="firefox"
      echo "ℹ️  Watch Later için 'firefox' tarayıcı çerezleri kullanılacak." >&2
    elif [ -d "$HOME/.config/google-chrome" ]; then
      BROWSER="chrome"
      echo "ℹ️  Watch Later için 'chrome' tarayıcı çerezleri kullanılacak." >&2
    elif [ -d "$HOME/.config/BraveSoftware/Brave-Browser" ]; then
      BROWSER="brave"
      echo "ℹ️  Watch Later için 'brave' tarayıcı çerezleri kullanılacak." >&2
    else
      echo "⚠️  UYARI: Watch Later özel bir oynatma listesidir! Tarayıcı çerezi olmadan erişilemez." >&2
      echo "    Lütfen '--browser zen' veya '--browser firefox' gibi bir tarayıcı belirtin." >&2
    fi
  fi
fi

# yt-dlp argümanlarını inşa et
YTDLP_ARGS=()

# Browser çerez argümanını ayarla (Zen Browser Firefox çatalı uyumluluğu)
if [ -n "$BROWSER" ]; then
  case "$BROWSER" in
    zen)
      ZEN_PROFILE=$(find_zen_profile || true)
      if [ -n "$ZEN_PROFILE" ]; then
        echo "🔍 Zen Browser profili bulundu: $ZEN_PROFILE" >&2
        YTDLP_ARGS+=(--cookies-from-browser "firefox:$ZEN_PROFILE")
      else
        echo "⚠️  Zen profili (~/.zen) otomatik bulunamadı. Standart 'firefox' çerezleri deneniyor..." >&2
        YTDLP_ARGS+=(--cookies-from-browser "firefox")
      fi
      ;;
    zen:*)
      ZEN_CUSTOM_PATH="${BROWSER#zen:}"
      YTDLP_ARGS+=(--cookies-from-browser "firefox:$ZEN_CUSTOM_PATH")
      ;;
    *)
      YTDLP_ARGS+=(--cookies-from-browser "$BROWSER")
      ;;
  esac
fi

if [ -n "$COOKIES_FILE" ]; then
  YTDLP_ARGS+=(--cookies "$COOKIES_FILE")
fi

# Sadece linkleri listeleme modu (dump-urls)
if [ "$DUMP_URLS" = true ]; then
  YTDLP_ARGS+=(--flat-playlist --print webpage_url)
  if [ -n "$BATCH_FILE" ]; then
    YTDLP_ARGS+=(--batch-file "$BATCH_FILE")
    exec yt-dlp "${YTDLP_ARGS[@]}"
  else
    exec yt-dlp "${YTDLP_ARGS[@]}" "$TARGET"
  fi
fi

# YouTube n-challenge ve imza çözücü için JS runtime desteği (EJS)
if command -v node &>/dev/null || [ -x "/usr/bin/node" ]; then
  YTDLP_ARGS+=(--js-runtimes node --remote-components ejs:github)
elif command -v deno &>/dev/null || [ -x "$HOME/.deno/bin/deno" ]; then
  YTDLP_ARGS+=(--remote-components ejs:github)
fi

# Normal indirme parametreleri
mkdir -p "videos"
if [ "$USE_ARCHIVE" = true ]; then
  YTDLP_ARGS+=(--download-archive "$ARCHIVE_FILE")
fi

# Çerez kullanılıyorsa (örn. Watch Later), indirilen videoları YouTube'da "İzlendi" olarak işaretle
if [ -n "$BROWSER" ] || [ -n "$COOKIES_FILE" ]; then
  YTDLP_ARGS+=(--mark-watched)
fi

YTDLP_ARGS+=(
  -f "bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080]"
  --write-subs --write-auto-subs
  --sub-langs "$SUB_LANG"
  --convert-subs srt
  -o "videos/%(title)s [%(id)s]/%(title)s.%(ext)s"
)

if [ -n "$BATCH_FILE" ]; then
  echo "📂 Liste dosyasından indiriliyor: $BATCH_FILE"
  YTDLP_ARGS+=(--batch-file "$BATCH_FILE")
  exec yt-dlp "${YTDLP_ARGS[@]}"
else
  echo "🎬 Hedef indiriliyor: $TARGET"
  exec yt-dlp "${YTDLP_ARGS[@]}" "$TARGET"
fi
