---
name: improve-codebase-architecture
description: Surveys a codebase for shallow modules and proposes deep-module refactors with a read-only report before any code edits. Triggers include mimari incele, improve architecture, shallow module, deep module, codebase refactor survey, teknik borc tara, modul sadelestirme.
user-invocable: true
metadata:
  type: workflow
  version: "1.1"
---

# Improve Codebase Architecture

Read-only architectural survey that spots shallow modules and proposes high-leverage deep-module consolidations.

## When

- User asks to review module boundaries, simplify a growing codebase, or find refactoring candidates (`mimari incele`, `improve architecture`, `shallow module`, `deep module`, `teknik borç tara`).
- Run before major feature work on `/workspace/projects/` or any multi-file repository.

## Workflow

1. **Scope & Activity Hotspots:**
   - Identify source roots and check recent `git log -n 20 --stat` (when in a Git repo) so refactoring candidates prioritize actively changing paths over dead code.
2. **Shallow-Module Survey & Deletion Test:**
   - Look for wrappers, fragmented helpers, or thin pass-through layers whose interface is nearly as complex as their implementation.
   - Apply the **Deletion Test**: keep only candidates where merging or hiding complexity behind a smaller boundary clearly simplifies callers (turning shallow wrappers into deep modules).
3. **Write Read-Only Report:**
   - Save a clean report (Markdown or self-contained HTML with Mermaid boundary diagrams) under `/tmp/arch-survey-<repo>.md` (or `.html`)—never cluttering the project root.
   - Rank candidates into three tiers: `Strong`, `Worth exploring`, and `Speculative`, noting exact file paths and current vs proposed interfaces.
4. **Interactive Decision Gate:**
   - Summarize the top candidates concisely and let the user pick one (using `/grill-me` or direct discussion) before modifying any source file.

## Output

```markdown
# Mimari Tarama: <repo-name>
Rapor: /tmp/arch-survey-<repo>.md

## Strong
1. **<Candidate Name>** (`file1`, `file2`) — Current boundary vs proposed deep interface (1-2 sentences).

## Worth exploring
- ...

## Speculative
- ...
```

## Constraints

- Strictly read-only during the survey; never edit production code or commit changes without explicit user confirmation.
- Cite only file paths, symbols, and git stats verified in the current session.
- Never include personal PII or local machine secrets in shared architecture reports.
