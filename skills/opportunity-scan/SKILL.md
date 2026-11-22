---
name: opportunity-scan
description: Weekly and monthly scan of open internships, talent programs, hackathons as a list, bootcamps, cloud student vouchers, and mentorship term windows in reports/career.md, plus silent delta checks for newly opened roles or imminent deadlines. Triggers include haftalik firsat, ilan tara, kariyer kontrol, donem kapisi, aylik tarama, sessiz kontrol, delta kontrol, youthall, anbean, coderspace, Devpost, HackerEarth, LFX, GSoC, Outreachy, MLH, Blue Book, EEAS, Teknofest takvim, student voucher, remote board, LinkedIn staj.
user-invocable: true
metadata:
  type: workflow
  version: "5.2"
---

# Opportunity Scan

Weekly and monthly open-opportunity discovery (internships, talent programs, hackathons as a list, bootcamps, cloud student vouchers, and mentorship term windows) written to `reports/career.md`. List only—no ✅/⚠️/❌ marks.

## When

The user asks for a weekly career scan, monthly term-window sweep (`dönem kapısı`, `aylık tarama`), or mentions LFX, GSoC, Outreachy, MLH, Blue Book, EEAS, Teknofest calendar, student exam vouchers, or remote/TR intern boards. A one-shot "run it now" executes immediately.

## Profile & Sources

Read `profile.md` from `/workspace` (unless supplied in chat). Never invent missing profile data or use gender/age as ranking signals.

Search starting points (always open the live official apply/program page—never cite an aggregator or old cache as the final link):
- **TR Boards & National:** Youthall, Anbean, Coderspace, Savunma Kariyer, Kariyer.net (intern + software/devops/backend/cloud), Teknofest / national student tech contests, named company career pages.
- **Global Remote & Intern Lists:** LinkedIn Jobs public search, GitHub curated intern lists, JustRemote, Wellfound (no login wall), We Work Remotely, Remote OK, Himalayas, Devpost, HackerEarth.
- **Mentorship, Open Source & Student Windows:** LFX Mentorship, GSoC, Outreachy, MLH (fellowship/student programs), CNCF / Kubernetes / HashiCorp / cloud provider student credits & exam vouchers (dated/active campaigns only—skip generic always-open courses), EU Careers, Blue Book, EEAS.

## Workflow

1. Use current local date; search live sources and open official program/company pages (`careers.*`, `*.gov.tr`, `*.cern`, `smartrecruiters.com`, etc.). If a JS-heavy/SPA listing returns an empty shell on standard HTTP fetch, fall back to the `singlefile` MCP server or `./.agents/skills/media-web-archiver/scripts/archive.sh "<URL>"` (`single-file-cli`) before marking `erisilemedi`.
2. Verify hard eligibility against `profile.md` (class year, graduation date `2028-06`, location/remote eligibility). Never infer eligibility from the title alone.
3. Categorize verified open items into `### Staj ve iş`, `### Hackathon`, and `### Bootcamp & Öğrenci Fırsatları` (paid/stipend first; exclude non-technical sales/PR/recruiter roles and multi-year senior bars).
4. Place closed cycles that still fit future graduation under `### Sonraki pencere` (with published next date or `sonraki tarih bilinmiyor`).
5. **Uymaz, tekrar yazma:** Programs requiring a completed degree or restricted residence that misses `profile.md` go once under `## Uymaz, tekrar yazma` (one line per program family; never repeat as `bekle` in future scans).
6. **Bakılmadı & Kapalı:** Closed cycles go under `## Kapalı`. Unreachable, login-walled, unverified, or visa-locked rows go under `## Bakılmadı — YYYY-MM-DD` labeled `erisilemedi`, `login gerekli`, or `dogrulanmadi`.
7. Update `reports/career.md`: on a new date, move the previous current board under `## Arşiv` (preserve standing `## Uymaz, tekrar yazma`), and write the new board at the top. On the same date, replace today's board.
8. **Silent Delta Mode (`sessiz kontrol` / `delta kontrol` / `/schedule`):** Compare live findings against `reports/career.md` and `reports/applications.md`. Suppress routine listings and emit only newly opened verified roles or deadlines `< 7` days away.

## Output

- **Full Scan:** Write to `reports/career.md` (do not create dated filenames) and summarize concisely in chat with clickable `[Title](official-url)` links:
- **Silent Delta Mode:** Print only new openings / `< 7`-day deadline alerts (or `Değişiklik veya <7 gün içinde acil son tarih yok.` if none).

```markdown
# Kariyer

Güncel tarama YYYY-MM-DD. Üstte yalnız sayfası açılmış kartlar. Erişilemeyen, doğrulanmayan ve vizeyle kilitli satırlar altta.

## Doğrulanan — YYYY-MM-DD

### Staj ve iş
- [Title](official-url) — company/org — location — deadline — 1 sentence why it fits — paid/stipend/unclear/unpaid/ucretsiz

### Hackathon

### Bootcamp & Öğrenci Fırsatları

### Sonraki pencere

## Uymaz, tekrar yazma

## Kapalı

## Bakılmadı — YYYY-MM-DD
```

## Constraints

- Do not mark ✅ / ⚠️ / ❌ here (`erisilemedi`, `login gerekli`, `dogrulanmadi` are not verdicts).
- Every verified line requires a pay field (`paid` / `stipend` / `unclear` / `unpaid` / `ucretsiz`) and clickable `[Title](official-url)` (or `url bulunamadi` at the bottom of the subsection).
- Never invent deadlines, pay, or eligibility; tag unverified third-party claims `resmi degil`.
