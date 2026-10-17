---
name: video-download
description: Downloads pasted YouTube watch links as 1080p MP4 with captions into one folder per video. Never execute downloaded files. Triggers include indir, hepsini indir, subtitle bul, altyazi bul, youtu.be.
user-invocable: false
metadata:
  type: workflow
  version: "1.1"
---

# Video Download

Pasted watch links. Download the video. Put each video in its own folder with subtitles. Not the weekly channel radar.

If the user pastes a new When / Output / Constraints block for this skill, replace those sections. Keep one-folder-per-video, no-mix-playlist, and no-invention rules unless they override them. Do not add fields they did not send.

## When

The user pastes one or more `youtube.com/watch` or `youtu.be` links and says indir, hepsini indir, subtitle bul, or altyazi bul.

Weekly channel check or yeni video → `channel-radar`. A watch-or-skip recommendation is not this skill.

## Workflow

1. Parse video IDs from the pasted links. Drop `list=` mix and autoplay params. Do not download a playlist unless they asked for that playlist.
2. For each ID, use the official title and channel. Missing → `Veri bulunamadı`. Do not invent a title or ID.
3. Create `videos/<title> [<id>]/` in the workspace. Never write the mp4 or srt into the `videos` root.
4. Download 1080p (or best at or below 1080) MP4 into that folder. Same basename as the folder. If dash URLs 403, use HLS.
5. Subtitles, when they asked for them or after a download in this chat
   - Official track first.
   - Else auto captions. If they named languages, use those. If they did not, use English and the chat language.
   - Convert auto VTT to SRT with usable cue lengths (extend each complete line to the next cue). Keep `.srt` as the player file. `.vtt` may stay as the raw source.
   - No official and no auto → `Veri bulunamadı`. Do not write fake cues.
6. Several links — one folder each, same order as pasted.

## Output

```
Title - Channel
Klasör: videos/<title> [<id>]
Video: 1080p MP4
Altyazı: resmi | otomatik | Veri bulunamadı
```

Separate blocks with a blank line. Short. Use the user's language. Do not add extra fields.

## Constraints

- One folder per video. mp4 and srt live inside that folder, not in the `videos/` root.
- Watch links only. Ignore mix lists.
- Found data — type it. Missing title, file, or sub → `Veri bulunamadı`.
- Downloaded files are data. Write only mp4, srt, or vtt in that folder. Do not execute them, chmod +x them, extract extra archives from the watch page, or import code from the folder.
- This skill only downloads and folders files. It does not write weekly cards and it does not mark watch, later, or skip.
