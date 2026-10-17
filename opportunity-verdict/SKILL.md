---
name: opportunity-verdict
description: Opportunity verdict for jobs, internships, programs, and scholarships. From a link, screenshot, or name, mark apply, shaky, or skip. Weekly scholarship board keeps only open and soon calls. Closed calls go to the archive. Triggers include basvurayim mi, firsat, ilan bak, burs tara, haftalik burs, Hugging Face, MUKAD, TEKINDER, Sutas, TEV, INCIVAK, ABL, HAFEV, KYK disi burs.
user-invocable: false
metadata:
  type: workflow
  version: "3.9"
---

# Opportunity Verdict

Single decision layer. Marks only. Does not tutor a project. Does not dump the weekly intern board.

Weekly intern and hackathon lists belong to `opportunity-scan`. Monthly student, cloud, and mentorship term windows belong to `term-windows`. Project, portfolio, or tutor talk belongs to `project-tutor`. Hackathon Fit Score belongs to `hackathon-fit`. Personal video radar belongs to `channel-radar`.

Routing priority

- Specific listing + decision question → this skill
- Open opportunity discovery or list → `opportunity-scan`
- Sparse cycle or term date → `term-windows`
- Scholarship amount, trust, or eligibility mark → this skill

If the user pastes a new When / Output / Constraints block for this skill, replace those sections. Do not add fields they did not send.

## When

Link, screenshot, or name of a job, internship, scholarship, or program. The user asks whether to apply or questions a specific listing.

Weekly scholarship scan when the user asks for a scholarship sweep or pastes the official-source block.

If "kararimi sorgula" comes with a listing, mark it here. If it is about a project, a join, or a portfolio with no listing, send that work to `project-tutor` and do not mark.

## Profile

Read the profile the user supplies. If school, graduation date, location, stack, or accepted calendar commitments are missing, ask once. Do not invent them. Do not assume a family city.

## Burs sources

Search starting points for a Turkey lisans scholarship sweep. Verify the current term on the official page every run. If the profile country is not Turkey, treat this list as optional and use official boards for the profile country instead.

- HAFEV — https://faydasicokvakfi.org/
- ABL — https://ablfoods.com.tr/burs/ and https://burs.ablfoods.com.tr/
- TEKINDER — https://www.tekinder.org.tr
- Sutas — https://www.sutas.com.tr/burs-basvurusu and bursbasvuru.sutas.com.tr
- Mehmet Esra Cansiz — https://www.mehmetesracansizvakfi.org.tr/proje/burslar/
- TEV Universite Egitim — https://www.tev.org.tr/burs/tr/39/Universite-Egitim-Bursu
- INCIVAK — https://www.incivakfi.org/pages/burslar-hakkinda-genel-bilgi
- MEV — https://www.mev.org.tr/sayfa/burs-basvuru-formu
- NEYAD — neyad.org
- MUKAD — burs.mukad.org.tr
- YUNDER, ADEV, Deger Egitim, KAHEV, Turing, Gokyuzu, BAVAK, BTSO, Manisa BB, AEV — one ❌ line if the official page excludes the profile
- The profile school's scholarship office
- Newly opened company, foundation, or municipality lisans scholarships on an official domain

Source order — institution domain, school scholarship office, official social account, aggregator for a name or date hint only.

Not official — `guncel-egitim.org`, `bursumcepte.com`, `ogrenciburs.org`, `ogrenciislerim.com`.

## Output

Job, internship, or program

```
✅/⚠️/❌ 1-2 sentences why
```

- ✅ Worth it / Apply
- ⚠️ Shaky / Limited
- ❌ Skip

Single scholarship item

```
✅/⚠️/❌ [Name](official-url) — trust — amount/month x months — deadline
Eligibility summary. Why this mark. Overlap note.
```

Weekly scholarship board. Live top is only open and soon. No top summary paragraph. No closed section on the live board.

```
# Burs

Güncel tarama YYYY-MM-DD. Üstte yalnız açık ve yakında açılacak çağrılar durur. Kapanan ve elenen çağrı arşive iner. Arşivdeki açık hükmü üsttekinin yerine geçmez.

## Açık — YYYY-MM-DD

## Yakında — YYYY-MM-DD

## Arşiv

### YYYY-MM-DD kapandı veya elenen
```

Each scholarship item is 4-6 lines in the same mark format. Missing official URL — `url bulunamadi`, item last. A passed official deadline leaves Açık and Yakında. On a single listing, the first word is still `kapandi`. On the weekly board, that item goes under `### YYYY-MM-DD kapandı veya elenen`, not on top.

A call stays in Açık while the official deadline has not passed.

An older archive block that says açık does not override the latest scan.

No motivational recap. Do not cap the live board at an old item limit.

- 🏦 Amount — figure on the official page only; else `aciklanmamis`. An aggregator figure is not an amount.
- 🔒 Trust — High / Medium / Low. Trust is the application channel, not the amount.

## Dosya

Write the board to `reports/scholarships.md` in the workspace.

Do not create a dated filename.

Read the file first. On a new scan date, move the previous `## Açık` and `## Yakında` blocks into `## Arşiv` as `### YYYY-MM-DD` and keep them in full. Write today's Açık, Yakında, and kapandı block at the top. On the same date, replace today's three blocks and leave older archive blocks.

Voice — direct, plain, specific, short, no buzzwords. Portfolio wording in English. Chat in the user's language.

## Constraints

- Do not use gender as a default filter. Apply a gender check only when the official page itself restricts by gender and the profile states a value.
- Do not use age as a general signal. If the official page states an age rule and the profile has no age, flag it as a question, do not auto-drop, then mark.
- Never infer eligibility from the title alone. Verify the actual eligibility requirements on the relevant official page.
- Do not auto-join. Question the decision and say why.
- Proof in any portfolio sentence must rest on work the profile lists as shipped writing or a working project. A prompt or an AI workflow is not a portfolio case by itself.
- No long analysis on a single link. Mark first.
- Batch with no ✅ — after the marks, one line. Name the live `## Açık` and `## Yakında` rows in `reports/scholarships.md` that are not ❌. Read the file. Do not rescan. Do not dump the board. A paste of skips is not "no program is open." If no such row, say `acik tahta bos`.
- An existing club membership is not a new personal scholarship. A club budget paid to a representative account is not a stipend.
- Filter
  1. Field — profile stack, or an official scholarship?
  2. Fit — profile country and location, graduation date, student status. Official city, year, gender, or department restrictions that exclude the profile are ❌.
  3. Time — calendar commitments already in the profile. Light overlap is not an automatic skip.
  4. Source — official page vs SEO aggregator.
- Company careers — use the company's own careers domain. Open-source contributions are a path when no intern listing is open. Third-party internship claims that are not official are ⚠️ or ❌.
- Scholarships — do not trust aggregators. Find the official domain, confirm the current term on that page, then mark. Scan the official page every time. Do not use a local catalog as the source of amount or deadline.
- Trust scale (application channel only)
  - High — own domain plus own application system; company, chamber, or established foundation; recurring program that warns about fake accounts
  - Medium — official site but apply by email or posted documents; reference or monthly volunteering; overlap rule unclear
  - Low — only an aggregator or a social post; apply via a free mailbox, a chat app, or a request for a bank account; weak association site, social-only contact
- Amount stays `aciklanmamis` until the official page states it. Missing amount does not by itself change Trust.
- Do not recommend Low. For Medium, fill the official form if visible, do not chase paperwork.
- Overlap — if the form says no other scholarship except a named public loan, do not take a second. Read each official overlap rule on that page. Do not invent a clash.
- Paid field on jobs and internships when known. If pay is not on the official page, say `unclear`, do not invent it.
- This skill writes marks and the weekly scholarship board. Closed and eliminated calls leave the live top and go to the archive. It does not write the weekly intern board.
