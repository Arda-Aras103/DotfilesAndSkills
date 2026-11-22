---
name: channel-radar
description: Weekly video radar for a user-supplied channel list. Check the previous 168 hours for long videos and live streams, skip Shorts and members-only, then write one-line title cards with channel, ISO date, and link. Channels with no new video collapse to one comma line. Triggers include youtube, kanal, yeni video, weekly youtube, no new video, or a YouTube Sources/Output/Constraints block. Not for indir or subtitle download.
user-invocable: true
metadata:
  type: workflow
  version: "1.8"
---

# Channel Radar

Weekly YouTube channel check (previous `7 × 24 hours`) for long-form videos and live streams, saved to `reports/youtube.md`.

## When

The user asks for new videos, a channel check, a weekly video pass, or pastes a channel list / `Sources / Output / Constraints` block.

## Sources

No channel list ships with this skill; use the list supplied by the user in order (`Display Name — https://www.youtube.com/@handle`). If empty, ask once and do not invent handles.

Always verify each candidate on its official YouTube watch page. If web scraping hits anti-bot challenges, use YouTube's official RSS feed (`https://www.youtube.com/feeds/videos.xml?channel_id=CHANNEL_ID`) or run [scripts/fetch_feed.sh](./scripts/fetch_feed.sh) `<CHANNEL_ID>`.

## Workflow

1. Compute the `7 × 24 hours` window ending at the current timestamp.
2. Process channels in supplied list order.
3. Keep only regular long-form videos, active live streams, and completed live-stream replays published within the window (`YYYY-MM-DD`).
4. Drop all Shorts (regardless of URL format), members-only/subscriber-only items, and older items.
5. Group channels with zero qualifying videos into one comma-separated line in source-list order. For channels with multiple qualifying videos, list newest first within that channel.

## Output & File

Write to `reports/youtube.md` (do not create dated filenames; also match this format in chat). On a new scan date, prepend today's `## YYYY-MM-DD` section above previous sections; on the same date, replace today's section and keep older sections:

```markdown
# YouTube

Kart başlık, kanal, tarih ve link. Yeni videosu olmayan kanallar tek satır. Açıklama cümlesi yok.

## YYYY-MM-DD
- [Title](https://www.youtube.com/watch?v=VIDEO_ID) — Channel — YYYY-MM-DD

Yeni video yok: Channel A, Channel B, Channel C
```

Match channel names containing ` - ` against the longest name from the source list without splitting on the hyphen.

## Constraints

- No summaries, explanation sentences, per-channel empty blocks, tables, or extra fields.
- Never invent titles, video IDs, dates, or links; missing field -> `Veri bulunamadı`.
- This skill only writes video cards—it does not download `.mp4`/`.srt` files.
