---
name: skill-workshop
description: Workshop for building and revising this skill family. When the user pastes a When/Output/Constraints block, a numbered review, or says skill yap, create or patch a SKILL.md instead of running the scan. Triggers include skill yap, skill dosyasi olustur, bu chati skill yap, parcalara ayir, gerekli skillere ekle, When Output Constraints, v1.0 duzelt, Fit Score, routing priority.
user-invocable: false
metadata:
  type: workflow
  version: "1.6"
---

# Skill Workshop

This chat's method. Filter first, then write a skill. Do not dump a board unless the user asked to run the scan.

If the user pastes a new When / Output / Constraints block for this skill, replace those sections. Do not add fields they did not send.

## When

- "skill yap", "skill dosyası oluştur", "bu chati skill yap", "gerekli skillere ekle"
- A pasted Sources / Profile / Output / Constraints block meant as a reusable workflow
- A numbered review of an existing skill in this family
- A request to split a blob into separate skills

If the message is only "tara / başvurayım mı / yeni video", run the matching family skill. Do not open this workshop.

## Family

Do not invent a master scanner. Keep these roles.

- `media-runtime` — film / dizi / oyun runtime card
- `game-decision` — continue or drop a game. New mechanic inside 1-2 hours, otherwise drop. Not a runtime card.
- `channel-radar` — last 168 hours, long videos and lives, no Shorts
- `video-download` — pasted watch URL download + subtitles, one folder per video
- `hackathon-fit` — selective Fit Score cards
- `opportunity-scan` — open listing discovery, no marks
- `term-windows` — sparse official cycle / term / window
- `opportunity-verdict` — specific listing decision + weekly scholarship board
- `project-tutor` — project / portfolio / own-decision tutor, no marks
- `skill-author` — workflow skill text design, score, revise. Does not write the agent SKILL.md.
- `lecture-notes` — lecture paste → notes, one topic one page
- `design-page` — pasted Dribbble or Behance URL, short page card

If the request is only to design, score, or revise skill text without adding a family file, send it to `skill-author`.

Routing priority (copy into the career-family skills when editing them)

- Specific listing + decision question → `opportunity-verdict`
- Open opportunity discovery/list → `opportunity-scan`
- Sparse cycle / term date → `term-windows`
- Scholarship amount / trust / eligibility mark → `opportunity-verdict`
- Hackathon list → `opportunity-scan`; Fit Score → `hackathon-fit`
- Pasted watch URL + indir / subtitle → `video-download`; weekly yeni video → `channel-radar`
- Pasted dribbble.com or behance.net URL → `design-page`
- Continue / drop / grind / card-table mechanic → `game-decision`. Bare title or süre → `media-runtime`

## Workflow

1. Decide create vs patch vs split. Overlapping drafts — ask short questions before writing files.
2. A full older body pasted beside other skills is not a replace order. Keep the live file when it already has a later output shape, report path, source list, or uymaz/archive rule. Apply only a rule the live file lacks. Say which files stayed.
3. Do not execute the pasted scan as a one-shot unless the user said run it now.
4. New skill — create `skills/<name>/SKILL.md` in this repo. On a Grok install, the same file lives at `$GROK_HOME/skills/<name>/SKILL.md` (if GROK_HOME is unset, `~/.grok/skills/<name>/SKILL.md`).
5. Patch — edit the existing file, bump `metadata.version`.
6. Shared rules to keep unless the user overrides them
   - Official page is the card source. Index URLs are search starts only.
   - Never invent a date, amount, runtime, handle, or URL. Missing → `Veri bulunamadı` / `aciklanmamis` / `url bulunamadi`.
   - Never infer eligibility from the title alone.
   - List skills do not use ✅/⚠️/❌ and do not say skip for apply/skip. Use `erisilemedi`, `login gerekli`, `exclude`.
   - Do not add output fields the user did not send.
   - Result language matches the user. Field labels stay as in the Output block.
   - Personal profile, channel lists, recorded calls, and filled report history stay outside the published skill. Do not commit them.
7. Description YAML — one line, no quotes, no `: `, no `<>`.
8. YAML check — name is lowercase-hyphen, description is one line, no quotes, no `: `, no `<>`. Read the file back. Skills auto-reload. Do not require init-skill.sh or validate-skill.sh.
9. Reply short. What changed, version, file. No lecture.

## Review patches

When the user sends numbered critique, apply only those points. Typical ones already settled

- Fit Score buckets, no prize points
- Source as citation / official page, not aggregator URL
- Window as 7 × 24 hours when the skill is a weekly video radar
- Trust = application channel, amount = official figure only
- Gender or age only when the official page states the rule

Do not add a new family skill for cloud implementation or a deep scholarship catalog unless the user asks again.

## Constraints

- One concern per skill. Split rather than merge incompatible outputs.
- Empty extra folders (`scripts/`, `references/`, `assets/`) may remain from init. Do not invent reference catalogs the user did not supply.
- This skill only writes and patches skills. It does not mark apply/skip and it does not scan listings.
- Do not put a legal name, school, graduation date, home city, family city, calendar project, membership, or machine path into a published skill.
