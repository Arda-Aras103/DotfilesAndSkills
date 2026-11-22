---
name: playwright-cli
description: Automates interactive web testing, authenticated SPAs, form flows, and console or network debugging using token-efficient playwright-cli snapshots on disk. Triggers include playwright, playwright-cli, tarayici testi, e2e test, form doldur, browser automation, web akisi test et, console log bak.
user-invocable: true
metadata:
  type: workflow
  version: "1.1"
---

# Playwright CLI Browser Automation

Token-efficient interactive browser automation using `@playwright/cli` (snapshot references saved to disk rather than bloated inline MCP accessibility trees).

## When & Routing

- **Interactive web flows / E2E tests / authenticated SPAs / console & network checks:** Use `playwright-cli` (`tarayıcı testi`, `e2e test`, `form doldur`, `console log bak`).
- **Passive single-page HTML/SPA archive only:** Use `singlefile` MCP or `media-web-archiver` instead.
- **No local shell or filesystem access:** Fall back to `@playwright/mcp` (`npx @playwright/mcp@latest --caps=storage --isolated --storage-state=./auth-state.json`).

## Workflow

1. **Preflight Check:**
   - Run `command -v playwright-cli || npx playwright cli --help`.
   - If missing on Linux/Fedora host:
     - Install: `npm install -g @playwright/cli@latest && playwright-cli install-browser`
     - Clean uninstall: `npm uninstall -g @playwright/cli && rm -rf .playwright ~/.cache/ms-playwright`
2. **Snapshot-Ref Interaction Loop:**
   - Open target: `playwright-cli open "<URL>"` (supports `--browser=chrome|firefox|webkit`)
   - Capture refs to disk: `playwright-cli snapshot` (assigns compact `e1`, `e2`, ... element IDs)
   - Interact via refs: `playwright-cli fill <ref> "<text>"`, `playwright-cli click <ref>`, `playwright-cli type "<text>"`
   - Inspect state: `playwright-cli console`, `playwright-cli requests`, `playwright-cli screenshot --filename=/tmp/shot.png`
3. **Close & Hygiene:**
   - Always terminate session: `playwright-cli close`.
   - Ensure `.playwright/` and any auth storage state JSONs are listed in `.gitignore` and never committed.

## Output

Summarize target URL, actions executed, observed console/network errors (if any), and exact paths to saved screenshots/traces.

## Constraints

- Never commit `.playwright/`, cookies, or storage-state JSON files containing credentials.
- Prefer `playwright-cli` over `@playwright/mcp` for coding-agent loops whenever filesystem access is available to avoid inline DOM/schema token bloat.
- Never claim browser checks passed unless executed and observed after the final edit.
