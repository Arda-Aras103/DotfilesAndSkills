---
name: opportunity-verdict
description: Evaluates specific job, internship, program, scholarship, and hackathon listings against user profile. Outputs apply, shaky, or skip verdicts for listings and scholarships, and 100-point Fit Score cards with project ideas for hackathons. Triggers include basvurayim mi, firsat, ilan bak, burs tara, haftalik burs, KYK disi burs, hackathon, hackaton, Unstop, Kaggle, Devfolio, Imagine Cup, TensorHack, TAIKAI, Cerebral Valley, worth maybe skip, fit score.
user-invocable: true
metadata:
  type: workflow
  version: "4.1"
---

# Opportunity Verdict

Evaluates specific opportunities (jobs, internships, programs, scholarships, or hackathons) against `/workspace/profile.md`.

## When & Modes

- **Mode 1 — Job, Internship, Program, or Scholarship Verdict:** Link, screenshot, or name asking `başvurayım mı`, `ilan bak`, or scholarship eligibility/trust (`burs tara`, `KYK dışı burs`).
- **Mode 2 — Selective Hackathon & Competition Radar:** Request for hackathons/competitions with Fit Score cards (`Worth / Maybe / Skip`, `Fit Score`, Unstop, Kaggle, Devfolio, Imagine Cup, TAIKAI, TensorHack, Cerebral Valley, HackerEarth).

## Workflow & Sources

### Mode 1 — Listing & Scholarship Verdicts
1. Read `/workspace/profile.md` (graduation date, location, priority stack, accepted calendar commitments).
2. Verify eligibility, deadline, pay, and overlap rules on the **official** domain (never rely solely on aggregators like `guncel-egitim.org`, `bursumcepte.com`, `ogrenciburs.org`, `ogrenciislerim.com`, or social posts). If an official SPA page returns an empty JS shell on standard HTTP fetch, fall back to the `singlefile` MCP server or `./.agents/skills/media-web-archiver/scripts/archive.sh "<URL>"`.
   - *TR Lisans Scholarship Starter Domains (when asked for scholarships):* TEV, HAFEV (`faydasicokvakfi.org`), ABL (`ablfoods.com.tr/burs/`), TEKINDER, Sütaş, Mehmet Esra Cansız Vakfı, İNCİVAK, MEV, NEYAD, MUKAD, university scholarship office.
   - *Trust Scale (application channel):* **High** (own domain + application portal), **Medium** (official site via email/post or unclear overlap), **Low** (social/aggregator only, free mailbox/chat apply—do not recommend).
3. Apply hard filters (graduation year, location, major, official age/gender restrictions only when explicitly stated on the official page). Light calendar overlap is noted, not an automatic skip.
4. Only write `reports/scholarships.md` if the user explicitly asks for a saved scholarship board.
5. **Browser Hiding:** When the user shares a specific listing URL that gets a `❌ Skip` verdict (or explicitly asks to hide a reviewed listing), append it to the uBlock Origin custom filter list via `python3 /workspace/scripts/hide-opportunity.py add "<URL>"` (or `add-text "<domain>" "<title>"` for SPAs without unique URLs).

### Mode 2 — Selective Hackathon Radar (Fit Score)
1. Search Unstop, Kaggle, Cerebral Valley, TAIKAI, Imagine Cup, Devfolio, TensorHack, HackerEarth, and Devpost; follow through to the **official event page** (cite as clickable `Official event page`—omit unverified events). If an event SPA page returns an empty JS shell on standard HTTP fetch, fall back to the `singlefile` MCP server or `./.agents/skills/media-web-archiver/scripts/archive.sh "<URL>"`.
2. Keep events if registration **or** submission window is still open. Hard-skip non-remote events outside profile country and pure leaderboard notebooks/CTFs unless the user asked for them.
3. Score remaining events out of **100** (no points for prize size or popularity):
   - Profile / technical match: `0–50`
   - Real software build potential (shipped tool/CLI/service/infra vs notebook): `0–20`
   - Remote or profile-country eligibility: `0–15`
   - Alignment with profile priority order (leftmost skill highest; do not stack): `0–10`
   - Practicality for current skill & time: `0–5`
4. Sort by Fit Score descending; return only `Worth` or `Maybe` cards. If none pass, output `No worthwhile opportunities found.`

## Output

Language matches the user (keep Mode 2 card field labels as shown).

- **Job / Internship / Program:**
  ```
  ✅/⚠️/❌ 1-2 sentences why (✅ Worth it / ⚠️ Shaky / ❌ Skip)
  ```
- **Scholarship:**
  ```
  ✅/⚠️/❌ [Name](official-url) — trust (High/Medium/Low) — amount/month x months — deadline
  Eligibility summary. Why this mark. Overlap note.
  ```
- **Hackathon Fit Card (separate with blank lines, no table):**
  ```
  [Hackathon Name]
  Source: [Official event page](official-url)
  Why it fits me (2 sentences):
  What I could build (2 concrete project ideas):
  Deadline:
  Prize:
  Remote: Yes/No
  Eligibility:
  Difficulty (estimated): Easy / Medium / Hard
  Fit Score: X/100
  Your Decision (Worth/Maybe/Skip) (1 word and 1 sentence to why):
  ```

## Constraints

- Never infer eligibility from title alone; never invent deadlines, amounts (`aciklanmamis` if unstated on official page), pay (`unclear` if unstated), or prizes (`Veri bulunamadı`).
- Do not output `Skip` cards in Mode 2; be selective.
- Portfolio/project claims must rest strictly on shipped work listed in `profile.md` (prompts/AI workflows alone are not portfolio projects).
