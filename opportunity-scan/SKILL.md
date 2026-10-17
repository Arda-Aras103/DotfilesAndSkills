---
name: opportunity-scan
description: Weekly and daily scan of internships, talent programs, hackathons as a list, bootcamps, mentorship terms, and remote boards, plus LinkedIn Instagram X. Produce a list, do not mark apply or skip. Verified cards stay on top. Unopened and visa-only rows stay off the top. A finished-degree miss is written once as uymaz. Daily social does not copy the career file. Triggers include haftalik firsat, ilan tara, kariyer kontrol, gunluk linkedin, instagram tara, sosyal tarama, youthall, anbean, coderspace, Devpost, HackerEarth, LFX, remote board, LinkedIn staj.
user-invocable: false
metadata:
  type: workflow
  version: "3.9"
---

# Opportunity Scan

Scan open technical opportunities and list them. No apply or skip marks.

"Basvurayim mi", screenshot verdicts, and scholarship amount or trust boards go to `opportunity-verdict`. Project tutor talk goes to `project-tutor`. Selective hackathon Fit Score cards go to `hackathon-fit`. Channel videos go to `channel-radar`. Sparse student, cloud, and mentorship term windows go to `term-windows`.

Routing priority

- Specific listing + decision question → `opportunity-verdict`
- Open opportunity discovery or list → this skill
- Sparse cycle or term date → `term-windows`
- Scholarship amount, trust, or eligibility mark → `opportunity-verdict`

If the user pastes a new When / Output / Constraints block for this skill, replace those sections. Do not add fields they did not send.

## When

The user asks for a weekly board, a source sweep, or a daily LinkedIn, Instagram, or X pass. Also when a scheduled weekly board or a daily social pass runs this skill.

A one-shot "run it now" means run the scan immediately, do not only enqueue.

## Profile

Read the profile the user supplies. Required when a line depends on them: school, graduation date, city, country, remote preference, and stack. If a required field is missing, ask once. Do not invent it. Do not assume a family city. Do not use gender or age as a ranking signal.

## Sources

The list is a search starting point. Prefer the individual official apply URL over an index page. Browse live pages every run. Do not trust an old cache.

Turkey boards below are the bundled starter list. If the profile country is not Turkey, treat them as optional and prefer official boards for the profile country plus the remote boards.

Weekly

- Youthall — https://www.youthall.com/tr/is-ilanlari/ and https://www.youthall.com/tr/etkinlikler/
- Anbean — https://anbeankampus.co/ilanlar and events if present
- Coderspace — https://coderspace.io/etkinlikler
- Devpost — https://devpost.com/hackathons
- HackerEarth — https://www.hackerearth.com/challenges/ plus a site search for hackathon or hiring. Skip citizen or university locks that exclude the profile. Keep the profile country, worldwide, and remote. Hiring only intern, junior, student, or a graduation year that fits the profile. Drop multi-year experience bars.
- LFX — https://mentorship.lfx.linuxfoundation.org/ and projects accepting. Closed term → one line with the next term date.
- Savunma Kariyer — https://savunmakariyer.com/ilanlar for intern, software, computer, or talent roles at the major employers listed on that board. Do not force the login page.
- Kariyer.net — intern plus software, devops, backend, or cloud; profile city plus remote
- LinkedIn Jobs public search — internship, software, devops, and the profile stack; profile city, profile country, or remote
- GitHub intern lists — public curated Summer, Fall, and off-cycle lists for the relevant years, then company career pages. The old GitHub Jobs product is gone.
- JustRemote — https://justremote.co/remote-developer-jobs
- Wellfound — https://wellfound.com/jobs for intern or software. Do not force login.
- We Work Remotely — https://weworkremotely.com/categories/remote-programming-jobs
- Remote OK — https://remoteok.com/remote-dev-jobs
- Himalayas — https://himalayas.app/jobs/software-engineering-intern and https://himalayas.app/jobs
- Other national job boards the user names, for current intern posts
- summerofcode.withgoogle.com if the cycle is open
- outreachy.org, mlh.io, and the current national student technology contest if a listing is open
- CNCF careers, cloud and infrastructure company student or intern pages, when a current listing exists
- EU Careers traineeships — https://eu-careers.europa.eu/en/job-opportunities/traineeships and https://eu-careers.europa.eu/en
- Blue Book — https://traineeships.ec.europa.eu/ and available strands. Do not force a login.
- EEAS — https://www.eeas.europa.eu/eeas/vacancies_en
- Company careers pages the user named. Prefer the company's own apply host.

Daily social

- LinkedIn
- Instagram
- X, personal follow list only when the user supplied handles

Do not use a paid-wall job board as a source.

If the user later pastes a source file or a new source list, use that list instead.

Do not add video-channel sweeps here.

## Output

No top summary. No item cap. Language follows the user. Do not mark ✅ / ⚠️ / ❌.

Weekly board. The top holds only cards whose page was opened on this run.

```
# Kariyer

Güncel tarama YYYY-MM-DD. Üstte yalnız sayfası açılmış kartlar. Erişilemeyen, doğrulanmayan ve vizeyle kilitli satırlar altta. Arşivdeki hüküm üsttekinin yerine geçmez.

## Doğrulanan — YYYY-MM-DD

### Staj ve iş

### Hackathon

### Bootcamp

### Sonraki pencere

## Uymaz, tekrar yazma

## Kapalı

## Bakılmadı — YYYY-MM-DD
```

Each verified item

```
- [Title](url) — company/org — location — deadline — 1 sentence why it fits — paid/stipend/unclear/unpaid
```

If the URL is missing, keep the line at the bottom of that verified subsection and write `url bulunamadi`.

Inside a verified subsection: linked plus priority-stack first, then other technical roles; sooner deadlines higher; missing-URL rows last.

`## Uymaz, tekrar yazma` — a program that requires a finished degree and misses the profile graduation date. Write it once. Do not list every office or delegation again. Do not write these as bekle on the next scan.

`## Kapalı` — known closed cycles only, one short line each. This is not Bakılmadı. Detailed monthly windows stay in `term-windows`.

`## Bakılmadı` — pages that were not opened, login-only pages, unverified rows, and visa-only rows that cannot accept the profile location. One line each. Use `erisilemedi`, `login gerekli`, or `dogrulanmadi`. Those words are not apply or skip marks. Do not put these rows in Doğrulanan.

Do not add a "new this week" section. It repeats the verified list.

Daily social. Do not copy a card already written in `reports/career.md` that day. Keep only cards first seen that day. A different URL is a different card.

```
# Sosyal

Kariyer dosyasındaki kart burada tekrarlanmaz. Her gün yalnız o gün ilk kez görülen kart durur.

## YYYY-MM-DD
```

Each social item uses the same one-line fields. Official apply URL first, social post second. Empty Instagram line: `Instagram: bugün yeni sinyal yok.` Missing X handle: `X: x bulunamadı.`

Do not include a video-channel section.

## Dosya

Write the weekly board to `reports/career.md` and the daily pass to `reports/social.md` in the workspace.

Do not create a dated filename.

Read the file first. On a new scan date, move the previous current board under `## Arşiv` and keep it. Write today's board at the top. On the same date, replace today's current board and leave older archive blocks. An archive ruling does not override the top scan. Scholarship amounts stay in `reports/scholarships.md`.

## Constraints

- Never infer eligibility from the title alone. Verify the actual eligibility requirements on the relevant official page.
- Sort by relevance first, then deadline. Prefer direct technical matches over adjacent roles. Do not suppress a valid opportunity only because the list is long.
- Stack priority comes from the profile. It is not a hard filter. Also list other technical roles.
- No hour cap. Applications in the listing's language are fine.
- Paid first. Mark free or volunteer as `ucretsiz`. Pay field is required on every job, intern, or talent line (`paid` / `stipend` / `unclear` / `unpaid` / `ucretsiz`).
- Types — internship, talent or new-grad, hackathon (list only, no Fit Score), bootcamp or academy, mentorship term, industry intern or talent, networking, and official open-source or intern programs the user named. Deep scholarship amount and trust marks go to `opportunity-verdict`.
- Horizon — open now or in the next 1-2 months. Also keep internships that fit the profile graduation date.
- Exclude sales, customer advisor, recruiter, social media, and event intern unless the role is technical.
- Only open listing pages. Do not force login walls. Unreachable, login-only, unverified, and visa-only rows get one line under `## Bakılmadı`: `erisilemedi`, `login gerekli`, or `dogrulanmadi`. That line is not an apply or skip mark and does not go in Doğrulanan.
- A company careers page is official. Tag an unofficial third-party internship claim as `resmi degil`.
- Remote boards — prefer intern or junior roles that match the profile stack. Exclude visa-only, country-locked, or multi-year bars unless the listing explicitly accepts the profile country or worldwide applicants.
- Do not mark ✅ / ⚠️ / ❌ here.
- Drop expired one-off listings and non-technical rows. A known closed cycle stays as one `## Kapalı` line, not in Doğrulanan and not in Bakılmadı. Prefer the individual apply URL over a list page. Do not delete an item just because the URL is missing.
- If a mentorship term is open now, one list line is enough. Closed-cycle dates and the monthly window board belong to `term-windows`. A completed-degree requirement that misses the profile graduation date is `uymaz, tekrar yazma`. Do not rewrite it next month as bekle. One line per program family is enough.
- Daily social — last 24-48 hours only, not the full board. Omit any card already in `reports/career.md` that day. Keep a card only on the day it is first seen. A later day does not repeat the same URL. Only include accounts with a verified or supplied handle. Do not invent handles. If the user asks to add an account and the handle is missing, write `X: x bulunamadı.`
- A social post alone is not proof of a scholarship amount. Find the official domain. Amount and trust marks go to `opportunity-verdict`.
- Do not write sales courses, influencer courses, or fake scholarship carousels.
- A weekly board and a daily social pass are separate schedules in the user's local timezone. Daily social is LinkedIn, Instagram, and X only. Video channels belong to `channel-radar`. If the filter, hour, or source changes, update this skill and the matching schedule.
- This skill only writes lists.
