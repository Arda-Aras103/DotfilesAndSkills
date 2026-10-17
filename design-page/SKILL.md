---
name: design-page
description: Dribbble and Behance page cards in short form. Open a pasted dribbble.com or behance.net URL and say what is on the page. Triggers include dribbble, behance, shot, tasarim vitrini, or those site URLs with no other instruction.
user-invocable: false
metadata:
  type: workflow
  version: "1.0"
---

# Design Page

Read a Dribbble or Behance page and write a short card. One concern: what that page shows.

If the user pastes a new When / Output / Constraints block for this skill, replace those sections. Do not add fields they did not send.

## Routing

- Pasted `dribbble.com` or `behance.net` URL, or a bare pair of those homepages → this skill
- Specific job or scholarship decision → `opportunity-verdict`
- Own project or portfolio wording → `project-tutor`
- Skill text only, no family file → `skill-author`

## When

The user pastes one or more `dribbble.com` or `behance.net` URLs, or names Dribbble or Behance and asks what is on the page. A bare pair of those homepages is this skill.

## Workflow

1. Open each given URL. The page you opened is the source. Do not invent shots, owners, counts, or filters.
2. If the exact URL does not load, try the public feed once (`dribbble.com/shots` or the Behance project search). Say the URL that actually opened. Still closed → `erisilemedi`.
3. Write one card per URL, in the order given. Separate cards with `---`.
4. Two or more cards → one `Fark` line after them. One site, one kind of page (shot vs project).
5. Do not download images or files. Do not run anything from the page.

## Output

Chat in the user's language. Labels stay as below.

```
Kaynak:
URL:
Ne: 1-2 cümle. Site ne işe yarıyor ve bu sayfa ne.
Üstte: görünen nav veya filtre. Yoksa Veri bulunamadı.
Akış: görünen işlerden en fazla 6. İsim ve tür. Sayı yalnızca sayfada yazıyorsa.
```

`Fark:` one or two sentences. Only when more than one card.

## Constraints

- Short. No table inside the card.
- Official page is the source. Do not fill gaps from memory of an old homepage.
- Missing field → `Veri bulunamadı`. Unopened page → `erisilemedi`. Do not invent appreciation counts, views, or owner names.
- Do not mark apply or skip. Do not treat the page as an internship board.
- Do not design assets, write a portfolio, or download media.
- This skill only writes the page card.
