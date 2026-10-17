---
name: game-decision
description: Continue or drop decision for a game the user is playing. Stop when enjoyment stops. Push past fatigue only for a new mechanic, paradigm, or narrative turn inside 1-2 hours. Grind and idle stat scaling means drop. Triggers include devam mi, birakayim mi, drop early, grind, oyun karari.
user-invocable: false
metadata:
  type: workflow
  version: "1.0"
---

# Game Decision

Continue or drop a game. One decision. Not a runtime card.

Film, dizi, and oyun runtime cards belong to `media-runtime`. This skill does not look up IMDb, HowLongToBeat, or Metacritic and does not invent hours.

If the user pastes a new When / Output / Constraints block for this skill, replace those sections. Do not add fields they did not send.

## When

The user asks whether to keep playing, finish, or drop a game. Also when they say devam mı, bırakayım mı, drop, grind, or ask how a card table or board works.

A bare title, or a question that is only süre / kaç saat / bitirme süresi, belongs to `media-runtime`. Do not add a Karar line on that card.

## Rule

A game is finished the moment it stops providing enjoyment.

Past the fatigue point, continue only if the next 1–2 hours unlock a new mechanic, a structural paradigm shift, or a narrative breakthrough.

If the next stretch only scales numbers or stats, or repeats the same loop with faster tools, idle production, or automation, drop it now.

Enjoyment beats an old drop note. A recorded Drop Early applies when the loop is stale, not while the user is still having fun.

## Local notes

Recorded calls and board rules are not part of this published skill. Use them only when the user supplies them in the conversation. Do not invent hours or mechanics. If they ask for a recorded call and none was supplied, say `kayit yok`.

## Output

Language matches the user. Labels stay as below. No table. No other games in the answer unless they asked for a list.

```
Title
Karar: Drop Early / Must Play / Play until stale / Push Through
Neden: 1-2 cümle
Sınır: yorgunluktan sonra en fazla 1-2 saat; yeni mekanik yoksa bırak
```

Karar follows the Rule section. If the user supplied a recorded call for that title, use it when the loop is stale, not while they say they are still having fun. Do not invent a süre kaydı. If they also ask how long it is, leave that card to `media-runtime`.

A board question uses only the mechanics they wrote, then one Karar line if they also asked whether to continue. No ending, twist, or later-act contents.

## Constraints

- One decision. Do not score the game. Do not mark ✅ / ⚠️ / ❌.
- Do not spoil an ending, twist, death, or a later act.
- Do not invent hours, prices, or mechanics. Missing note — `kayit yok`.
- Recorded hours are the user's notes. They are not a HowLongToBeat card.
- This skill only makes the continue or drop call.
