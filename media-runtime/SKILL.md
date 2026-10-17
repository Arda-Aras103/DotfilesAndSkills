---
name: media-runtime
description: Film, dizi, and oyun runtime cards. Look up IMDb, Wikipedia, official sites, HowLongToBeat, and Metacritic, then write a spoiler-free card. Not for continue or drop decisions. Triggers include film, dizi, oyun, movie, series, game, kac saat, kac sezon, kac bolum, IMDB, HLTB, HowLongToBeat, bitirme suresi, medya kart, or a bare title list with no other instruction.
user-invocable: false
metadata:
  type: workflow
  version: "5.2"
---

# Media Runtime

Runtime cards for film, series, and games. Short and spoiler-free. No tables.

If the user pastes a new When / Output / Constraints block for this skill, replace those sections. Keep the title-year and missing-data rules unless they override them. Do not add fields they did not send.

## When

The user gives one or more film, dizi, or oyun names, or a bare title list. Also when they ask sure, kac saat, kac sezon, kac bolum, bitirme suresi, or how long something takes to watch or play.

Continue, drop, grind, or a card-table question belongs to `game-decision`. Do not add a Karar line on the runtime card.

## Workflow

1. Identify each title type — film, dizi, or oyun. Infer if unstated. Genuinely ambiguous (same name as film and game) — pick the best-known work and keep the year on the title line. Still unclear — one short question, or cover both briefly.
2. Search the web for the exact title and year.
3. Open primary source pages and extract numbers from them. Never invent a number.
   - Film and dizi — IMDb, Wikipedia, official site.
   - Oyun — HowLongToBeat for Main / Main+Extra / Completionist, and Metacritic for metascore.
4. Fill the Output block. Never use a table.
5. Process multiple titles in the order given. Separate blocks with `---`.

## Output

Language matches the user. Labels stay as below.

```
Film:
Title (Year) (film)
Özet: 1-2 cümle.
Süre: Y saat Z dk
IMDb: X.X/10
---
Dizi:
Title (Year) (dizi)
Özet: 1-2 cümle.
Sezon: N
Toplam bölüm: M
Bölüm başı: ~X dk
Toplam: Y saat Z dk
IMDb: X.X/10
---
Oyun:
Title (Year) (oyun)
Özet: 1-2 cümle.
Main: A saat
Main+Extra: B saat
Completionist: C saat
Metacritic: NN
```

Type label in parentheses. Swap the type when needed — `(mini-series)`, `(anthology)`, `(film trilogy)`. A requested trilogy gets one note line, then one Film block per title.

## Constraints

- Do not make a table.
- Keep it short.
- No spoiler. No ending, twist, death, killer, or last-season reveal. Do not write "no spoiler" or "spoiler yok" in the card.
- Found data — type it. Missing field — `Veri bulunamadı`. Do not invent runtime, seasons, episodes, HLTB hours, IMDb, or Metacritic.
- Sources — film and dizi from IMDb, Wikipedia, or the official site. Games require HowLongToBeat for times and Metacritic for the metascore. Do not take ratings or runtimes from listicles, blogs, or random roundups.
- Lookup order is search, then primary pages above. Do not hardcode tool function names.
- IMDb is the 10-point rating to one decimal (`8.4/10`). No vote count. No link.
- Metacritic is metascore 0-100, not user score.
- Duration format is `Y saat Z dk`. Drop `0 dk`. Game hours may be `A saat` only.
- Episode length varies a lot across seasons — use `~` and a range (`~22-45 dk`). Series Toplam = average episode length × total episodes, rounded.
- Ongoing or unfinished series — Toplam uses only released episodes, marked `(devam ediyor)`.
- List mini-series, film trilogies, and anthologies as separate blocks, not one merged total.
- HowLongToBeat — all-playstyles / most-common-platform average. DLC is not a second card unless the user named it.
- No watch or play recommendation unless asked. A continue or drop call stays in `game-decision`.
- This skill only writes runtime cards. It does not mark apply or skip.
