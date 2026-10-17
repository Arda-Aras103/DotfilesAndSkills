---
name: skill-author
description: Designs, scores, and revises workflow skill text from a rough idea or a pasted skill body. Triggers include skill olustur, skill yaz, workflow skill yap, skill degerlendir, skill duzelt, ChatGPT skill.
user-invocable: false
metadata:
  type: workflow
  version: "1.0"
---

# Skill Author

Design, score, and revise workflow skill text. One job: a skill body someone can apply.

Writing or patching this family's `SKILL.md` belongs to `skill-workshop`. Listing scans, scholarship marks, hackathon cards, media cards, video radar, and tutor talk stay in their own skills.

If the user pastes a new When / Output / Constraints block for this skill, replace those sections only. Do not add a field they did not send.

## Routing

- Rough idea, rules, or a workflow → design skill text
- An existing skill was pasted and the user wants a fix → revise it and keep its shape
- Score, rate, or evaluate → score it. Give the full text only if they asked
- `skill yap`, `skill dosyası oluştur`, `gerekli skillere ekle`, `skill olarak ekle` → `skill-workshop`
- The user wants the skill to run → do not design it. Use the matching skill

## When

Run on requests like these:

- "Bana bir skill oluştur"
- "Bunun için skill yaz"
- "Bu workflow'u skill yap"
- "Bu skill'i düzelt"
- "Skill'i değerlendir"
- "Bu kuralları bir skill'e dönüştür"
- "Yeni bir skill lazım"

If the user gives raw notes about a topic, a goal, or a workflow, turn that into a skill design.

If information is missing, ask only for a gap that would change behavior. Do not ask about a small detail. State a reasonable assumption.

"tara / başvurayım mı / yeni video / tutor ol" alone is not this skill.

## Workflow

1. Classify the request: create, revise, or evaluate. If they want a family file on disk, stop and use `skill-workshop`.
2. Write one main job. Do not merge discovery, decision, automation, content, and evaluation in the same skill. If that job already has a skill, point at it in Routing. Do not redefine it.
3. Use real user phrases in `When`. Do not write a trigger that matches everything.
4. Add `Sources` only when the job needs them. Keep search starts separate from the final or official source. Say when the official source is required. Do not invent a fact from a page that did not open. Do not present a third party as official. Skip `Sources` when the job needs none. Add `Profile` only when it changes behavior.
5. Write the workflow as ordered steps someone can follow. Do not assume a behavior that is not in the workflow.
6. Keep Output deterministic. Do not add a field they did not want. Missing data:
   - `belirsiz`
   - no URL → `url bulunamadi`
   - empty section → `bu ay yok`
7. Write what the skill will not do under Constraints.
8. Check before delivery: one job, clear trigger, overlap, who decides, sources, output, missing data, repetition, unwanted new behavior. When two rules conflict, keep the more specific one.

Revise

1. Keep the current purpose.
2. Check routing, overlapping rules, conflicting constraints, and repetition.
3. Keep the user's output format when you can.
4. Change only what is needed. Bump the version.
5. Do not change the architecture unless the user asked.
6. If they sent only some sections, leave the others alone.

Evaluate on trigger scope, routing clarity, workflow determinism, source reliability, output clarity, constraint consistency, and overlap with other skills. Score out of 100. A score is not enough. Name the important problems and the smallest fix.

## Output

Chat in the user's language. Skill text in the user's language. If they did not name one, use the language of the paste.

Create or revise — the full skill, one code block. Do not put commentary inside the block.

Required sections:

1. `name`
2. `description`
3. `metadata`
4. Main purpose
5. `Routing`
6. `When`
7. `Workflow`
8. `Output`
9. `Constraints`

Add `Sources` and `Profile` only when needed. Do not add an empty section.

Evaluation

```
Puan: X/100
Trigger:
Routing:
Workflow:
Source:
Output:
Constraint:
Overlap:
Sorunlar:
Minimum düzeltme:
```

If the user did not ask for the full text, do not dump the skill in an evaluation.

Short delivery. Direct, technical, plain language. No buzzwords.

## Constraints

- One main job. Keep it small and complete.
- Do not take another skill's job. Leave the decision with the skill that owns it.
- Do not decide for the user, invent data, or state an unverified fact as certain.
- No long analysis. No extra constraint. Do not repeat the same rule.
- Do not write or patch the family `SKILL.md`. Do not mark listings. Do not scan boards.
- Do not add a field the user did not send.
- Do not put a legal name, school, graduation date, home city, or machine path into skill text meant for a public repo.
