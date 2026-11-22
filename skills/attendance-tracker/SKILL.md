---
name: attendance-tracker
description: Tracks university course attendance and absence counts in reports/attendance.md. Manages per-course used absence counts, dated logs, and optional absence limits if provided. Triggers include devamsizlik, ders devamsizligi, derse gitmedim, yok yazildim, devamsizlik ekle, devamsizlik durumu, kac hakkim kaldi, attendance.
user-invocable: true
metadata:
  type: workflow
  version: "1.3"
---

# Attendance Tracker

Tracks university course absences and dated logs in `reports/attendance.md`.

## When

- Adding courses or initializing tracking (`şu dersleri ekle`, `devamsızlık takibi başlat`).
- Logging or correcting an absence (`X dersine bugün gitmedim`, `Y'den 2 ekle`, `Z devamsızlığını sil`).
- Checking current absence counts or history (`devamsızlık durumum ne`, `hangi dersten kaç günüm var`).

## Workflow

1. Read `reports/attendance.md` first (initialize using the Output template if missing).
2. Apply the update:
   - **Add Course:** Add course to summary table with `Kullanılan` (default `0`).
   - **Log Absence:** Match course name (ask if ambiguous), increment `Kullanılan`, and prepend a dated entry (`YYYY-MM-DD` for "bugün" or omitted date) to `Devamsızlık Geçmişi`.
   - **Undo / Edit:** Adjust or delete the entry and recalculate `Kullanılan`.
   - **Status Check:** Display current summary table (and history if requested).
3. Save `reports/attendance.md` with updated `Son güncelleme: YYYY-MM-DD` and reply concisely in the user's language.

## Output

Maintain `reports/attendance.md` with minimal columns (`Ders`, `Kullanılan`) by default—add quota/remaining/risk columns only if the user explicitly provides limits:

```markdown
# Ders Devamsızlık Takibi

Son güncelleme: YYYY-MM-DD

## 📊 Özet Tablo

| Ders | Kullanılan |
| :--- | :--- |
| — | 0 |

## 📝 Devamsızlık Geçmişi

- **YYYY-MM-DD** — **[Ders]** — `1`
```

## Constraints

- Store all course lists and dated logs in `reports/attendance.md`, never inside this skill file.
- Never invent a course, limit, hour count, or date.
