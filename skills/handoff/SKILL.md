---
name: handoff
description: Compacts current session state, verified facts, open blockers, and next commands into a portable Markdown handoff note for a fresh agent. Triggers include handoff, oturumu devret, yeni ajana aktar, baglam devri, context handoff, kaldigimiz yerden.
user-invocable: true
metadata:
  type: workflow
  version: "1.2"
---

# Handoff

Creates a high-signal, zero-secret Markdown handoff note so a fresh agent session can resume cold without losing verified state.

## When

- Session context is long or switching to a fresh agent/subagent (`handoff`, `oturumu devret`, `yeni ajana aktar`, `bağlam devri`, `kaldığımız yerden`).

## Workflow

1. **Inspect Current State:** Review active tasks, edited files, and recently run test/build commands in the current session.
2. **Verify vs Separate Assumptions:** Tag items strictly as **Verified** (directly observed file paths, symbols, command outputs in this session) vs **Open / Unverified** (pending checks or next steps).
3. **Reference, Do Not Duplicate:** Point to exact file paths, line ranges, plans, or artifact URIs instead of pasting large code blocks.
4. **Redact Secrets & PII:** Strip API keys, `.env` values, tokens, passwords, and unnecessary personal PII.
5. **Write Portable Note:** Save to `/tmp/handoff-<slug>.md` (or the conversation scratch directory) so it never pollutes the Git working tree, then print a ready-to-paste starter prompt in chat.
6. **Promote Durable Knowledge (0–3 bullets max):** When a lasting architecture/career decision or working preference emerged, append 1–3 dated bullets to `/workspace/context/prefs-and-decisions.md` (keep file `<= 50` lines; never copy raw session logs).

## Output

```markdown
# Handoff: <task-title>
Dosya: /tmp/handoff-<slug>.md

## Starter Prompt (Yeni Oturuma Yapıştır)
Read /tmp/handoff-<slug>.md and resume from Next Step 1.
```

## Constraints

- Never store secrets, tokens, or raw `.env` contents in handoff notes.
- Never claim tests or builds pass unless directly observed after the final edit in this session.
- Keep the workspace root clean; never leave temporary handoff files untracked in project directories.
