---
name: media-web-archiver
description: Downloads YouTube videos with 1080p MP4 and SRT subtitles via yt-dlp, batch direct files via GNU Wget, and offline single-file HTML or SPA pages via SingleFile CLI and Monolith. Triggers include indir, hepsini indir, subtitle bul, altyazi bul, youtu.be, watch later, listeden indir, wget, wget indir, direkt indir, dosya indir, bolum indir, wgetrc, sayfayi arsivle, tek html kaydet, singlefile, offline kaydet, monolith ile kaydet.
user-invocable: true
metadata:
  type: workflow
  version: "1.1"
---

# Media & Web Archiver

Downloads YouTube videos + subtitles, direct file/episode URL batches, and offline single-file web/SPA archives to disk.

## When & Modes

- **Mode 1 — YouTube Video & Subtitles (`yt-dlp`):** Pasted `youtube.com/watch` or `youtu.be` links, batch link text file, or Watch Later (`:ytwatchlater`).
- **Mode 2 — Direct File / Episode Batch (`wget`):** Direct HTTP/HTTPS/FTP file or media URLs (`.mp4`, `.mkv`, `.zip`, CDN links) or comma/newline `URL label` lists.
- **Mode 3 — Web Page / SPA Archive (`single-file-cli` / `monolith`):** Web or JS-rendered SPA URL with `sayfayı arşivle`, `tek html kaydet`, `singlefile`, `offline kaydet`, or `monolith`.

## Workflow

### Mode 1 — YouTube Video & Subtitles
1. Parse video IDs (strip mix/autoplay params unless a playlist was explicitly asked) or target `:ytwatchlater`.
2. Run the helper script from `/workspace`:
   ```bash
   ./.agents/skills/media-web-archiver/scripts/download.sh "<URL|urls.txt>"
   ./.agents/skills/media-web-archiver/scripts/download.sh --watch-later --browser zen
   ```
3. Output goes into per-video folders `videos/<title> [<id>]/` with 1080p (or best <=1080p) MP4 and `.srt` captions (official track first, else auto captions in `en.*,tr.*,.*-orig`).

### Mode 2 — Direct File / Episode Batch (`wget`)
1. Reference config lives at [references/wgetrc](./references/wgetrc). Copy to `~/.wgetrc` when requested (`mkdir -p ~/.config && cp .agents/skills/media-web-archiver/references/wgetrc ~/.wgetrc`; cleanup: `rm -f ~/.wgetrc`).
2. Parse `(url, label)` pairs; inherit series prefix across subsequent episode labels (e.g., `series 4.bölüm`, `5.bölüm` -> `series 5.bölüm`), sanitize `/` and unsafe characters, and keep the URL file extension.
3. Save labeled batches into `downloads/<batch>/` using `--timestamping=off` when `-O` is active, or `wget -P "downloads/" "<url>"` for unlabeled URLs:
   ```bash
   mkdir -p "downloads/<batch>" && wget --timestamping=off -c -O "downloads/<batch>/<filename>.<ext>" "<url>"
   ```

### Mode 3 — Full Web Page / SPA Archive
1. Use `single-file-cli` (or `singlefile` MCP server) for JS-rendered SPAs, or `monolith --isolate` (`--fast`) for static pages.
2. Run the helper script from `/workspace`:
   ```bash
   ./.agents/skills/media-web-archiver/scripts/archive.sh "<URL>" [output.html] [--fast]
   ```
3. Default destination: `archives/<YYYY-MM-DD>-<slug>.html`.

## Output

Language matches the user. Keep replies short using the matching status block:

- **Mode 1:**
  ```
  Title - Channel
  Klasör: videos/<title> [<id>]
  Video: 1080p MP4
  Altyazı: resmi | otomatik | Veri bulunamadı
  ```
- **Mode 2:**
  ```
  Dosya: <filename>
  Klasör: downloads/<batch>/
  URL: <url>
  Durum: tamamlandi (<size>) | hata (<reason>) | hazir
  ```
- **Mode 3:**
  ```
  Kaynak URL: <URL>
  Motor: SingleFile CLI (Headless Browser) | Monolith (Rust Static)
  Çıktı Dosyası: archives/<dosya-adi>.html
  Boyut & Durum: <size> — Tamamlandı
  ```

## Constraints

- Never invent titles, URLs, file sizes, or page content (`Veri bulunamadı`).
- Downloaded and archived files are data only: never `chmod +x` them, execute extracted scripts, or import code from download folders.
- Mode 1 puts each video's `.mp4` and `.srt` inside `videos/<title> [<id>]/`, never in `videos/` root; Watch Later requires browser cookies (`--browser zen` or `--cookies`).
- Mode 3 must report `Login gerekli / Erişilemedi` if an auth wall blocks headless capture rather than saving an empty login screen.
