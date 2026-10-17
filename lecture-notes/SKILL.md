---
name: lecture-notes
description: Turns pasted course or lecture transcripts into notes. Same topic stays on one page under subheadings. Triggers include kurs not, obsidian not, lecture paste, ozetler misin with a transcript.
user-invocable: false
metadata:
  type: workflow
  version: "1.0"
---

# Lecture Notes

Pasted course or lecture transcripts become notes. One topic, one page, `##` subheadings. Chat in the user's language. Note body in the language of the lecture.

If the user pastes a new When / Output / Constraints block for this skill, replace those sections. Do not add fields they did not send.

A job, intern, scholarship, or program link goes to `opportunity-verdict`. Weekly boards go to `opportunity-scan`. Skill text design without a family file goes to `skill-author`. Family `SKILL.md` create or patch goes to `skill-workshop`.

## When

- The user pastes a course or training transcript
- "kurs not", "obsidian not", or "aynı şekilde devam et" with lecture text
- "özetler misin" on a lecture transcript, not on a job listing

Not this skill: apply or skip, a board scan, video radar, a media runtime card, tutor talk, or skill text with no notes file.

## Workflow

1. Skip trainer bio, support email, feedback, and "content may be outdated" marketing. Keep the technical lecture.
2. Find the topic. Same topic as an existing page under `notes/` → edit that page. New course series → an index page plus topic pages. Do not open a new file for a demo, a recap, or a heading that belongs on an existing topic.
3. Merge under `##` on the topic page. A demo is `## DEMO` (or `## DEMO — …`) on the same page. A course recap is `## Course Summary` on the index, not a third file.
4. Write only what the lecture said. Do not add product facts that were not in the paste. If a service is shut down or an exam is retired, one warning line is allowed.
5. Style: `#` title, nested `-` bullets, `###` when needed, mermaid for flows, fenced JSON only when the lecture shows a policy or a query. No YAML frontmatter. No empty stub pages.
6. Link sibling topic pages from the index. Do not link a demo as its own note.
7. Default vault: workspace `notes/`. Chat names the file that changed. Stay short.
8. Keep a topic map for the active course: one index page, plus one page per service or object. A new course gets a new index and topic pages named after the service or object, then follows the same merge rule. Do not commit a filled personal map in the published skill.

## Output

Note body in the lecture language. Chat is one short line: which file, what heading.

## Constraints

- One topic = one page. The same topic does not get a second file.
- Do not invent lecture content, console clicks, limits, or identifiers that were not in the paste.
- Do not keep a trainer bio, a support email, or a feedback ask.
- Do not mark apply or skip. Do not scan boards.
- Do not write a family `SKILL.md` from this skill.
