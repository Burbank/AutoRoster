# AutoRoster

**AI-powered calendar events from natural language** — A fork of [LLMCal](https://github.com/cafferychen777/LLMCal) for [PopClip](https://popclip.app) on macOS.

Select text like *"Team meeting tomorrow at 2pm"* or *"Flight AMS 12:30 to LAX 15:45"*, click the calendar icon, and the event is added to your calendar. Especially useful for **adding flights from airline emails and reservations** — times are converted to your home timezone automatically.

---

## About this fork

AutoRoster is based on [LLMCal](https://github.com/cafferychen777/LLMCal) by cafferychen777. Changes include multi-timezone support for flights, removal of Zoom integration (calendar-only), and reliability improvements. Credit for the original extension goes to the LLMCal project.

---

## Features

| Feature | Description |
|---------|-------------|
| Multi-timezone flights | Converts departure/arrival times to your home TZ; adds local-time note to event |
| Preferred Calendar | Dedicated setting for your calendar name |
| Calendar mapping | Maps "Personal"/"Work" to your actual calendar names |
| Title/time fallbacks | Uses defaults when parsing misses a field |
| Ambiguity check | Warns before API call if text seems too vague |
| Default model | Claude Sonnet 4.0 |

---

## Installation

### Prerequisites

- **macOS 12+** with [PopClip](https://popclip.app)
- **Anthropic API key** from [console.anthropic.com](https://console.anthropic.com/)
- **jq** — `brew install jq`
- Calendar app access + Full Disk Access for PopClip

### Install

1. Download or clone this repo.
2. Double-click `AutoRoster.popclipext` to install into PopClip.
3. Open PopClip → Extensions → AutoRoster and add your **Anthropic API key**.
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

## Quick test

1. Select: *"Team meeting tomorrow at 2pm"* or flight text from an airline email
2. Click the calendar icon in PopClip
3. Event appears with a success notification showing topic, date, and time

---

## Troubleshooting

**Log file:** `~/Library/Logs/AutoRoster/autoroster.log`

```bash
tail -80 ~/Library/Logs/AutoRoster/autoroster.log
```

**Restart PopClip after changes:**

```bash
killall PopClip; sleep 1; open -a PopClip
```

---

## License

Same as LLMCal. See [LICENSE](LICENSE) if present, or the [original LLMCal repo](https://github.com/cafferychen777/LLMCal).
