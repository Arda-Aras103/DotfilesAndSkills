---
name: media-game-guide
description: Film, series, and game runtime cards, continue or drop game decisions, QoL mod loadouts, ideal settings tables, and 4-tier mod list prioritization. Triggers include film, dizi, oyun, kac saat, kac sezon, kac bolum, IMDB, HLTB, HowLongToBeat, bitirme suresi, devam mi, birakayim mi, drop early, grind, oyun karari, mod oner, qol modlari, ideal ayarlar, hangi modlarla baslayayim, mod listesi sirala, mod kurulumu.
user-invocable: true
metadata:
  type: workflow
  version: "1.1"
---

# Media & Game Guide

Runtime cards for film/series/games, continue-or-drop game verdicts, and QoL modding/settings guidance.

## When

Route into one or more modes based on the request (combine Mode 1 + Mode 2 only when the user asks both):

- **Mode 1 — Runtime & Score Card:** Bare title list or questions about runtime, seasons, episodes, HowLongToBeat hours, IMDb, or Metacritic.
- **Mode 2 — Continue or Drop Decision:** `devam mı`, `bırakayım mı`, `drop early`, `grind`, or fatigue check on a game.
- **Mode 3 — Modding, QoL & Settings:** `mod öner`, `qol modları`, `ideal ayarlar`, `mod kurulumu`, game library mod check (Mode 3A), or ranking a pasted mod list into 4 tiers (Mode 3B).

## Workflow & Sources

### Mode 1 — Runtime & Score Card
- **Sources:** IMDb, Wikipedia, and official site for film/series; HowLongToBeat (Main / Main+Extra / Completionist, all-playstyles average) and Metacritic (metascore 0-100, not user score) for games. Never pull numbers from blogs or listicles.
- **Format Rules:** Duration as `Y saat Z dk` (drop `0 dk`; games may use `A saat`). IMDb to one decimal (`8.4/10`, no vote count/link). Ongoing series marked `(devam ediyor)` using released episodes only. Separate blocks for mini-series, anthologies, and trilogies with `---`. No tables.

### Mode 2 — Continue or Drop Decision
- **Rule:** A game is finished the moment enjoyment stops. Past the fatigue point, continue only if the next 1–2 hours unlock a new mechanic, structural paradigm shift, or narrative breakthrough. Pure stat scaling, idle loops, or repetitive grind means drop now (`Drop Early`).
- If the user supplies personal hours/notes or asks for a recorded call (`kayit yok` if none supplied), weigh enjoyment over old notes. Do not invent HLTB hours if Mode 1 was not requested.

### Mode 3 — Modding, QoL & Settings
- **Sources:** Steam Workshop, Thunderstore (`r2modman`), Modrinth (`Prism Launcher`), NexusMods, CurseForge, Reloaded-II, tModLoader, GameJolt, PCGamingWiki.
- **Mode 3A (Game / Library QoL):** Separate moddable games from unmoddable/edition-locked titles (**Diğer Oyunların Durumu**). Identify mod manager (with Fedora/Proton notes like `WINEDLLOVERRIDES` only when relevant), standout grind-reducing QoL mods (tag content expansions with `*(İçerik)*`), and critical `Vanilla:` / `Mod:` settings.
- **Mode 3B (4-Tier Mod List Ranking):** Group pasted mods into 5 categories (`Performans & Temel Altyapı`, `Arayüz & Bilgilendirme (HUD)`, `Yaşam Kalitesi (QoL)`, `Çok Oyunculu & Teknik`, `Grafik & Kozmetik`) and rank into 4 tiers:
  1. **1. Kademe (Temel & Performans):** Rendering optimization, mod menus, config APIs, shader loaders.
  2. **2. Kademe (En Yüksek Faydalı QoL):** High-frequency HUD/inventory/inspection tools without breaking balance.
  3. **3. Kademe (Oynanış Tarzına Bağlı):** Minimaps, schematics, LOD distance, voice/co-op host tools (prefer clean open tools like `e4mc` / `World Host`).
  4. **4. Kademe (Saf Kozmetik):** Particles, animations, 3D skin layers, sound packs.

## Output

Language matches the user. Keep exact Mode 1 / Mode 2 card labels.

### Mode 1 Cards (No tables; separate titles with `---`)
```
Title (Year) (film | mini-series | anthology | film trilogy)
Özet: 1-2 cümle.
Süre: Y saat Z dk
IMDb: X.X/10
Platform: Resmi platform veya Veri bulunamadı
---
Title (Year) (dizi)
Özet: 1-2 cümle.
Sezon: N
Toplam bölüm: M
Bölüm başı: ~X dk
Toplam: Y saat Z dk
IMDb: X.X/10
Platform: Resmi platform veya Veri bulunamadı
---
Title (Year) (oyun)
Özet: 1-2 cümle.
Main: A saat
Main+Extra: B saat
Completionist: C saat
Metacritic: NN
Platform: Steam / Game Pass / PS5 veya Veri bulunamadı
```

### Mode 2 Card
```
Title
Karar: Drop Early / Must Play / Play until stale / Push Through
Neden: 1-2 cümle
Sınır: yorgunluktan sonra en fazla 1-2 saat; yeni mekanik yoksa bırak
```

### Mode 3A Table & Mode 3B List
- **Mode 3A:** Table `| Oyun | Kurulum Aracı | Öne Çıkan QoL Modları | Kritik Oyun & Mod Ayarları (Settings) |` + optional `### 2. Diğer Oyunların Durumu` (omit section 2 for a single moddable game unless an edition caveat exists).
- **Mode 3B:** `### 1. Modların Gruplandırılması ve Açıklanması` (5 categories) + `### 2. Öncelik ve Mantık Sıralaması` (4 tiers).

## Constraints

- **No spoilers:** Never reveal endings, twists, deaths, killers, or late-act content (do not write `"spoiler yok"` in the card).
- **No invention:** Found data -> type it; missing runtime, score, note, or mod support -> `Veri bulunamadı` (or `kayit yok` for missing personal call notes).
