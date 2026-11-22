#!/usr/bin/env bash
# Dotfile and shell diagnostic script
set -uo pipefail

TARGET_DIR="${1:-.}"
if [ ! -d "$TARGET_DIR" ]; then
    echo "Hata: Hedef dizin bulunamadı: $TARGET_DIR" >&2
    exit 1
fi

echo "========================================================"
echo " DOTFILE DOCTOR TEŞHİS VE DENETİM RAPORU"
echo " Hedef Dizin: $(cd "$TARGET_DIR" && pwd)"
echo " Tarih      : $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================================"

ERRORS=0
WARNINGS=0

# 1. Secret Check (Gizli anahtar / token taraması)
echo -e "\n[1] Güvenlik ve Gizli Bilgi Taraması..."
SECRET_PATTERN='(ghp_[a-zA-Z0-9]{20,}|github_pat_[a-zA-Z0-9_]{20,}|AIza[0-9A-Za-z\\-_]{35}|BEGIN (RSA|OPENSSH|DSA|EC) PRIVATE KEY|aws_access_key_id|api[_-]?key\s*=\s*['\''"][^'\''"]+['\''"])'

LEAKS=$(grep -rEIn --exclude-dir=".git" --exclude="*.log" --exclude="audit_dotfiles.sh" "$SECRET_PATTERN" "$TARGET_DIR" 2>/dev/null || true)
if [ -n "$LEAKS" ]; then
    echo "  [KRİTİK] Olası gizli anahtar/token bulundu (değerler güvenlik için maskelendi):"
    echo "$LEAKS" | cut -d: -f1,2 | sed 's/^/    - /' | head -n 10
    ERRORS=$((ERRORS + 1))
else
    echo "  [OK] Takip edilen dosyalarda token veya özel anahtar tespit edilmedi."
fi

# 2. Broken Symlink Check
echo -e "\n[2] Kırık Sembolik Bağlantı Taraması (~/)..."
BROKEN_LINKS=$(find -L "$HOME" -maxdepth 3 -type l 2>/dev/null || true)
if [ -n "$BROKEN_LINKS" ]; then
    echo "  [UYARI] Hedefi silinmiş sembolik linkler bulundu:"
    echo "$BROKEN_LINKS" | head -n 10
    WARNINGS=$((WARNINGS + 1))
else
    echo "  [OK] Kırık sembolik link bulunamadı."
fi

# 3. Shell Syntax Check (.bashrc / .profile / *.sh)
echo -e "\n[3] Kabuk Betikleri Sözdizimi Taraması (bash -n)..."
while IFS= read -r -d '' f; do
    if bash -n "$f" 2>&1; then
        echo "  [OK] $f sözdizimi geçerli."
    else
        echo "  [HATA] $f içinde sözdizimi hatası var!"
        ERRORS=$((ERRORS + 1))
    fi
done < <(find "$TARGET_DIR" -maxdepth 2 -type f \( -name "*.sh" -o -name ".bashrc" -o -name ".profile" \) -print0 2>/dev/null)

# 4. Duplicate Aliases Check
BASHRC="$TARGET_DIR/.bashrc"
if [ -f "$BASHRC" ]; then
    echo -e "\n[4] Çakışan / Yinelenen Alias Taraması (.bashrc)..."
    DUPE_ALIASES=$(grep -E '^\s*alias\s+' "$BASHRC" | sed -E 's/^\s*alias\s+([^=]+)=.*/\1/' | sort | uniq -d || true)
    if [ -n "$DUPE_ALIASES" ]; then
        echo "  [UYARI] Tekrar eden alias tanımları bulundu: $DUPE_ALIASES"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "  [OK] Tekrar eden alias tanımı bulunamadı."
    fi
fi

echo -e "\n========================================================"
echo " ÖZET: $ERRORS Kritik Hata, $WARNINGS Uyarı."
echo "========================================================"

if [ "$ERRORS" -gt 0 ]; then
    exit 1
fi
exit 0
