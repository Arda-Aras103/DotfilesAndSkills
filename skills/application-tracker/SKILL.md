---
name: application-tracker
description: Manages internship, fellowship, and job applications in reports/applications.md, researches 4-track internship recommendations, runs CV and ATS keyword matching, and coaches project portfolio readiness. Triggers include basvuru takip, staj takip, staj oner, staj arastir, basvurdum, mulakat geldi, oa geldi, red geldi, teklif aldim, basvuru ekle, basvuru durumu, applications.md, cv eslestir, ats kontrol, ilana uygunluk, cv karsilastir, ilana gore cv, ats score, tutor ol, kararimi sorgula, portfolio, proje.
user-invocable: true
metadata:
  type: workflow
  version: "2.1"
---

# Application Tracker & Career Prep

Manages the application pipeline in `reports/applications.md`, researches tailored internships, checks CV/ATS match against postings, and coaches project/portfolio readiness.

## When & Modes

- **Mode 1 — Application Pipeline & 4-Track Internship Discovery (`reports/applications.md`):** Logging applications, OA/interview/rejection updates, checking pipeline stats/deadlines, or researching tailored internships to add as targets.
- **Mode 2 — CV & ATS Matching:** Pasted job/internship spec asking for ATS match score, keyword gaps, eligibility risk, or tailored CV/cover-letter bullets against `profile.md` / `ArdaArasCavdur_CV.pdf`.
- **Mode 3 — Project & Portfolio Coach:** `tutor ol`, `kararimi sorgula` (about a project, portfolio rewrite, or extra commitment), or reviewing project readiness.

## Profile & Stages

Read `/workspace/profile.md` first (graduation `2028-06`, 3rd year, GPA `3.62`, stack priority `DevOps / Cloud > Backend > AI/ML`, `ArdaArasCavdur_CV.pdf`, `documents/flyrank/`).

Pipeline stages: `🎯 Hedef` (Researched target—excluded from `Toplam Başvuru`) · `📨 Başvuruldu` · `💻 OA / Teknik Test` · `🗣️ Mülakat` · `🎉 Teklif / Kabul` · `❌ Red / İptal`.

## Workflow

### Mode 1 — Pipeline & 4-Track Recommendations
1. Read `reports/applications.md` and `profile.md`.
2. **If researching internships:** Search 4 tracks matching `profile.md`: (1) Global Remote / OS / Research Fellowships (CERN, MLH, LFX, GSoC, remote Cloud/Go/Rust), (2) İzmir Local/Hybrid R&D (Jotform, Rapsodo, HUGO BOSS, Teknopark İzmir/DEPARK), (3) National/Defense 3rd-Year (USP, ASELSAN, HAVELSAN, TUSAŞ, STM), (4) TR Tech/Cloud/Backend (Trendyol, Vodafone, Softtech, İş Bankası). Verify hard eligibility on the **company's own official career domain** (not aggregator homepages; if an ATS SPA returns an empty shell on standard fetch, fall back to the `singlefile` MCP server or `./.agents/skills/media-web-archiver/scripts/archive.sh "<URL>"`), pick proof/projects to highlight, and add as `🎯 Hedef` (`TGT-XX`).
3. **If logging/updating:** Keep sequential IDs (`APP-XX` submitted, `TGT-XX` target; promote `TGT` -> `APP` on submit). Sync all sections of `reports/applications.md`:
   - `Özet ve İstatistikler`: `Toplam Başvuru` (excludes `🎯 Hedef`), `Aktif Süreç` (`Başvuruldu + OA + Mülakat`), `Dönüş Oranı` (`(OA+Mülakat+Teklif+Red)/Toplam`), `İlerleme Oranı` (`(OA+Mülakat+Teklif)/Toplam`).
   - `Yaklaşan Tarihler` (soonest first), `Kanban Panosu`, `Başvuru ve Hedef Tablosu`, and timestamped `Detaylı Süreç ve Mülakat Notları`.
4. Ensure every entry in both `reports/applications.md` and chat includes a clickable official link `[Program / Şirket](official-url)`.

### Mode 2 — CV & ATS Matching
1. Parse target posting for hard constraints (graduation year, location, visa), core tech, and nice-to-haves. Flag graduation/location disqualifications immediately as **ELENME RİSKİ**.
2. Compute estimated ATS alignment (`%XX`), list **Eşleşen Güçlü Yetenekler**, **Eksik / Aranılan Anahtar Kelimeler**, and **İkame Edilebilirler**, and draft 2–3 tailored CV/cover-letter bullets + 1–2 interview prep topics.

### Mode 3 — Project & Portfolio Coach
1. Challenge decisions directly without auto-joining; name clashes with existing commitments in `profile.md` (light overlap is not an automatic skip).
2. Audit projects against the **Portfolio Readiness Checklist**:
   - **Problem & Architecture:** Clear 1-sentence value prop + architecture/data flow diagram.
   - **Demo / Proof:** Live link, video, or animated GIF in README.
   - **Reproducibility:** 1-step local run command (`docker compose up` or minimal dev command).
   - **Hygiene:** Automated tests, CI badge, open-source license.
3. Write portfolio text in clean English based strictly on shipped projects/writing (never present prompts alone as portfolio cases).

## Output

- **Mode 1:** Maintain `reports/applications.md` schema (`📊 Özet ve İstatistikler`, `⏰ Yaklaşan Tarihler ve Hatırlatıcılar`, `🔍 Profiline Özel Önerilen Staj Stratejisi (4 Kulvar)`, `📋 Kanban Panosu`, `🗂️ Başvuru ve Hedef Tablosu`, `📝 Detaylı Süreç ve Mülakat Notları`); summarize concisely in chat with clickable `[Name](official-url)` links.
- **Mode 2:** Concise `# ATS & CV Eşleştirme Raporu: [Pozisyon / Şirket]` (`Genel Uyum Skoru`, `Uygunluk Durumu`, `Kritik Kriterler`, `Anahtar Kelime Analizi`, `CV İyileştirme Önerileri`, `Mülakat / Hazırlık Notu`).
- **Mode 3:** Short, plain coaching response (no buzzwords, no ✅/⚠️/❌ opportunity marks).

## Constraints

- Never invent applications, dates, OA scores, referrals, or unpossessed skills (`belirsiz` / `—` if missing). Do not modify `ArdaArasCavdur_CV.pdf` unless asked.
- Every program/company mentioned in Mode 1 chat or `reports/applications.md` must use its verified official clickable URL.
