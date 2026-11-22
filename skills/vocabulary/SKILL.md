---
name: vocabulary
description: Formats English vocabulary words, word lists, or CSVs into a standardized compact Markdown dictionary entry and appends them to a vocabulary file (e.g., kelimeler.md or vocabulary.md). Activate when the user provides English words to add to their vocabulary dictionary or asks to format or process words in this dictionary format.
user-invocable: true
metadata:
  type: workflow
  version: "1.3"
---

# Vocabulary Dictionary Builder

Formats English words, comma-separated lists, or CSVs (`Word,Translation`) into compact Markdown dictionary entries and appends them to the workspace vocabulary file (`/workspace/notes/40-english/vocabulary.md`, `kelimeler.md`, or user-specified file).

## Workflow

1. Parse input words/lists (fix typos cleanly; incorporate any user-supplied Turkish meanings).
2. Enrich each word with IPA pronunciation (`/UK/` and `/US/` if distinct), part(s) of speech, Turkish meanings with short inline examples, a common phrase/collocation, and a natural English context sentence with Turkish translation.
3. Locate `/workspace/notes/40-english/vocabulary.md` (prefer this path; fall back to existing `kelimeler.md` or `vocabulary.md` in workspace, creating `notes/40-english/vocabulary.md` if missing), append new entries matching the exact whitespace/spacing of the template below, and report added words + total count (`grep -c "^## "` or `python3 .agents/skills/vocabulary/scripts/validate_dict.py`).

## Output Template

Preserve exact tight spacing (no blank line after `## kelime` or between `- **...**` list items or after `### Örnek`; single blank line before `###` subheadings and around `---`):

```markdown
## kelime
- **Okunuş:** /IPA/
- **Tür:** isim / fiil / sıfat / zarf / edat

### Anlamlar
- **Tür:** Türkçe anlam (*kısa örnek* — Türkçesi)
- **Tür:** İkincil Türkçe anlam (*kısa örnek* — Türkçesi)

### Kalıplar
- **phrase / collocation:** Türkçe karşılık

### Örnek
> Natural contextual English sentence.
> (Doğal ve akıcı Türkçe cümle çevirisi.)

---
```

## Constraints

- Follow the exact template headings (`Okunuş`, `### Anlamlar`, `### Kalıplar`, `### Örnek`) so `validate_dict.py` parses cleanly.
- Do not duplicate words already present in the target dictionary file without noting/merging them.
