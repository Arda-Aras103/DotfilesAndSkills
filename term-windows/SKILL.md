---
name: term-windows
description: Monthly student, cloud, and mentorship window scan. Catch sparse official application terms that the weekly opportunity board misses. A finished-degree requirement that misses the profile graduation date is recorded once as uymaz and is not repeated as bekle. Triggers include donem kapisi, aylik tarama, LFX term, GSoC, Outreachy, MLH, Blue Book, EEAS, Teknofest takvim, student voucher, student intern season.
user-invocable: false
metadata:
  type: workflow
  version: "1.6"
---

# Term Windows

Monthly period-door scan. Official programs with an application, registration, or term date only. No top summary. No apply or skip marks.

Weekly intern boards belong to `opportunity-scan`. Apply or skip marks belong to `opportunity-verdict`. Hackathon Fit Score belongs to `hackathon-fit`. Tutor talk belongs to `project-tutor`.

Routing priority

- Specific listing + decision question → `opportunity-verdict`
- Open opportunity discovery or list → `opportunity-scan`
- Sparse cycle or term date → this skill
- Scholarship amount, trust, or eligibility mark → `opportunity-verdict`

If the user pastes a new When / Output / Constraints block for this skill, replace those sections. Do not add fields they did not send.

## When

The user asks for a monthly student, cloud, or mentorship window scan, a term date, or names LFX, GSoC, Outreachy, MLH, Blue Book, EEAS, a Teknofest season, a cloud-provider student campaign, a student exam voucher only when that voucher exists, or an official student intern season.

## Profile

Read the profile the user supplies. Required when a line depends on them: school, graduation date, location, stack, and calendar commitments already accepted. If a required field is missing, ask once. Do not invent it. Note a clash with an accepted commitment. Do not auto-drop.

## Sources

Search starting points only. The official program page is always the card source. Verify every date on that page. Never use a blog or a generic course list as the card source.

1. Cloud education or student programs — only student-accessible benefits, application or registration windows, credits, vouchers, or officially dated campaigns. Exclude generic courses, learning paths, and always-open content.
2. LFX Mentorship — open term or next term date. https://mentorship.lfx.linuxfoundation.org/
3. GSoC, Outreachy, MLH — if the cycle is open, deadline plus eligibility against the profile graduation date. MLH — only fellowship or student programs with an official application or term date. Do not scan hackathon events.
4. Blue Book, EU Careers traineeship, EEAS — open window, deadline, and whether a completed degree is required. A completed-degree requirement that misses the profile graduation date is `uymaz`, written once, not an open or next-window line. Do not force a login wall.
5. Current national student technology-contest calendar, plus software or technology contest registration deadlines, when an official page states the date.
6. CNCF, Kubernetes, or HashiCorp — only if an official student voucher, student exam campaign, or mentorship term is actually open or dated on the official page. Do not list generic community pages every month.
7. Official careers pages the user named. A third-party internship claim that is not on the company page is omitted or tagged `resmi degil`.
8. Companies the user named — only if a student or intern season newly opened.
9. Local cloud user group, local community workshop, and the profile school's career office — only when a date is on the official page.

If the user sends a new source list, use that list instead.

If the official page cannot be opened, do not invent the date. Write `url bulunamadi` or omit the item.

## Workflow

1. Use the current date and time. Title month is `YYYY-MM` in the user's local timezone.
2. Run web search, then open the official page for each check above.
3. Never infer eligibility from the title alone. Verify requirements on the official page.
4. Keep only programs with an application, registration, or term date.
5. Drop blogs, course ads, and generic coupons.
6. A closed cycle that can still fit a later window — one line `kapandı, sonraki tarih X` (or `sonraki tarih bilinmiyor`) under `## Sonraki pencere`. Do not narrate the closed season. That section is only the next official cycle or term already published. Do not list cycles two or more years out when no date is published.
7. Finished degree or wrong residence — if the official page requires a completed degree or a residence the profile does not have, write the program once under `## Uymaz, tekrar yazma`. Do not put it in `## Açık` or `## Sonraki pencere`. Do not use the action `bekle` for it on this scan or any later scan. One exclusion line covers a program family. Do not list every site again next month.
8. A visa-only restriction — note it, and exclude the row if it cannot accept the profile location.
9. Full-time roles that require several years of experience are out of scope.
10. Do not mark ✅ / ⚠️ / ❌.

## Output

Language matches the user. No top summary. Do not mark ✅ / ⚠️ / ❌.

```
# Dönem kapısı

Güncel tarama YYYY-MM. Profildeki mezuniyet tarihine uymayan çağrı bir kez yazılır, sonraki ay bekle diye dönmez.

## Açık — YYYY-MM
- [Ad](resmi-url) — son tarih veya sonraki term — ücretli/stipend/voucher/belirsiz — 1 cümle neden önemli — kısa aksiyon (kaydol / bekle / başvur)

## Sonraki pencere
- [Ad](resmi-url) — son tarih veya sonraki term — ücretli/stipend/voucher/belirsiz — 1 cümle neden önemli — kısa aksiyon (kaydol / bekle / başvur)

## Uymaz, tekrar yazma

## Bu ay kaçırılmaması gerekenler
- ...
- ...
- ...
```

`## Açık` — currently open windows. Items that close in the next 30-45 days go first. Empty section — one line `bu ay yok`.

`## Sonraki pencere` — only the next published official cycle or term for a program that can still fit. Not a second copy of an open window. Not a program already filed as uymaz. Empty section — one line `bu ay yok`.

`## Uymaz, tekrar yazma` — standing exclusion. One short reason, then the programs. A later month does not list them again under Açık, Sonraki pencere, or `bekle`. If this block is already in the file, keep it and do not add the same programs again. A newly discovered uymaz program is appended once.

`BU AY YENİ / DEĞİŞEN` — include this heading only when one of these happened in the current calendar month: new application opened, deadline changed, new term date published, eligibility changed, voucher or benefit changed. State what changed in the one-sentence why. If nothing changed, omit the heading. Do not put the same program in both `## Açık` and this heading unless the change itself is the news.

Missing official URL — keep the line and write `url bulunamadi`.

Footer — exactly this block, no extra recap. If fewer than three exist, fill the remaining lines with `bu ay yok`. If none exist, the only line is `bu ay yok`.

```
## Bu ay kaçırılmaması gerekenler
- En kritik pencere
- İkinci kritik pencere
- Üçüncü kritik pencere
```

Note a calendar clash in the one-sentence why or the action, not as an automatic skip. The action `bekle` is only for a real later window. It is not used for uymaz.

## Dosya

Write the board to `reports/term-windows.md` in the workspace.

Do not create a dated filename.

Read the file first. On a new month, move the previous Açık, Sonraki pencere, and kaçırılmaması gerekenler blocks under `## Arşiv — YYYY-MM` as a short paragraph. Do not copy the uymaz list into that archive paragraph. Keep `## Uymaz, tekrar yazma` on the current board. On the same month, replace today's Açık, Sonraki, and footer, and leave the standing uymaz block and older archive. An older archive line does not override the latest scan.

## Constraints

- Official page only for dates, pay, and eligibility.
- Found data — type it. Missing field — `belirsiz` or `url bulunamadi`. Do not invent deadlines.
- A finished-degree or wrong-residence miss is written once under `Uymaz, tekrar yazma` and is not repeated next month as bekle.
- This skill only writes the monthly window board.
