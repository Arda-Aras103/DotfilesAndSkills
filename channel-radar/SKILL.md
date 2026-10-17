---
name: channel-radar
description: Weekly video radar for a user-supplied channel list. Check the previous 168 hours for long videos and live streams, skip Shorts and members-only, then write one-line title cards with channel, ISO date, and link. Channels with no new video collapse to one comma line. Triggers include youtube, kanal, yeni video, weekly youtube, no new video, or a YouTube Sources/Output/Constraints block. Not for indir or subtitle download.
user-invocable: false
metadata:
  type: workflow
  version: "1.6"
---

# Channel Radar

Weekly channel check. Previous 7 × 24 hours only. Long-form videos and live streams. No Shorts. No members-only. No summary. No explanation sentence.

If the user pastes a new When / Output / Constraints block for this skill, replace those sections. Keep the 7 × 24 hour window, watch-page verification, no-Shorts, no-members, and no-invention rules unless they override them. Do not add fields they did not send.

## When

The user asks for new videos, a channel check, a weekly video pass, or pastes a Sources / Output / Constraints block.

Pasted watch or youtu.be links plus indir, hepsini indir, subtitle bul, or altyazi bul → `video-download`. Do not download files here.

## Sources

No channel list ships with this skill. The user supplies the list, in order. Each line is a display name and the official channel URL.

- Display Name — https://www.youtube.com/@handle

If the list is empty, ask once. Do not invent handles. If the user sends a new list, use that list instead.

The channel list is a search starting point, not evidence that a video exists.

Always verify each video on its official YouTube watch page. If the official watch page cannot be opened and verified, do not create a card for that item.

## Workflow

1. Use the current date and time. Window is the previous 7 × 24 hours, including the current moment.
2. Process channels in list order.
3. Open the official channel videos and streams pages and verify each candidate on its official YouTube watch page.
4. Keep only:
   - regular long-form videos
   - live streams currently live
   - completed live-stream replays published within the window
5. Drop:
   - Shorts, including items the platform identifies as Shorts regardless of URL format
   - members-only or subscriber-only items
   - items outside the 7 × 24 hour window
6. Do not write a summary. Do not write an explanation sentence.
7. Never invent a title, video ID, date, or link.
8. For live streams, use the official published or start date. Write that date as `YYYY-MM-DD`.
9. If a channel has no qualifying video in the window, add its display name to one comma line. Do not write a separate block for that channel.
10. If a channel has several qualifying videos, write one line per video, newest first. Keep channels in source-list order.

## Output

One line per qualifying video. Channels stay in source-list order. Inside a channel, newest first.

```
- [Title](https://www.youtube.com/watch?v=VIDEO_ID) — Channel — YYYY-MM-DD
```

Channel names can contain ` - `. Match the longest channel name from the source list. Do not split those names on the hyphen.

Channels with no qualifying video in the window become one line, in source-list order, after the cards.

```
Yeni video yok: Channel A, Channel B, Channel C
```

No explanation sentence. No per-channel empty block. No table. No extra fields.

## Dosya

Write the scan to `reports/youtube.md` in the workspace.

Do not create a dated filename.

Read the file first. Keep this header.

```
# YouTube

Kart başlık, kanal, tarih ve link. Yeni videosu olmayan kanallar tek satır. Açıklama cümlesi yok.
```

The current scan is the first `## YYYY-MM-DD` section. On a new scan date, leave the previous section in the file under today's section, newest date first, and write today's section at the top. On the same date, replace today's section and leave older date sections. Do not drop archive videos. An older section does not override today's scan.

If the board is also shown in chat, use this same shape.

## Constraints

- Once in 7 days. Only videos and live streams inside the previous 7 × 24 hours.
- Just long-form videos and live streams.
- Not Shorts. Not members-only. Drop an item if the platform identifies it as a Short, regardless of URL format.
- Do not write a summary. Do not write an explanation sentence.
- Channels with no new qualifying video collapse to one comma line, `Yeni video yok: A, B, C`, in source-list order.
- Several qualifying videos are one line each, in the Output format.
- Found data — type it. Missing field — `Veri bulunamadı`. Do not invent titles, dates, or links.
- The title is a markdown link to the verified watch page. Do not invent a video id.
- Do not commit a personal channel list into the published skill.
- This skill only writes video cards. It does not download files, does not folder mp4 or srt, and it does not mark apply or skip.
