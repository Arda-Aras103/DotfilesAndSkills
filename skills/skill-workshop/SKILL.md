---
name: skill-workshop
description: Designs, evaluates, creates, and patches workspace SKILL.md files from rough workflow ideas or When Output Constraints blocks. Triggers include skill yap, skill olustur, skill yaz, skill dosyasi olustur, bu chati skill yap, parcalara ayir, gerekli skillere ekle, skill degerlendir, skill duzelt, When Output Constraints.
user-invocable: false
metadata:
  type: workflow
  version: "2.3"
---

# Skill Workshop

Designs, evaluates, creates, and patches `/workspace/.agents/skills/<name>/SKILL.md` files.

## When

- Designing or creating a new skill (`skill yap`, `skill oluştur`, `skill yaz`, `skill dosyası oluştur`).
- Revising or splitting an existing skill from a `When / Output / Constraints` block or numbered critique.
- Evaluating/scoring a skill (`skill değerlendir`).

If the user asks to execute an existing workflow (e.g., scan listings, check attendance), run that skill instead—do not open this workshop.

## Workflow

1. **Classify Request:**
   - **Create / Patch on Disk:** Write or edit `/workspace/.agents/skills/<name>/SKILL.md`. On patches, bump `metadata.version` and keep live rules/paths the user did not ask to replace.
   - **Design in Chat:** Output one clean code block without commentary inside the block.
   - **Evaluate:** Score out of 100 (`Puan: X/100` across Trigger, Workflow, Source, Output, Constraint, Overlap), name real issues, and give the smallest fix.
2. **Design Minimal & Deterministic Rules:**
   - **One main job per skill:** Split incompatible workflows; check `/workspace/.agents/rules/AGENTS.md` to avoid duplicating existing skills.
   - **Context budget ("Delete, don't explain"):** Cut general knowledge models already know and non-essential rationale; every always-loaded word costs context on every turn.
   - **Sharp pointers & one trigger per branch:** Front-load active trigger phrasing in `description`; keep one trigger per distinct branch and collapse synonyms.
   - **No anti-pattern priming & single source of truth:** Never embed prohibited code/output examples inline (they prime emission), and never repeat a rule across multiple sections.
   - **4-part structure:** `When`, `Workflow` (ordered steps; add `Sources`/`Profile` only if needed), `Output` (exact template, no unrequested fields), and `Constraints` (only non-obvious boundaries—do not repeat Workflow steps).
   - **No invention:** Missing data uses `Veri bulunamadı`, `belirsiz`, or `url bulunamadi`. Official pages are primary card sources; aggregators are search starts only.
   - **UI / Frontend Skills (`hallmark` / `impeccable` Anti-Slop Check):** Require explicit design tokens (palette, typography, spacing, states) and reject generic AI-slop defaults (stock purple gradients, boilerplate card grids, decorative clutter).
3. **YAML, Doctor & Readback Check:**
   - `name`: lowercase-hyphen.
   - `description`: **one single line**, no quotes (`"` / `'`), no `: `, no `<>`.
   - Run `python3 /workspace/scripts/agent_doctor.py audit-security` and `python3 /workspace/scripts/agent_doctor.py audit-tokens` after disk edits to confirm 100/100 security hygiene, context budget (<100 lines / <2500 chars), and zero duplicate triggers.
   - Read back the saved `SKILL.md` to verify formatting. Keep replies short (what changed, version, file path).

## Constraints

- Never commit personal PII (legal name, school, graduation date, home city, or machine-specific `/home/<user>` paths) inside reusable skill templates.
- Do not execute a scan or apply/skip check when only asked to create or patch a skill.
- Follow **Judgment = Agent, Determinism = Script (`scripts/`)**: keep skill prompts focused on judgment calls and offload deterministic validation, parsing, or batch/table updates to zero-token helper scripts under `scripts/`.
