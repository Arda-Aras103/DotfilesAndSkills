#!/usr/bin/env python3
"""
Normalize, deduplicate, and sort English vocabulary entries into
/workspace/notes/40-english/vocabulary.md, and generate a fast,
offline single-file Tokyo Night viewer at /workspace/apps/vocab.html.

Usage:
  python3 /workspace/scripts/build_vocab.py                 # Rebuild vocab.html from vocabulary.md
  python3 /workspace/scripts/build_vocab.py --normalize     # Deduplicate & sort vocabulary.md + rebuild HTML
  python3 /workspace/scripts/build_vocab.py --import-inbox  # Merge 00-inbox.md into vocabulary.md + rebuild HTML
"""

import argparse
import json
import re
from collections import OrderedDict
from pathlib import Path

WORKSPACE = Path("/workspace")
VOCAB_MD = WORKSPACE / "notes" / "40-english" / "vocabulary.md"
INBOX_MD = WORKSPACE / "notes" / "00-inbox.md"
VOCAB_HTML = WORKSPACE / "apps" / "vocab.html"


def clean_line(s: str) -> str:
    return s.replace("\u00a0", " ").replace("\u200b", "").strip()


def format_kv_bullet(item: str, italicize_example: bool = False) -> str:
    """Ensure '- **Key:** value' formatting cleanly."""
    item = item.strip()
    # Already bolded key?
    if item.startswith("**"):
        return f"- {item}"
    m = re.match(r"^([^:]{1,60}):\s*(.+)$", item)
    if m:
        key, val = m.group(1).strip(), m.group(2).strip()
        if italicize_example and "(*" not in val:
            # Italicize inline parenthetical example like (foo bar — baz)
            val = re.sub(
                r"\(([A-Za-z][^()—–-]{1,60}?)\s+[—–-]\s+([^()]+)\)",
                r"(*\1* — \2)",
                val,
            )
        return f"- **{key}:** {val}"
    return f"- {item}"


def parse_block(word: str, block: list[str]) -> dict:
    okunus = ""
    tur = ""
    anlamlar = []
    kaliplar = []
    ornekler = []

    section = "meta"
    for l in block:
        if re.match(r"^[-─━*]+$", l) or l.startswith("# "):
            continue
        if re.match(r"^(?:###\s+)?Anlamlar$", l):
            section = "anlamlar"
            continue
        if re.match(r"^(?:###\s+)?Kalıplar$", l):
            section = "kaliplar"
            continue
        if re.match(r"^(?:###\s+)?Örnek(?:ler)?$", l):
            section = "ornek"
            continue

        if section == "meta":
            m_ok = re.match(r"^[•\-*]\s*(?:\*\*)?Okunuş:(?:\*\*)?\s*(.+)$", l)
            m_tur = re.match(r"^[•\-*]\s*(?:\*\*)?Tür:(?:\*\*)?\s*(.+)$", l)
            if m_ok:
                okunus = m_ok.group(1).strip()
            elif m_tur:
                tur = m_tur.group(1).strip()
        elif section == "anlamlar":
            item = re.sub(r"^[•\-*]\s*", "", l).strip()
            if item:
                anlamlar.append(item)
        elif section == "kaliplar":
            item = re.sub(r"^[•\-*]\s*", "", l).strip()
            if item:
                kaliplar.append(item)
        elif section == "ornek":
            item = re.sub(r"^[>│]\s*", "", l).strip()
            if item:
                ornekler.append(item)

    return {
        "word": word.strip(),
        "okunus": okunus,
        "tur": tur,
        "anlamlar": anlamlar,
        "kaliplar": kaliplar,
        "ornekler": ornekler,
    }


def parse_markdown(text: str) -> list[dict]:
    lines = [clean_line(l) for l in text.splitlines()]
    if lines and lines[-1].endswith("**") and not lines[-1].startswith("**"):
        lines[-1] = lines[-1][:-2].rstrip()

    non_empty = [(i, l) for i, l in enumerate(lines) if l]
    starts = []
    for idx_in_ne, (line_no, l) in enumerate(non_empty):
        if l.startswith("## "):
            starts.append((line_no, l[3:].strip()))
        elif (
            not l.startswith("#")
            and not l.startswith("-")
            and not l.startswith("•")
            and not l.startswith("│")
            and not l.startswith(">")
            and not re.match(r"^[-─━*]+$", l)
            and l not in ("Anlamlar", "Kalıplar", "Örnek", "<!-- Yakalama -->")
        ):
            if idx_in_ne + 1 < len(non_empty):
                nxt = non_empty[idx_in_ne + 1][1]
                if re.match(r"^[•\-*]\s*(?:\*\*)?(?:Okunuş|Tür):(?:\*\*)?", nxt):
                    starts.append((line_no, l.strip()))

    entries = []
    for k, (start_line, word) in enumerate(starts):
        end_line = starts[k + 1][0] if k + 1 < len(starts) else len(lines)
        block = [l for l in lines[start_line + 1 : end_line] if l]
        while block and (re.match(r"^[-─━*]+$", block[-1]) or block[-1].startswith("# ")):
            block.pop()
        entries.append(parse_block(word, block))
    return entries


def richness_score(e: dict) -> tuple:
    return (
        1 if e["okunus"] else 0,
        1 if e["kaliplar"] else 0,
        1 if e["ornekler"] else 0,
        len(e["anlamlar"]),
        len(e["kaliplar"]),
        len(e["ornekler"]),
        sum(len(x) for x in e["anlamlar"]),
    )


def dedupe_and_merge(entries: list[dict]) -> tuple[list[dict], int]:
    grouped: dict[str, list[dict]] = {}
    for e in entries:
        key = e["word"].strip().lower()
        grouped.setdefault(key, []).append(e)

    merged = []
    dups_removed = 0
    for key, group in grouped.items():
        if len(group) > 1:
            dups_removed += len(group) - 1
        # Sort candidates by richness descending
        group_sorted = sorted(group, key=richness_score, reverse=True)
        best = dict(group_sorted[0])
        # Normalize headword to lowercase unless it starts with "What " or is an acronym
        w = best["word"].strip()
        if not (w.isupper() and len(w) <= 5):
            w = w[0].lower() + w[1:] if w else w
        best["word"] = w

        # Fill missing fields from secondary duplicates
        for other in group_sorted[1:]:
            if not best["okunus"] and other["okunus"]:
                best["okunus"] = other["okunus"]
            if not best["tur"] and other["tur"]:
                best["tur"] = other["tur"]
            if not best["kaliplar"] and other["kaliplar"]:
                best["kaliplar"] = other["kaliplar"]
            if not best["ornekler"] and other["ornekler"]:
                best["ornekler"] = other["ornekler"]
            # If secondary has extra distinct meanings (different POS), append them
            existing_lower = {re.sub(r"\W+", "", x.lower())[:25] for x in best["anlamlar"]}
            for a in other["anlamlar"]:
                sig = re.sub(r"\W+", "", a.lower())[:25]
                if sig and sig not in existing_lower and len(best["anlamlar"]) < 6:
                    best["anlamlar"].append(a)
                    existing_lower.add(sig)

        merged.append(best)

    merged.sort(key=lambda e: e["word"].lower())
    return merged, dups_removed


def render_markdown(entries: list[dict]) -> str:
    out = [
        "# İngilizce Kelime Sözlüğü",
        "",
        f"> Toplam **{len(entries)}** benzersiz kelime · Alfabetik sıralı · Hızlı arama için `apps/vocab.html`",
        "",
    ]
    for e in entries:
        out.append(f"## {e['word']}")
        if e["okunus"]:
            out.append(f"- **Okunuş:** {e['okunus']}")
        else:
            out.append("- **Okunuş:** —")
        out.append(f"- **Tür:** {e['tur'] or '—'}")
        out.append("")
        out.append("### Anlamlar")
        for a in e["anlamlar"]:
            out.append(format_kv_bullet(a, italicize_example=True))
        if e["kaliplar"]:
            out.append("")
            out.append("### Kalıplar")
            for k in e["kaliplar"]:
                out.append(format_kv_bullet(k))
        if e["ornekler"]:
            out.append("")
            out.append("### Örnek")
            for o in e["ornekler"]:
                out.append(f"> {o}")
        out.append("")
        out.append("---")
        out.append("")
    return "\n".join(out).rstrip() + "\n"


def strip_md_inline(s: str) -> str:
    s = re.sub(r"\*\*(.+?)\*\*", r"\1", s)
    s = re.sub(r"\*(.+?)\*", r"\1", s)
    return s


def build_html(entries: list[dict]) -> str:
    # Compact payload: [word, ipa, pos, meanings[], phrases[], examples[]]
    payload = []
    for e in entries:
        payload.append([
            e["word"],
            e["okunus"],
            e["tur"],
            [strip_md_inline(a) for a in e["anlamlar"]],
            [strip_md_inline(k) for k in e["kaliplar"]],
            e["ornekler"],
        ])
    data_json = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    # Escape </script> just in case
    data_json = data_json.replace("</", "<\\/")

    return f"""<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>İngilizce Sözlük ({len(entries)} Kelime)</title>
<style>
  :root {{
    --bg: #1a1b26;
    --bg-dark: #16161e;
    --card: #24283b;
    --card-hover: #292e42;
    --border: #3b4261;
    --fg: #c0caf5;
    --fg-dim: #7982a9;
    --fg-bright: #e0e8ff;
    --blue: #7aa2f7;
    --cyan: #7dcfff;
    --purple: #bb9af7;
    --green: #9ece6a;
    --orange: #ff9e64;
    --yellow: #e0af68;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    font-family: Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: var(--bg);
    color: var(--fg);
    line-height: 1.55;
    min-height: 100vh;
  }}
  header {{
    position: sticky;
    top: 0;
    z-index: 20;
    background: rgba(22, 22, 30, 0.94);
    backdrop-filter: blur(10px);
    border-bottom: 1px solid var(--border);
    padding: 14px 18px 10px;
  }}
  .top-row {{
    max-width: 1100px;
    margin: 0 auto 10px;
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
    align-items: center;
  }}
  .brand {{
    font-weight: 700;
    font-size: 1.05rem;
    color: var(--blue);
    white-space: nowrap;
    margin-right: 4px;
  }}
  .search-wrap {{
    flex: 1 1 280px;
    position: relative;
  }}
  #search {{
    width: 100%;
    background: var(--card);
    border: 1px solid var(--border);
    color: var(--fg-bright);
    padding: 9px 70px 9px 14px;
    border-radius: 8px;
    font-size: 0.95rem;
    outline: none;
    transition: border-color .15s;
  }}
  #search:focus {{ border-color: var(--blue); }}
  .shortcut {{
    position: absolute;
    right: 10px;
    top: 50%;
    transform: translateY(-50%);
    font-size: 0.72rem;
    color: var(--fg-dim);
    background: var(--bg-dark);
    border: 1px solid var(--border);
    border-radius: 4px;
    padding: 2px 6px;
    pointer-events: none;
  }}
  .controls {{
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
    align-items: center;
  }}
  select, button {{
    background: var(--card);
    color: var(--fg);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 8px 11px;
    font-size: 0.85rem;
    cursor: pointer;
    transition: background .15s, border-color .15s;
  }}
  button:hover, select:hover {{ background: var(--card-hover); border-color: var(--blue); }}
  button.active {{ background: var(--blue); color: var(--bg-dark); border-color: var(--blue); font-weight: 600; }}
  .alpha-bar {{
    max-width: 1100px;
    margin: 0 auto;
    display: flex;
    gap: 3px;
    flex-wrap: wrap;
    align-items: center;
  }}
  .alpha-btn {{
    padding: 3px 7px;
    font-size: 0.76rem;
    border-radius: 5px;
    min-width: 26px;
    text-align: center;
  }}
  .meta-bar {{
    max-width: 1100px;
    margin: 10px auto 0;
    padding: 0 18px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 0.82rem;
    color: var(--fg-dim);
  }}
  main {{
    max-width: 1100px;
    margin: 12px auto 40px;
    padding: 0 18px;
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
    gap: 12px;
  }}
  .card {{
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 14px 16px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    transition: border-color .15s, transform .1s;
  }}
  .card:hover {{ border-color: var(--blue); }}
  .card-head {{
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: 8px;
    flex-wrap: wrap;
  }}
  .word {{
    font-size: 1.18rem;
    font-weight: 700;
    color: var(--fg-bright);
  }}
  .ipa {{
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 0.82rem;
    color: var(--cyan);
  }}
  .pos {{
    font-size: 0.75rem;
    color: var(--purple);
    background: rgba(187, 154, 247, 0.12);
    border: 1px solid rgba(187, 154, 247, 0.25);
    padding: 1px 7px;
    border-radius: 99px;
  }}
  .section-label {{
    font-size: 0.72rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--fg-dim);
    margin-top: 2px;
  }}
  ul {{ list-style: none; display: flex; flex-direction: column; gap: 3px; }}
  li {{ font-size: 0.9rem; }}
  .phrases li {{ color: var(--green); font-size: 0.86rem; }}
  .example {{
    border-left: 3px solid var(--blue);
    padding-left: 10px;
    font-size: 0.86rem;
    color: var(--fg);
    background: rgba(22, 22, 30, 0.45);
    padding: 6px 10px;
    border-radius: 0 6px 6px 0;
  }}
  .example .tr {{ color: var(--fg-dim); display: block; margin-top: 2px; }}
  .quiz-hidden .card-body {{ filter: blur(6px); user-select: none; cursor: pointer; transition: filter .15s; }}
  .quiz-hidden .card.revealed .card-body {{ filter: none; user-select: auto; }}
  .load-more-wrap {{
    max-width: 1100px;
    margin: 0 auto 50px;
    text-align: center;
  }}
  #loadMore {{
    padding: 10px 26px;
    font-weight: 600;
    color: var(--blue);
  }}
  mark {{
    background: rgba(224, 175, 104, 0.28);
    color: var(--yellow);
    border-radius: 3px;
    padding: 0 2px;
  }}
  @media (max-width: 600px) {{
    main {{ grid-template-columns: 1fr; padding: 0 10px; }}
    header {{ padding: 10px 10px 8px; }}
  }}
</style>
</head>
<body>
<header>
  <div class="top-row">
    <div class="brand">Sözlük</div>
    <div class="search-wrap">
      <input id="search" type="search" placeholder="Kelime, Türkçe anlam veya kalıp ara..." autocomplete="off" autofocus>
      <span class="shortcut">/</span>
    </div>
    <div class="controls">
      <select id="posFilter" title="Kelime türü">
        <option value="">Tüm Türler</option>
        <option value="isim">İsim</option>
        <option value="fiil">Fiil</option>
        <option value="sıfat">Sıfat</option>
        <option value="zarf">Zarf</option>
        <option value="deyim">Deyim / Öbek</option>
      </select>
      <button id="quizBtn" title="Anlamları gizle, karta tıklayınca göster">Quiz Modu</button>
      <button id="randomBtn" title="Rastgele kelime getir">Rastgele</button>
    </div>
  </div>
  <div class="alpha-bar" id="alphaBar"></div>
</header>

<div class="meta-bar">
  <span id="stats">Yükleniyor...</span>
  <span id="quizHint" style="display:none;color:var(--yellow)">Quiz modu açık — anlamı görmek için karta tıkla</span>
</div>

<main id="grid"></main>
<div class="load-more-wrap">
  <button id="loadMore" style="display:none">Daha fazla göster</button>
</div>

<script>
const RAW = {data_json};

const norm = s => (s || "").toLowerCase()
  .replace(/İ/g, "i").replace(/ı/g, "i").replace(/ş/g, "s")
  .replace(/ğ/g, "g").replace(/ü/g, "u").replace(/ö/g, "o").replace(/ç/g, "c");

const DATA = RAW.map(r => ({{
  w: r[0],
  ipa: r[1],
  pos: r[2],
  m: r[3],
  p: r[4],
  ex: r[5],
  wNorm: norm(r[0]),
  posNorm: norm(r[2]),
  blob: norm([r[0], r[2], ...r[3], ...r[4], ...r[5]].join(" "))
}}));

let activeLetter = "";
let filtered = DATA;
let shown = 0;
const PAGE = 60;
let quizMode = false;

const searchEl = document.getElementById("search");
const posEl = document.getElementById("posFilter");
const gridEl = document.getElementById("grid");
const statsEl = document.getElementById("stats");
const loadMoreEl = document.getElementById("loadMore");
const alphaBar = document.getElementById("alphaBar");
const quizBtn = document.getElementById("quizBtn");
const quizHint = document.getElementById("quizHint");
const randomBtn = document.getElementById("randomBtn");

const letters = ["Tümü", ..."ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("")];
letters.forEach(lt => {{
  const b = document.createElement("button");
  b.className = "alpha-btn" + (lt === "Tümü" ? " active" : "");
  b.textContent = lt;
  b.onclick = () => {{
    activeLetter = lt === "Tümü" ? "" : lt.toLowerCase();
    document.querySelectorAll(".alpha-btn").forEach(x => x.classList.remove("active"));
    b.classList.add("active");
    applyFilter();
  }};
  alphaBar.appendChild(b);
}});

function esc(s) {{
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}}

function renderCard(item) {{
  const card = document.createElement("article");
  card.className = "card";
  card.onclick = () => {{ if (quizMode) card.classList.toggle("revealed"); }};

  const meaningsHtml = item.m.map(x => `<li>${{esc(x)}}</li>`).join("");
  const phrasesHtml = item.p.length
    ? `<div class="section-label">Kalıplar</div><ul class="phrases">${{item.p.map(x => `<li>${{esc(x)}}</li>`).join("")}}</ul>`
    : "";
  let exHtml = "";
  if (item.ex.length) {{
    const lines = item.ex.map(line =>
      line.startsWith("(") ? `<span class="tr">${{esc(line)}}</span>` : `<div>${{esc(line)}}</div>`
    ).join("");
    exHtml = `<div class="section-label">Örnek</div><div class="example">${{lines}}</div>`;
  }}

  card.innerHTML = `
    <div class="card-head">
      <div>
        <span class="word">${{esc(item.w)}}</span>
        ${{item.ipa ? `<span class="ipa">${{esc(item.ipa)}}</span>` : ""}}
      </div>
      ${{item.pos ? `<span class="pos">${{esc(item.pos)}}</span>` : ""}}
    </div>
    <div class="card-body">
      <ul>${{meaningsHtml}}</ul>
      ${{phrasesHtml}}
      ${{exHtml}}
    </div>
  `;
  return card;
}}

function renderMore() {{
  const frag = document.createDocumentFragment();
  const next = filtered.slice(shown, shown + PAGE);
  next.forEach(item => frag.appendChild(renderCard(item)));
  gridEl.appendChild(frag);
  shown += next.length;
  loadMoreEl.style.display = shown < filtered.length ? "inline-block" : "none";
  loadMoreEl.textContent = `Daha fazla göster (${{shown}} / ${{filtered.length}})`;
}}

function applyFilter() {{
  const q = norm(searchEl.value.trim());
  const pos = norm(posEl.value);

  filtered = DATA.filter(item => {{
    if (activeLetter && !item.wNorm.startsWith(activeLetter)) return false;
    if (pos) {{
      if (pos === "deyim") {{
        if (!item.posNorm.includes("deyim") && !item.posNorm.includes("obek") && !item.posNorm.includes("tamlama") && !item.posNorm.includes("kalip")) return false;
      }} else if (!item.posNorm.includes(pos)) return false;
    }}
    if (q && !item.blob.includes(q)) return false;
    return true;
  }});

  // Rank exact/prefix word matches first when searching
  if (q) {{
    filtered.sort((a, b) => {{
      const aExact = a.wNorm === q ? 0 : a.wNorm.startsWith(q) ? 1 : a.wNorm.includes(q) ? 2 : 3;
      const bExact = b.wNorm === q ? 0 : b.wNorm.startsWith(q) ? 1 : b.wNorm.includes(q) ? 2 : 3;
      return aExact - bExact || a.wNorm.localeCompare(b.wNorm);
    }});
  }}

  gridEl.innerHTML = "";
  shown = 0;
  statsEl.textContent = `${{filtered.length}} / ${{DATA.length}} kelime gösteriliyor`;
  renderMore();
}}

let timer;
searchEl.addEventListener("input", () => {{
  clearTimeout(timer);
  timer = setTimeout(applyFilter, 60);
}});
posEl.addEventListener("change", applyFilter);
loadMoreEl.addEventListener("click", renderMore);

quizBtn.addEventListener("click", () => {{
  quizMode = !quizMode;
  quizBtn.classList.toggle("active", quizMode);
  gridEl.classList.toggle("quiz-hidden", quizMode);
  quizHint.style.display = quizMode ? "inline" : "none";
  document.querySelectorAll(".card.revealed").forEach(c => c.classList.remove("revealed"));
}});

randomBtn.addEventListener("click", () => {{
  const pool = filtered.length ? filtered : DATA;
  const pick = pool[Math.floor(Math.random() * pool.length)];
  gridEl.innerHTML = "";
  gridEl.appendChild(renderCard(pick));
  shown = 1;
  loadMoreEl.style.display = "none";
  statsEl.textContent = `Rastgele kelime (havuz: ${{pool.length}}) — tüm listeye dönmek için aramayı değiştir`;
}});

document.addEventListener("keydown", e => {{
  if (e.key === "/" && document.activeElement !== searchEl) {{
    e.preventDefault();
    searchEl.focus();
    searchEl.select();
  }} else if (e.key === "Escape" && document.activeElement === searchEl) {{
    searchEl.value = "";
    applyFilter();
  }}
}});

applyFilter();
</script>
</body>
</html>
"""


def main():
    parser = argparse.ArgumentParser(description="Normalize vocabulary.md and build offline vocab.html")
    parser.add_argument("--import-inbox", action="store_true", help="Import & merge notes/00-inbox.md into vocabulary.md")
    parser.add_argument("--normalize", action="store_true", help="Deduplicate & alphabetically sort vocabulary.md")
    args = parser.parse_args()

    entries = []
    if VOCAB_MD.exists():
        entries.extend(parse_markdown(VOCAB_MD.read_text(encoding="utf-8")))

    inbox_count = 0
    if args.import_inbox and INBOX_MD.exists():
        inbox_entries = parse_markdown(INBOX_MD.read_text(encoding="utf-8"))
        inbox_count = len(inbox_entries)
        entries.extend(inbox_entries)

    if args.import_inbox or args.normalize or not VOCAB_MD.exists():
        merged, dups_removed = dedupe_and_merge(entries)
        VOCAB_MD.parent.mkdir(parents=True, exist_ok=True)
        VOCAB_MD.write_text(render_markdown(merged), encoding="utf-8")
        print(f"Wrote {VOCAB_MD}: {len(merged)} unique words (imported {inbox_count} from inbox, removed {dups_removed} duplicates)")
        entries = merged
    else:
        print(f"Loaded {VOCAB_MD}: {len(entries)} words")

    VOCAB_HTML.parent.mkdir(parents=True, exist_ok=True)
    VOCAB_HTML.write_text(build_html(entries), encoding="utf-8")
    size_kb = VOCAB_HTML.stat().st_size / 1024
    print(f"Wrote {VOCAB_HTML}: {len(entries)} words ({size_kb:.1f} KB)")


if __name__ == "__main__":
    main()
