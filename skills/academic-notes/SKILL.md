---
name: academic-notes
description: Turns arXiv research papers, PDFs, and course or lecture transcripts into structured Markdown study notes or optional 5-level TextFold progressive digests. Extracts paper problem, architecture, benchmarks, and engineering takeaways, or merges lecture transcripts under topic headings. Triggers include arxiv, paper ozetle, makale incele, research paper, arxiv.org link, paper digest, kurs not, obsidian not, lecture paste, ozetler misin, textfold, 5 seviye, katmanli ozet.
user-invocable: true
metadata:
  type: workflow
  version: "1.3"
---

# Academic Notes

## Modes
- **Mode 1 (Paper Digest):** `arxiv.org` URL, DOI, title, or PDF -> structured card or TextFold (`textfold`, `5 seviye`, `katmanlı özet`).
- **Mode 2 (Course Notes):** Lecture/course transcript -> technical topic page (`kurs not`, `obsidian not`, `özetler misin`).

## Workflow
### Mode 1 — Research Paper
1. Extract Title, Authors, Year, Category, arXiv URL, Code/Model repo (`Veri bulunamadı` if missing). For JS-rendered pages, fall back to `singlefile` MCP or `./.agents/skills/media-web-archiver/scripts/archive.sh "<URL>"`.
2. Summarize Problem (1–2 sentences), Method/Architecture, Benchmarks (datasets + margins), Limitations & Takeaway.
3. Save to `notes/20-engineering/papers/<slug>.md` (if requested or maintaining vault) with YAML (`type: paper`, `domain`, `year`, `status`, `arxiv`, `code`, `updated`).

### Mode 2 — Course & Lecture
1. Strip timestamps (`00:14`), fillers (`um`, `yani`, `şey`), bios, emails, and marketing blurbs.
2. **One topic = one page (`notes/10-courses/<course>/<topic>.md`):** Merge under `##` headings instead of duplicating; demos -> `## DEMO — …`; recaps -> `## Course Summary` on `INDEX.md`.
3. Style: YAML (`type: lecture`, `course`, `week`, `status`, `updated`), `#` title, nested `-` bullets, `###`, Mermaid, code/JSON, relative Markdown links (`[Topic](./topic.md)`), no empty stubs.

## Output & Constraints
- **Mode 1:** 4 sections in user's language (English technical terms): `1. Problem Tanımı`, `2. Önerilen Yöntem & Mimari`, `3. Deneysel Sonuçlar & Benchmark`, `4. Sınırlılıklar & Pratik Çıkarım`. TextFold: `1. Map` -> `2. Takeaway` -> `3. Key` -> `4. Brief` -> `5. Full`.
- **Mode 2:** Write body to `notes/10-courses/...`; reply in one line with file and heading.
- Never invent metrics, margins, lecture facts, or code links (`Veri bulunamadı` if absent). One paper = one card; one topic = one page.
