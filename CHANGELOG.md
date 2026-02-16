# Changelog

All notable changes to AutoCal (fork of [LLMCal](https://github.com/cafferychen777/LLMCal)) are documented in this file.

---

## Overview

AutoCal is a reliability-improved fork of LLMCal, the AI-powered PopClip extension for creating calendar events from natural language. This changelog tracks all modifications from the original.

---

## [Unreleased] — 2026-02

### Added

- **Preferred Calendar setting** — Dedicated field to specify the exact calendar name (e.g. Day2Day, Personal, Work). Takes priority over AI selection. Fixes cases where Personal Preferences calendar name wasn't picked up.
- **Local time reference in event notes** — For flights and multi-timezone events, a note is appended to the description: "🕐 Local times: 12:30 Amsterdam (departure) → 07:30 Hong Kong (arrival)". Only when both start_timezone and end_timezone are present.
- **Ambiguity pre-filter** — Before calling the API, checks if text is too vague (e.g. "Call John ASAP", "Meeting TBD"). Shows an alert: "This text may be lacking specific details for successful calendar entry." Offers "Cancel" or "Try Anyway". Avoids wasted API calls and gives instant feedback.
- **Success notification shows event details** — Notification displays topic, date, and time (e.g. "Team Standup — Mon Feb 16 at 2:30 PM") so you can quickly verify the entry was created correctly.
- **Robust title/start/end fallbacks** — When parsing loses the title, uses description or "Calendar Event". When start_time or end_time is missing, falls back to today 9:00–10:00 AM or start+1 hour. Prevents "Event title is missing" and "Start time is missing" errors.
- **AI-based timezone lookup for flights** — The AI returns `start_timezone` and `end_timezone` (IANA format) directly in the JSON response. No local airport database; works for any airport worldwide.
- **Timezone conversion** — `convert_datetime_between_timezones()` converts flight times from departure/arrival airport timezones to the user's home or system timezone.
- **User preference parsing** — Detects preferred calendar (e.g. "Day2Day") and home timezone (e.g. "Amsterdam") from the Personal Preferences field in PopClip settings.
- **Calendar name resolution** — `resolve_calendar_name()` maps abstract names ("Personal", "Work") to the user's actual calendar names. Falls back to alternatives (Family, Day2Day, work, etc.) or the first available calendar when exact match fails.
- **AutoCal branding** — New name, identifier (`com.popclip.extension.autocal`), custom logo, and log directory (`~/Library/Logs/AutoCal/`).

### Changed

- **Default model: Claude Sonnet 4.0** — Extension defaults to Sonnet 4.0 (balanced quality/cost). Haiku and Opus remain available in settings.
- **API key validation relaxed** — Accepts any key starting with `sk-ant-` (was: strict `sk-ant-api03-` prefix and length). Trims leading/trailing whitespace. Minimum length check (20 chars) instead of exact format.
- **Removed blocking API test** — Dropped the pre-flight API call during validation; invalid keys still surface as HTTP 401 on the actual request. Prevents network/timeout issues from blocking valid keys.
- **Response parsing improved** — `extract_text_from_content_blocks()` iterates all content blocks (not just first). Handles API error responses. Title fallback: empty title uses description or "Calendar Event". Missing `end_time` defaults to start + 1 hour.
- **Error notification fixed** — `show_error_notification_with_message` now passes the actual error message instead of the app name.
- **Prompt updates** — Flight/timezone rules added: AI must output `start_timezone` and `end_timezone` (IANA) for flights. Times are interpreted in the correct airport timezone.

### Fixed

- **Invalid date format when time has seconds** — The sed that appended `:00` to `HH:MM` incorrectly matched `30:00` in `12:30:00`, producing `12:30:00:00`. Now only appends seconds when the format is exactly `YYYY-MM-DD HH:MM` (no seconds).
- **"Unable to create a title" / "No title available"** — Empty titles from the AI no longer cause failure; fallback title is used.
- **"Can't get calendar Personal" (error -1728)** — Users without "Personal" or "Work" calendars no longer fail; resolver maps to existing calendars.
- **API never called / no credit usage** — Strict key format and blocking test were preventing valid keys from reaching the API.
- **Flight times in wrong timezone** — Departure and arrival times are now converted using the correct airport timezones before calendar creation.
- **Network check in error recovery** — Replaced `ping google.com` with `curl` to `api.anthropic.com` so only the required API is contacted (no third-party pings).

### Removed

- **Local airport database** — Replaced by AI-provided timezone fields. No `get_timezone_for_airport()` or hardcoded IATA→timezone mapping.
- **Zoom integration** — Removed Zoom Account ID, Client ID, Client Secret, Email, and Display Name settings. Deleted `zoom_integration.sh` and related code. Extension now focuses on calendar events only.
- **Unused modules** — Removed `config_validator.sh`, `env_loader.sh`, `logger.sh`, and `security.sh` (never used by main flow; contained hardcoded Chinese).
- **Chinese characters in lib** — Replaced/removed from error messages and validators. `i18n.json` zh/ja locales retained for localization.

---

## File changes summary

| File | Changes |
|------|---------|
| `Config.json` | Preferred Calendar option; Zoom options removed; default model Sonnet 4.0 |
| `lib/error_handler.sh` | Relaxed API key validation; AutoCal branding; Zoom codes removed; network check uses api.anthropic.com |
| `lib/api_client.sh` | Removed API test; flight/timezone prompt rules; `start_timezone`/`end_timezone` in JSON schema |
| `lib/json_parser.sh` | Content block extraction; title/end_time fallbacks; `start_timezone`/`end_timezone` passthrough |
| `lib/date_utils.sh` | `convert_datetime_between_timezones()`; removed airport lookup |
| `lib/calendar_creator.sh` | `resolve_calendar_name()`; calendar resolution before AppleScript |
| `calendar.sh` | API key trim; user preference parsing; timezone conversion; Preferred Calendar; title/start/end fallbacks; ambiguity pre-filter; success notification with event details; Zoom removed |
| `lib/*` | Removed: zoom_integration.sh, config_validator.sh, env_loader.sh, logger.sh, security.sh |

---

## Installation & deployment

- **Source:** `/Users/DuniaMBP/AutoCal/AutoCal.popclipext/`
- **Installable:** `AutoCal.popclipext.zip` or double-click `AutoCal.popclipext`
- **Installed location:** `~/Library/Application Support/PopClip/Extensions/AutoCal.popclipext/`

Updates are deployed by copying modified files to the installed extension directory. No reinstall required.

---

## Troubleshooting reference

- **Log file:** `~/Library/Logs/AutoCal/autocal.log`
- **API key:** Must start with `sk-ant-`; trim spaces when pasting
- **Calendar:** If "Personal"/"Work" fail, the resolver uses Family, Day2Day, work, etc., or the first calendar
- **Timezones:** AI provides IANA timezones for flights; conversion targets user's home TZ from preferences or system TZ
