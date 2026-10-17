---
name: hackathon-fit
description: Selective hackathon and competition radar. Search the listed sources, filter by the profile stack, keep only remote events or events in the profile country that build real software, and write Fit Score cards. Triggers include hackathon, hackaton, Unstop, Kaggle, Devfolio, Imagine Cup, HackerEarth, TensorHack, TAIKAI, Cerebral Valley, worth maybe skip, fit score, or a Sources/Profile/Output block.
user-invocable: false
metadata:
  type: workflow
  version: "1.3"
---

# Hackathon Fit

Selective hackathon radar. Not a dump of every listing. Only events that are genuinely worth the user's time.

Weekly intern and hackathon lists belong to `opportunity-scan`. Apply or skip marks belong to `opportunity-verdict`. Monthly student, cloud, and mentorship term windows belong to `term-windows`. Tutor talk belongs to `project-tutor`.

Routing priority

- Specific listing + decision question → `opportunity-verdict`
- Open opportunity discovery or list → `opportunity-scan`
- Sparse cycle or term date → `term-windows`
- Scholarship amount, trust, or eligibility mark → `opportunity-verdict`
- Hackathon list → `opportunity-scan`; Fit Score → this skill

If the user pastes a new When / Output / Constraints block for this skill, replace those sections. Keep the official-page, no-invention, remote-or-profile-country, Fit Score, and selectivity rules unless they override them. Do not add fields they did not send.

## When

The user asks for hackathons, competitions, challenges, or Fit Score cards. Also when they paste Sources, Profile, Priority, Output, and Constraints blocks. Also when they name Unstop, Kaggle, Cerebral Valley, TAIKAI, Imagine Cup, Devfolio, TensorHack, or HackerEarth as places to look.

## Profile

Read the profile the user supplies. If stack, country, or time available is missing, ask once. Do not invent it.

Default shape when they do supply one:

- Skills, as a list.
- Priority, left is best, right is smallest.
- Prefer building real software. Do not treat a leaderboard notebook, a CTF-only puzzle, or a workshop sandbox as a good fit unless the user asked for that format.
- Country from the profile. Skip non-remote events outside that country.

## Sources

The source list is a search starting point, not the card source.

Search these first:

- https://unstop.com/hackathons
- https://www.kaggle.com/competitions
- https://cerebralvalley.ai/events
- https://taikai.network/
- https://imaginecup.microsoft.com/en-US
- https://devfolio.co/
- https://tensorhack.com/
- https://www.hackerearth.com/challenges/
- https://www.hackerearth.com/

Then open the official event page (organizer site or the event's own Devpost, Unstop, TAIKAI, Devfolio, or Kaggle page). Cite that official page as Source. Do not use an index or aggregator URL as Source.

If the user sends a new source list, use that list instead of this one.

If no official event page can be opened and verified, do not create a card for that event.

## Workflow

1. Use the current date.
2. Identify open or upcoming events from the source list. Follow through to the official event page.
3. Deadline rule:
   - Closed registration does not automatically kill the event.
   - If the submission window is still open, the event is still eligible.
   - Drop the event only when both registration and submission are closed, or when new participants can no longer submit.
4. Extract deadline, prize, remote or in-person, location, eligibility, and theme from the official page. Never invent a number, date, or prize.
5. If the official page cannot verify deadline, eligibility, remote status, or prize, mark that field `Veri bulunamadı` rather than inferring it from a secondary listing.
6. Filter hard:
   - Skip non-remote events outside the profile country.
   - Skip events that do not match the profile in a real way.
   - Do not recommend something only because it is popular or has a large prize.
   - Leaderboard notebooks are usually skip unless they require shipping real software.
   - Student-only or country-locked events that exclude the profile country are skip.
7. Score remaining events with the Fit Score section. Sort by Fit Score, not prize.
8. Be selective. If only 2 are genuinely good, return 2. If none are good, output exactly: `No worthwhile opportunities found.`
9. Fill the Output block. No extra commentary before the first card unless zero results.

## Fit Score

Calculate Fit Score consistently. Sum the five buckets. Do not award points for prize size or popularity.

- Profile or technical match: 0-50
- Real software build potential: 0-20
- Remote or profile-country eligibility: 0-15
- Alignment with stated priority order: 0-10
- Practicality for the user's current skill level and time: 0-5

Real software build potential is separate from profile match. A working shipped tool, service, CLI, agent, or infra project scores high here. A notebook, demo script, workshop sandbox, or leaderboard entry scores low or zero.

Fit Score is an integer 0-100.

### Priority alignment

Award the 0-10 bucket from the highest-priority relevant skill in the profile. Leftmost matching skill scores highest. Do not stack these points. If the profile has no order, score this bucket 0 and say the order is missing.

## Output

```
[Hackathon Name]
Source: Official event page
Why it fits me (2 sentences):
What I could build (2 concrete project ideas):
Deadline:
Prize:
Remote: Yes/No
Eligibility:
Difficulty (estimated): Easy / Medium / Hard
Fit Score: X/100
Your Decision (Worth/Maybe/Skip) (1 word and 1 sentence to why):
```

Source is the label `Official event page` plus a clickable URL citation to the verified official event page. Never expose or invent raw URLs. Never use an index or aggregator URL as Source.

Difficulty is a model estimate, not an official organizer field. Keep the `(estimated)` label.

Separate cards with a blank line. Do not use a table. Decision on returned cards should be Worth or Maybe. Do not return Skip cards.

## Constraints

- Result language matches the user. If they write in another language, write the card text in that language. Field labels stay as in Output.
- Do not recommend something just because it is popular or has a large prize.
- Be selective. If only 2 opportunities are genuinely good, return 2.
- If none are good, say: No worthwhile opportunities found.
- Skip non-remote hackathons outside the profile country.
- Return only the opportunities that pass the filter.
- Sort them by Fit Score, not prize.
- The job is not to list everything. The job is to find only the opportunities that are genuinely worth the time.
- Prefer building real software.
- Found data — type it. Missing field — `Veri bulunamadı`. Do not invent deadline, prize, eligibility, or remote status.
- If the official event page cannot verify deadline, eligibility, remote status, or prize, mark that field `Veri bulunamadı` rather than inferring it from a secondary listing.
- Source must be a clickable URL citation to the verified official event page. Never expose or invent raw URLs.
- This skill only writes opportunity cards. It does not mark apply or skip for other skills.
