# AutoCal

**AI-powered calendar events from natural language** — A reliability-improved fork of [LLMCal](https://github.com/cafferychen777/LLMCal) for [PopClip](https://popclip.app) on macOS.

**Purpose:** This extension is built for **multi-timezone support**, especially **adding flights to your calendar** from airline emails and reservations. Select flight details (e.g. *"Flight KL601 AMS 12:30 to LAX 15:45 Feb 20"*), and AutoCal creates the event with times correctly converted to your home timezone. Zoom integration has been **removed** — this fork focuses solely on calendar events.

Select text like *"Team meeting tomorrow at 2pm"* or *"Flight AMS 12:30 to LAX 15:45"*, click the calendar icon, and the event is added to your calendar.

---

## Fork notice

AutoCal is a **fork** of [LLMCal](https://github.com/cafferychen777/LLMCal) by cafferychen777. This fork focuses on **multi-timezone support** and **improved reliability** — fixing common failure modes, better parsing, clearer errors, and a cleaner codebase. Zoom integration has been removed. All credit for the original idea and structure goes to the LLMCal project.

---

## What AutoCal improves (vs. original LLMCal)

| Issue | Fix |
|-------|-----|
| API key rejected despite being valid | Accepts any `sk-ant-` key; trims spaces; no blocking pre-flight test |
| "Unable to create a title" / "Event title is missing" | Fallbacks: description → "Calendar Event" |
| "Start time is missing" | Fallbacks: today 9:00 AM or start+1 hour |
| "Can't get calendar Personal/Work" | Maps to your actual calendars; dedicated **Preferred Calendar** setting |
| Flight times in wrong timezone | **Multi-timezone support:** AI returns IANA timezones; converts departure/arrival times to your home TZ |
| Vague text wastes API calls | Ambiguity pre-filter warns before calling API |
| Zoom bloat | **Zoom removed** — extension focused solely on calendar events (no Zoom credentials needed) |
| Chinese in lib error messages | Removed; English only in code |
| Default model | **Claude Sonnet 4.0** (balanced quality/cost) |

---

## Installation

### Prerequisites

- **macOS 12+** with [PopClip](https://popclip.app)
- **Anthropic API key** from [console.anthropic.com](https://console.anthropic.com/)
- **jq** — `brew install jq`
- Calendar app access + Full Disk Access for PopClip

### Install

1. Download or clone this repo.
2. Double-click `AutoCal.popclipext` to install into PopClip.
3. Open PopClip → Extensions → AutoCal and add your **Anthropic API key**.
4. (Optional) Set **Preferred Calendar** to your calendar name (e.g. Day2Day, Personal).

---

## Settings

| Setting | Description |
|---------|-------------|
| **Anthropic API Key** | Required. Get from [console.anthropic.com](https://console.anthropic.com/). |
| **Claude Model** | Sonnet 4.0 (default), Haiku 3.5, or Opus 4.1. |
| **Preferred Calendar** | Calendar name to add events to (must match Calendar app). |
| **Personal Preferences** | Free-form hints, e.g. "Home timezone Amsterdam", "Default duration 1 hour". |

---

## Use cases

**Flights from airline emails** — Copy flight details from confirmation emails (e.g. *"Flight KL601 departs Amsterdam 12:30, arrives Los Angeles 15:45 on 20 Feb"*), select the text, and add to calendar. Times are converted to your home timezone, with a local-time reference note in the event description.

**Meetings and events** — *"Team meeting tomorrow at 2pm"*, *"Doctor appointment Thursday 10am"* — works as expected.

## Quick test

1. Select: *"Team meeting tomorrow at 2pm"* or flight text from an airline email
2. Click the calendar icon in PopClip
3. Event appears with a success notification showing topic, date, and time

---

## Troubleshooting

**Log file:** `~/Library/Logs/AutoCal/autocal.log`

```bash
tail -80 ~/Library/Logs/AutoCal/autocal.log
```

**Restart PopClip after changes:**

```bash
killall PopClip; sleep 1; open -a PopClip
```

---

## License

Same as LLMCal. See [LICENSE](LICENSE) if present, or the [original LLMCal repo](https://github.com/cafferychen777/LLMCal).
