---
name: google-calendar
description: Generates copy-paste English Google Calendar prompts with the Google Calendar tag for Gemini Web from deadlines, schedules, or workspace markdown files like reports/applications.md and reports/career.md. Triggers include takvime ekle, google calendar, google takvim, calendar prompt, takvim promptu, tarihleri takvime ekle.
user-invocable: true
metadata:
  type: workflow
  version: "1.2"
---

# Google Calendar Prompt Generator

Generates ready-to-paste English `@Google Calendar` prompts for Gemini Web (`gemini.google.com`) from workspace reports or user-provided dates.

## When

- User asks to add deadlines, camps, interviews, exams, or schedules to Google Calendar (`takvime ekle`, `google calendar`, `google takvim`, `calendar prompt`, `takvim promptu`, `tarihleri takvime ekle`).
- User asks to export upcoming dates from `/workspace/reports/applications.md`, `/workspace/reports/career.md`, or chat messages into a calendar prompt.

## Workflow

1. **Collect Events:** Read the dates and details from the user message or referenced file (e.g., `/workspace/reports/applications.md`, `/workspace/reports/career.md`). Skip past dates unless the user asks for them.
2. **Normalize Date & Time (`Europe/Istanbul`, UTC+3):**
   - Convert foreign timezones (`CET`, `UTC`, etc.) to `Europe/Istanbul` (`UTC+3`) or note the exact cutoff in `Description`.
   - If a deadline date has no specific hour, assign `10:00 - 11:00` on that date.
   - If a date is missing or uncertain, write `belirsiz` (or skip if filtering). If a link is missing, write `url bulunamadi`.
3. **Render Prompt Block:** Output a single copy-pasteable `text` code block in English starting with `@Google Calendar` and setting reminders for `3 days before` and `1 day before`.

## Output

For multiple events:

```text
@Google Calendar Add the following events and application deadlines to my Google Calendar one by one in the "Europe/Istanbul" (UTC+3) timezone. Set reminders for 3 days before and 1 day before for each event:

1. Title: [Event or Program Name - Stage]
   Date: [YYYY-MM-DD, HH:MM - HH:MM]
   Description: [Short note in English]. Link: [Official URL or url bulunamadi]
```

For a single event:

```text
@Google Calendar Add the event "[Title]" on [YYYY-MM-DD, HH:MM - HH:MM] (Europe/Istanbul) to my Google Calendar with reminders 3 days before and 1 day before. Description: [Short note in English]. Link: [Official URL or url bulunamadi]
```

## Constraints

- Output only the English `@Google Calendar` copy-paste prompt block (Option A); do not generate `calendar.google.com/calendar/render` URL tables or configure a Google Calendar MCP server unless explicitly asked.
- Never invent dates, hours, or URLs, and never store personal PII in the skill template.
