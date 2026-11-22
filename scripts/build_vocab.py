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

WORKSPACE = Path(__file__).resolve().parent.parent
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
<title>Sözlük · {len(entries)} Kelime</title>
<style>
  :root {{
    --bg: #13141c;
    --surface: #1b1d28;
    --surface-hover: #212433;
    --border: #272b3f;
    --fg: #d8def6;
    --fg-muted: #7b83a6;
    --fg-bright: #f2f5ff;
    --accent: #7aa2f7;
    --accent-soft: rgba(122, 162, 247, 0.13);
    --mark-bg: rgba(224, 175, 104, 0.24);
    --mark-fg: #f0c674;
    --chip-bg: #161822;
    --shadow: 0 6px 24px rgba(0, 0, 0, 0.25);
  }}
  [data-theme="light"] {{
    --bg: #f8f9fc;
    --surface: #ffffff;
    --surface-hover: #f2f4fa;
    --border: #e3e7f0;
    --fg: #2b3040;
    --fg-muted: #6c748d;
    --fg-bright: #111420;
    --accent: #3b6ef5;
    --accent-soft: rgba(59, 110, 245, 0.10);
    --mark-bg: rgba(250, 204, 21, 0.35);
    --mark-fg: #111420;
    --chip-bg: #f3f5fa;
    --shadow: 0 4px 16px rgba(17, 20, 32, 0.06);
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    font-family: Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: var(--bg);
    color: var(--fg);
    line-height: 1.6;
    -webkit-font-smoothing: antialiased;
    transition: background .15s, color .15s;
  }}
  header {{
    position: sticky;
    top: 0;
    z-index: 10;
    background: color-mix(in srgb, var(--bg) 88%, transparent);
    backdrop-filter: blur(14px);
    border-bottom: 1px solid var(--border);
  }}
  .wrap {{
    max-width: 740px;
    margin: 0 auto;
    padding: 0 20px;
  }}
  .header-inner {{
    padding: 16px 0 11px;
  }}
  .search-row {{
    display: flex;
    align-items: center;
    gap: 8px;
  }}
  .search-box {{
    position: relative;
    flex: 1;
    display: flex;
    align-items: center;
  }}
  .search-icon {{
    position: absolute;
    left: 14px;
    color: var(--fg-muted);
    pointer-events: none;
    font-size: 0.92rem;
  }}
  #search {{
    width: 100%;
    background: var(--surface);
    border: 1px solid var(--border);
    color: var(--fg-bright);
    padding: 11px 92px 11px 38px;
    border-radius: 11px;
    font-size: 0.96rem;
    outline: none;
    transition: border-color .15s, box-shadow .15s;
  }}
  #search:focus {{
    border-color: var(--accent);
    box-shadow: 0 0 0 3px var(--accent-soft);
  }}
  #search::placeholder {{ color: var(--fg-muted); }}
  .count {{
    position: absolute;
    right: 14px;
    font-size: 0.76rem;
    color: var(--fg-muted);
    pointer-events: none;
    font-variant-numeric: tabular-nums;
  }}
  .icon-btn {{
    background: var(--surface);
    border: 1px solid var(--border);
    color: var(--fg-muted);
    width: 42px;
    height: 42px;
    border-radius: 11px;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    font-size: 1rem;
    transition: border-color .15s, color .15s;
    flex-shrink: 0;
  }}
  .icon-btn:hover {{ border-color: var(--accent); color: var(--fg-bright); }}
  .alpha {{
    display: flex;
    gap: 2px;
    flex-wrap: wrap;
    margin-top: 10px;
  }}
  .alpha button {{
    background: transparent;
    border: none;
    color: var(--fg-muted);
    font-size: 0.76rem;
    padding: 3px 6px;
    border-radius: 6px;
    cursor: pointer;
    transition: color .12s, background .12s;
  }}
  .alpha button:hover {{ color: var(--fg-bright); background: var(--surface); }}
  .alpha button.active {{ color: var(--accent); font-weight: 600; background: var(--accent-soft); }}
  main {{
    padding: 14px 0 72px;
  }}
  .entry {{
    border: 1px solid transparent;
    border-bottom-color: var(--border);
    padding: 14px 12px;
    border-radius: 0;
    cursor: pointer;
    transition: background .12s, border-color .12s, border-radius .12s;
  }}
  .entry:hover {{
    background: var(--surface);
    border-radius: 10px;
    border-color: transparent;
  }}
  .entry.open {{
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 12px;
    margin: 8px 0;
    padding: 16px 18px;
    box-shadow: var(--shadow);
  }}
  .entry-head {{
    display: flex;
    align-items: center;
    gap: 10px;
  }}
  .word-group {{
    display: flex;
    align-items: baseline;
    gap: 9px;
    flex-wrap: wrap;
    flex: 1;
    min-width: 0;
  }}
  .word {{
    font-size: 1.08rem;
    font-weight: 650;
    color: var(--fg-bright);
    letter-spacing: -0.01em;
  }}
  .ipa {{
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 0.8rem;
    color: var(--fg-muted);
  }}
  .speak-btn {{
    background: transparent;
    border: none;
    color: var(--fg-muted);
    cursor: pointer;
    font-size: 0.86rem;
    padding: 2px 5px;
    border-radius: 6px;
    line-height: 1;
    transition: color .12s, background .12s;
  }}
  .speak-btn:hover {{ color: var(--accent); background: var(--accent-soft); }}
  .pos {{
    font-size: 0.77rem;
    color: var(--accent);
    white-space: nowrap;
  }}
  .chev {{
    color: var(--fg-muted);
    font-size: 0.9rem;
    transition: transform .16s ease;
    user-select: none;
  }}
  .entry.open .chev {{ transform: rotate(90deg); color: var(--accent); }}
  .summary {{
    margin-top: 4px;
    font-size: 0.9rem;
    color: var(--fg-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }}
  .entry.open .summary {{ display: none; }}
  .details {{
    display: none;
    margin-top: 12px;
    padding-top: 12px;
    border-top: 1px solid var(--border);
  }}
  .entry.open .details {{ display: block; }}
  .meanings {{
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 5px;
  }}
  .meanings li {{
    font-size: 0.94rem;
    color: var(--fg);
  }}
  .sub-block {{
    margin-top: 12px;
  }}
  .sub-label {{
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--fg-muted);
    margin-bottom: 6px;
    font-weight: 600;
  }}
  .phrases {{
    list-style: none;
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }}
  .phrases li {{
    font-size: 0.84rem;
    color: var(--fg);
    background: var(--chip-bg);
    border: 1px solid var(--border);
    padding: 4px 10px;
    border-radius: 7px;
  }}
  .example {{
    border-left: 2px solid var(--accent);
    padding: 2px 0 2px 12px;
    font-size: 0.9rem;
    color: var(--fg);
  }}
  .example .tr {{
    display: block;
    color: var(--fg-muted);
    font-size: 0.86rem;
    margin-top: 3px;
  }}
  mark {{
    background: var(--mark-bg);
    color: var(--mark-fg);
    border-radius: 3px;
    padding: 0 2px;
  }}
  .more-wrap {{
    text-align: center;
    margin-top: 24px;
  }}
  #loadMore {{
    background: var(--surface);
    color: var(--fg);
    border: 1px solid var(--border);
    padding: 9px 22px;
    border-radius: 9px;
    font-size: 0.85rem;
    cursor: pointer;
    transition: border-color .15s, color .15s;
  }}
  #loadMore:hover {{ border-color: var(--accent); color: var(--fg-bright); }}
  .empty {{
    text-align: center;
    color: var(--fg-muted);
    padding: 56px 0;
    font-size: 0.95rem;
  }}
  @media (max-width: 600px) {{
    .wrap {{ padding: 0 12px; }}
    .entry {{ padding: 13px 8px; }}
    .entry.open {{ padding: 14px 14px; }}
    .pos {{ display: none; }}
    .entry.open .pos {{ display: inline; }}
  }}
</style>
</head>
<body>
<header>
  <div class="wrap header-inner">
    <div class="search-row">
      <div class="search-box">
        <span class="search-icon">⌕</span>
        <input id="search" type="search" placeholder="Kelime, anlam veya kalıp ara... (/)" autocomplete="off" autofocus>
        <span class="count" id="stats">{len(entries)} kelime</span>
      </div>
      <button class="icon-btn" id="themeBtn" title="Açık / Koyu Tema">◐</button>
    </div>
    <nav class="alpha" id="alphaBar"></nav>
  </div>
</header>

<main class="wrap">
  <div id="list"></div>
  <div class="more-wrap">
    <button id="loadMore" style="display:none">Daha fazla göster</button>
  </div>
</main>

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
  blob: norm([r[0], ...r[3], ...r[4], ...r[5]].join(" "))
}}));

let activeLetter = "";
let currentQuery = "";
let filtered = DATA;
let shown = 0;
const PAGE = 80;

const searchEl = document.getElementById("search");
const listEl = document.getElementById("list");
const statsEl = document.getElementById("stats");
const loadMoreEl = document.getElementById("loadMore");
const alphaBar = document.getElementById("alphaBar");
const themeBtn = document.getElementById("themeBtn");

const savedTheme = localStorage.getItem("vocab-theme");
if (savedTheme === "light") document.documentElement.setAttribute("data-theme", "light");
themeBtn.onclick = () => {{
  const isLight = document.documentElement.getAttribute("data-theme") === "light";
  if (isLight) {{
    document.documentElement.removeAttribute("data-theme");
    localStorage.setItem("vocab-theme", "dark");
  }} else {{
    document.documentElement.setAttribute("data-theme", "light");
    localStorage.setItem("vocab-theme", "light");
  }}
}};

["Tümü", ..."ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("")].forEach(lt => {{
  const b = document.createElement("button");
  b.textContent = lt;
  if (lt === "Tümü") b.className = "active";
  b.onclick = () => {{
    activeLetter = lt === "Tümü" ? "" : lt.toLowerCase();
    alphaBar.querySelectorAll("button").forEach(x => x.classList.remove("active"));
    b.classList.add("active");
    applyFilter();
  }};
  alphaBar.appendChild(b);
}});

const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

function highlight(text, q) {{
  const safe = esc(text);
  if (!q || q.length < 2) return safe;
  const re = new RegExp("(" + q.replace(/[.*+?^${{}}()|[\\]\\\\]/g, "\\\\$&") + ")", "gi");
  return safe.replace(re, "<mark>$1</mark>");
}}

function speak(word, ev) {{
  ev.stopPropagation();
  if (!("speechSynthesis" in window)) return;
  window.speechSynthesis.cancel();
  const u = new SpeechSynthesisUtterance(word);
  u.lang = "en-US";
  u.rate = 0.95;
  window.speechSynthesis.speak(u);
}}

function renderEntry(item, autoOpen) {{
  const el = document.createElement("article");
  el.className = "entry" + (autoOpen ? " open" : "");
  el.onclick = () => el.classList.toggle("open");

  const q = currentQuery;
  const firstMeaning = item.m[0] || "";
  const meanings = item.m.map(x => `<li>${{highlight(x, q)}}</li>`).join("");
  const phrases = item.p.length
    ? `<div class="sub-block"><div class="sub-label">Kalıplar</div><ul class="phrases">${{item.p.map(x => `<li>${{highlight(x, q)}}</li>`).join("")}}</ul></div>`
    : "";
  let examples = "";
  if (item.ex.length) {{
    const lines = item.ex.map(l => l.startsWith("(") ? `<span class="tr">${{esc(l)}}</span>` : `<div>${{esc(l)}}</div>`).join("");
    examples = `<div class="sub-block"><div class="sub-label">Örnek</div><div class="example">${{lines}}</div></div>`;
  }}

  el.innerHTML = `
    <div class="entry-head">
      <div class="word-group">
        <span class="word">${{highlight(item.w, q)}}</span>
        ${{item.ipa && item.ipa !== "—" ? `<span class="ipa">${{esc(item.ipa)}}</span>` : ""}}
        <button class="speak-btn" title="Telaffuzu dinle" aria-label="Dinle">🔊</button>
      </div>
      ${{item.pos ? `<span class="pos">${{esc(item.pos)}}</span>` : ""}}
      <span class="chev">›</span>
    </div>
    <div class="summary">${{highlight(firstMeaning, q)}}</div>
    <div class="details">
      <ul class="meanings">${{meanings}}</ul>
      ${{phrases}}
      ${{examples}}
    </div>
  `;
  el.querySelector(".speak-btn").onclick = ev => speak(item.w, ev);
  return el;
}}

function renderMore() {{
  const frag = document.createDocumentFragment();
  const autoOpen = filtered.length <= 5;
  const next = filtered.slice(shown, shown + PAGE);
  next.forEach(item => frag.appendChild(renderEntry(item, autoOpen)));
  listEl.appendChild(frag);
  shown += next.length;
  loadMoreEl.style.display = shown < filtered.length ? "inline-block" : "none";
  loadMoreEl.textContent = `Daha fazla göster (${{shown}} / ${{filtered.length}})`;
}}

function applyFilter() {{
  currentQuery = searchEl.value.trim();
  const q = norm(currentQuery);
  filtered = DATA.filter(item => {{
    if (activeLetter && !item.wNorm.startsWith(activeLetter)) return false;
    if (q && !item.blob.includes(q)) return false;
    return true;
  }});

  if (q) {{
    filtered.sort((a, b) => {{
      const rank = x => x.wNorm === q ? 0 : x.wNorm.startsWith(q) ? 1 : x.wNorm.includes(q) ? 2 : 3;
      return rank(a) - rank(b) || a.wNorm.localeCompare(b.wNorm);
    }});
  }}

  listEl.innerHTML = "";
  shown = 0;
  statsEl.textContent = filtered.length === DATA.length
    ? `${{DATA.length}} kelime`
    : `${{filtered.length}} / ${{DATA.length}}`;

  if (!filtered.length) {{
    listEl.innerHTML = '<div class="empty">Sonuç bulunamadı.</div>';
    loadMoreEl.style.display = "none";
    return;
  }}
  renderMore();
}}

let timer;
searchEl.addEventListener("input", () => {{
  clearTimeout(timer);
  timer = setTimeout(applyFilter, 50);
}});
loadMoreEl.addEventListener("click", renderMore);

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
