#!/usr/bin/env python3
"""
Sözlük dosyasını analiz eden, kelime sayısını, format tutarlılığını
ve olası tekrarları kontrol eden taşınabilir yardımcı betik.
"""

import sys
import re
from pathlib import Path

CANDIDATE_FILENAMES = ["kelimeler.md", "vocabulary.md", "dictionary.md", "words.md"]

def find_dictionary_file(arg_path: str = None) -> Path:
    if arg_path:
        p = Path(arg_path)
        if p.exists():
            return p
        print(f"Hata: Belirtilen dosya bulunamadı: {arg_path}")
        sys.exit(1)

    cwd = Path.cwd()
    # Search in cwd and parent directories
    for check_dir in [cwd, *cwd.parents]:
        for candidate in CANDIDATE_FILENAMES:
            target = check_dir / candidate
            if target.exists():
                return target

    print("Hata: Çalışma dizininde sözlük dosyası bulunamadı (arananlar: " + ", ".join(CANDIDATE_FILENAMES) + ").")
    print("Kullanım: python3 validate_dict.py [dosya_yolu]")
    sys.exit(1)

def analyze_dictionary(path: Path):
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    words = re.findall(r"^##\s+(.+)$", text, re.MULTILINE)
    pronunciations = re.findall(r"-\s+\*\*Okunuş:\*\*", text)
    meanings = re.findall(r"###\s+Anlamlar", text)
    patterns = re.findall(r"###\s+Kalıplar", text)
    examples = re.findall(r"###\s+Örnek", text)
    quotes = re.findall(r"^>\s+(.+)$", text, re.MULTILINE)

    seen = {}
    duplicates = []
    for w in words:
        w_lower = w.strip().lower()
        if w_lower in seen:
            duplicates.append(w)
        seen[w_lower] = seen.get(w_lower, 0) + 1

    blank_lines = sum(1 for line in lines if not line.strip())

    print("=" * 55)
    print(f" SÖZLÜK DURUM RAPORU: {path.name}")
    print("=" * 55)
    print(f"Dosya Konumu          : {path.resolve()}")
    print(f"Toplam Satır          : {len(lines):,}")
    print(f"Dolu Satır            : {len(lines) - blank_lines:,}")
    print(f"Boş Satır             : {blank_lines:,} (%{blank_lines/len(lines)*100:.1f})")
    print(f"Toplam Kelime (##)    : {len(words):,}")
    print(f"Okunuş Sayısı         : {len(pronunciations):,}")
    print(f"Anlamlar Başlığı      : {len(meanings):,}")
    print(f"Kalıplar Başlığı      : {len(patterns):,}")
    print(f"Örnek Başlığı         : {len(examples):,}")
    print(f"Örnek Cümle Satırları : {len(quotes):,}")
    print("-" * 55)

    if duplicates:
        print(f"Tekrar Eden Kelimeler ({len(duplicates)} adet):")
        for d in duplicates[:10]:
            print(f"  - {d}")
        if len(duplicates) > 10:
            print(f"  ... ve {len(duplicates) - 10} kelime daha.")
    else:
        print("Tüm kelimeler benzersiz, mükerrer kayıt bulunamadı.")

    print("=" * 55)

if __name__ == "__main__":
    file_arg = sys.argv[1] if len(sys.argv) > 1 else None
    dict_path = find_dictionary_file(file_arg)
    analyze_dictionary(dict_path)
