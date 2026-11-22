---
name: inbox-triage
description: Triages dropped videos, screenshots, GitHub repos, links, and notes/00-inbox.md against user profile and architectural prefs, then routes keepers to reports, Obsidian notes, or skills and cleans processed clutter. Triggers include videolari yorumla, videoya bak, fotolara bak, ekran goruntusu incele, inbox temizle, inbox.md bak, toplu incele, neleri alabiliriz, ne ekleyelim, linkleri yorumla.
user-invocable: true
metadata:
  type: workflow
  version: "1.0"
---

# Inbox Triage & Media Routing

Reviews dropped videos, root screenshots, links, and `notes/00-inbox.md` with critical Keep/Skip verdicts, routes keepers to workspace SSOTs, and cleans processed clutter.

## When

Use when reviewing dropped YouTube video dirs, root PNGs, repo/social links, or `notes/00-inbox.md` for triage and cleanup.

## Workflow

1. **Discover & Context:** Run `python3 ./.agents/skills/inbox-triage/scripts/scan_inbox.py` and read `/workspace/profile.md` + `/workspace/context/prefs-and-decisions.md`.
2. **Inspect Evidence (Read-Only):** Read full `.srt` subtitles (never judge by title), view every root PNG with `read_file` (grouping sequential carousels), and verify repos/deadlines on official domains. Delegate mixed batches of 4+ items across parallel read-only subagents when helpful.
3. **Propose Before Editing:** Output categorized verdicts and proposed destinations; wait for confirmation unless the user already approved edits/cleanup.
4. **Route, Mirror & Clean:** Update approved targets (`reports/applications.md` via `application-tracker`, future windows in `reports/career.md`, deferred tools in `reports/backlog.md`, reusable techniques in `.agents/skills/*/SKILL.md`, durable notes in `notes/`), sync matching `notes/workspace-reports/` mirrors, clear `notes/00-inbox.md` below `<!-- Yakalama -->`, delete only confirmed processed PNGs/video dirs, and verify with `ls -la /workspace` + `sha256sum`.

## Output

Concise Turkish verdict tables (`İzle / Hızlı Göz At / Özet Yeter` for videos; `Kur / Backlog / Geç` for tools/repos; `Başvur / Shaky / Geç` for listings) with clickable `file://` links, ending with a brief apply/cleanup offer.

## Constraints

- Never bypass login walls or anti-bot gates (`Doğrulanamadı / Geç`).
- Never delete unapproved files or non-media workspace docs, and never overwrite diverged `notes/workspace-reports/` files without checking `sha256sum` first.
- Keep zero PII in reusable outputs.
