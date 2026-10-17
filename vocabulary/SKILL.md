---
name: vocab-builder
description: >-
  Formats English vocabulary words, word lists, or CSVs into a standardized compact Markdown dictionary entry and appends them to a vocabulary file (e.g., kelimeler.md or vocabulary.md). Activate when the user provides English words to add to their vocabulary dictionary or asks to format/process words in this dictionary format.
---

# Vocabulary Dictionary Builder

Bu skill, kullanıcının ilettiği İngilizce kelimeleri veya kelime listelerini (tek tek, virgülle ayrılmış ya da CSV formatında) standart, zengin ve kompakt bir Markdown sözlük formatına dönüştürüp çalışma alanındaki sözlük dosyasına (varsayılan: `kelimeler.md` veya `vocabulary.md`) eklemek için kullanılır.

## Sözlük Formatı Şablonu

Her kelime girdisi aşağıdaki şablona ve kompakt boşluk kurallarına tam olarak uymalıdır:

```markdown
## kelime
- **Okunuş:** /IPA/
- **Tür:** isim / fiil / sıfat / zarf / edat

### Anlamlar
- **Tür:** Türkçe anlam (*kısa örnek* — Türkçesi)
- **Tür:** İkincil Türkçe anlam (*kısa örnek* — Türkçesi)

### Kalıplar
- **phrase / collocation:** Türkçe karşılık

### Örnek
> Natural contextual English sentence.
> (Doğal ve akıcı Türkçe cümle çevirisi.)

---
```

## Kompakt Format ve Boşluk Kuralları

Dosyanın gereksiz yere uzamasını engellemek ve temiz bir Markdown görünümü sağlamak için aşağıdaki boşluk kurallarına dikkat edilmelidir:

1. Başlık (`## kelime`) ile hemen altındaki ilk madde (`- **Okunuş:**`) arasında boş satır bırakılmaz.
2. Liste maddeleri (`- **...**`) arasında boş satır bırakılmaz (sıkı liste / tight list).
3. Alt başlıklar (`### Anlamlar`, `### Kalıplar`, `### Örnek`) öncesinde yalnızca TEK bir boş satır bırakılır.
4. Alt başlık (`### Örnek`) ile örnek cümle (`> ...`) arasında boş satır bırakılmaz.
5. İki örnek cümle satırı (`>` ve `> (...)`) peş peşe yazılır.
6. Kelime sonu ayırıcısı (`---`) öncesinde ve sonrasında tek bir boş satır bulunur.

## İş Akışı ve Yönergeler

1. **Girdiyi Ayrıştırma:**
   - Kullanıcı kelimeleri tek tek, virgülle ayrılmış ya da CSV (`Word,Translation`) formatında verebilir.
   - İletilen kelimelerdeki olası yazım hatalarını (typo) tespit et ve doğru halini işle.
   - Kullanıcı Türkçe anlam vermişse bunu dikkate al; Türkçe anlam verilmemişse veya eksikse en doğru, zengin ve yaygın karşılıklarını sağla.

2. **İçerik Zenginleştirme:**
   - **Okunuş:** Uluslararası Fonetik Alfabe (IPA) standartlarında İngiliz (/UK/) ve Amerikan (/US/) telaffuzunu yaz.
   - **Tür:** Kelimenin dilbilgisel türlerini (isim, fiil, sıfat, zarf vb.) belirt.
   - **Anlamlar:** Her tür için en yaygın anlamı ve parantez içinde kısa bir kullanım örneğini (*örnek* — Türkçesi) ver.
   - **Kalıplar:** Kelimenin sık kullanıldığı bir deyim, edatlı fiil (phrasal verb) veya yaygın kelime öbeğini (collocation) ekle.
   - **Örnek Cümle:** Doğal, bağlamsal ve güncel bir İngilizce cümle ile tam Türkçe çevirisini blockquote (`>`) içinde yaz.

3. **Hedef Dosyayı Belirleme ve Ekleme:**
   - Çalışma alanında öncelikle mevcut sözlük dosyasını ara (`kelimeler.md`, `vocabulary.md` veya kullanıcının belirttiği dosya).
   - Yeni kelimeleri mevcut dosyanın sonuna ekle veya dosya yoksa yeni oluştur.
   - İşlem bittikten sonra eklenen kelimeleri ve güncel toplam kelime sayısını kullanıcıya bildir.

4. **Yardımcı Komutlar:**
   - Toplam kelime sayısını hızlıca kontrol etmek için:
     `grep -c "^## " kelimeler.md`
   - Sözlük doğrulama ve analiz betiği:
     [scripts/validate_dict.py](./scripts/validate_dict.py)
