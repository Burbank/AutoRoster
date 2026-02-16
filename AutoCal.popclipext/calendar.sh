#!/bin/bash

# AutoCal - AI-Powered Calendar Event Creator
# Fork of LLMCal with improved API key handling and parsing reliability
# Based on LLMCal v2.0

set -euo pipefail  # Enable strict error handling

# Configuration
SCRIPT_DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly LIB_DIR="$SCRIPT_DIR/lib"
readonly LOG_DIR="$HOME/Library/Logs/AutoCal"
readonly LOG_FILE="$LOG_DIR/autocal.log"

# Create log directory
mkdir -p "$LOG_DIR"

# Initialize logging
log() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level]: $message" >> "$LOG_FILE"
}

# Source all library modules
source_modules() {
    local modules=(
        "error_handler.sh"
        "date_utils.sh"
        "json_parser.sh"
        "api_client.sh"
        "calendar_creator.sh"
        "priority_calendar.sh"
    )
    
    for module in "${modules[@]}"; do
        local module_path="$LIB_DIR/$module"
        if [ -f "$module_path" ]; then
            source "$module_path"
            log "INFO" "Loaded module: $module"
        else
            echo "ERROR: Required module not found: $module_path" >&2
            exit 1
        fi
    done
}

# Initialize the application
initialize() {
    log "INFO" "Starting AutoCal (LLMCal fork)"
    log "INFO" "Processing text: $POPCLIP_TEXT"
    
    # Set up error logging for all modules
    set_error_logger "log"
    
    # Validate dependencies
    if ! validate_dependencies; then
        show_error_notification "AutoCal Setup"
        graceful_exit
    fi
    
    # Initialize JSON processor
    init_json_processor
    
    # Test calendar availability early
    if ! test_calendar_availability; then
        show_error_notification "AutoCal Calendar Access"
        show_recovery_suggestion
        graceful_exit
    fi
    
    log "INFO" "Initialization completed successfully"
}

# Enhanced language detection with fallback support
get_language() {
    local lang=""
    
    # Check for explicit override first
    if [[ -n "${LANGUAGE:-}" ]]; then
        lang="$LANGUAGE"
        log "INFO" "Using override language: $lang"
    # Check environment variable
    elif [[ -n "${LC_ALL:-}" ]]; then
        lang="${LC_ALL%.*}"  # Remove .UTF-8 suffix
        lang="${lang%_*}"    # Remove country code
    elif [[ -n "${LANG:-}" ]]; then
        lang="${LANG%.*}"    # Remove .UTF-8 suffix
        lang="${lang%_*}"    # Remove country code
    # Fall back to system preferences
    else
        local sys_lang
        # Try multiple methods to get system language
        sys_lang=$(defaults read .GlobalPreferences AppleLanguages 2>/dev/null | \
                  head -n 3 | tail -n 1 | tr -d '", ' 2>/dev/null) || \
        sys_lang=$(osascript -e 'return (get system info)' 2>/dev/null | \
                  grep -o 'system language:[^,]*' | cut -d: -f2 | tr -d ' ') || \
        sys_lang="en"
        
        # Extract language code
        lang="${sys_lang%%-*}"  # Remove region code
        lang="${lang%%_*}"      # Remove underscore variant
    fi
    
    # Normalize and validate language code
    lang=$(echo "$lang" | tr '[:upper:]' '[:lower:]')
    
    case "$lang" in
        zh|zho|chi) echo "zh" ;;  # Chinese (simplified/traditional)
        es|spa) echo "es" ;;      # Spanish
        fr|fra|fre) echo "fr" ;;  # French
        de|deu|ger) echo "de" ;;  # German
        ja|jpn) echo "ja" ;;      # Japanese
        en|eng|*) echo "en" ;;   # English (default fallback)
    esac
}

# Get translated text
get_translation() {
    local lang
    lang=$(get_language)
    local key="$1"
    local bundle_path="${POPCLIP_BUNDLE_PATH:-$SCRIPT_DIR}"
    local translations_file="$bundle_path/i18n.json"
    
    if [ -f "$translations_file" ]; then
        python3 - "$translations_file" "$lang" "$key" <<'EOF'
import sys, json
try:
    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        data = json.load(f)
    lang = sys.argv[2]
    key = sys.argv[3]
    text = data.get(lang, {}).get(key, data.get('en', {}).get(key, 'Message not found'))
    print(text)
except Exception as e:
    print(f"Translation error: {str(e)}", file=sys.stderr)
    # Fallback translations
    fallbacks = {
        'processing': 'Processing...',
        'success': 'Event added to calendar',
        'error': 'Failed to add event'
    }
    print(fallbacks.get(sys.argv[3], 'Unknown message'))
EOF
    else
        log "WARN" "Translation file not found: $translations_file"
        # Fallback translations when i18n.json is not available
        case "$key" in
            "processing") echo "Processing..." ;;
            "success") echo "Event added to calendar" ;;
            "error") echo "Failed to add event" ;;
            "api_error") echo "API request failed" ;;
            "invalid_key") echo "Invalid API key" ;;
            "no_text") echo "No text selected" ;;
            "network_error") echo "Network connection failed" ;;
            "permission_error") echo "Calendar permission required" ;;
            "timeout_error") echo "Request timed out" ;;
            "parsing_error") echo "Failed to parse event details" ;;
            "calendar_error") echo "Calendar operation failed" ;;
            "config_error") echo "Configuration error" ;;
            *) echo "Unknown message" ;;
        esac
    fi
}

# Show processing notification
show_processing_notification() {
    local processing_msg
    processing_msg=$(get_translation "processing")
    osascript -e "display notification \"$processing_msg\" with title \"AutoCal\"" 2>/dev/null || true
}

# Process calendar event with AI
process_event_with_ai() {
    local text="$1"
    local api_key="$2"
    
    log "INFO" "Processing event with AI: $text"
    
    # Validate API key
    if ! validate_anthropic_api_key "$api_key"; then
        local error_code
error_code=$(get_error_code)
return "$error_code"
    fi
    
    # Get date references with proper timezone handling
    local date_refs
    date_refs=$(get_date_references)
    if [ $? -ne "$ERR_SUCCESS" ]; then
        local error_code
error_code=$(get_error_code)
return "$error_code"
    fi
    
    local today tomorrow
    today=$(extract_json_field "$date_refs" "today")
    tomorrow=$(extract_json_field "$date_refs" "tomorrow")
    
    log "INFO" "Date references: today=$today, tomorrow=$tomorrow"
    
    # Process calendar event
    local response
    response=$(process_calendar_event "$text" "$api_key" "$today" "$tomorrow")
    if [ $? -ne "$ERR_SUCCESS" ]; then
        local error_code
error_code=$(get_error_code)
return "$error_code"
    fi
    
    log "INFO" "AI processing completed successfully"
    echo "$response"
    return "$ERR_SUCCESS"
}

# Extract and validate event data
extract_event_data() {
    local api_response="$1"
    
    log "INFO" "Extracting event data from AI response"
    
    # Process the Anthropic response
    local event_json
    event_json=$(process_anthropic_response "$api_response")
    if [ $? -ne "$ERR_SUCCESS" ]; then
        local error_code
error_code=$(get_error_code)
return "$error_code"
    fi
    
    # Validate event structure
    local validated_event
    validated_event=$(validate_event_json "$event_json")
    if [ $? -ne "$ERR_SUCCESS" ]; then
        local error_code
error_code=$(get_error_code)
return "$error_code"
    fi
    
    log "INFO" "Event data extracted and validated successfully"
    echo "$validated_event"
    return "$ERR_SUCCESS"
}

# Create the calendar event
create_event() {
    local event_data="$1"
    local user_prefs="${POPCLIP_OPTION_USER_PREFERENCES:-}"
    
    log "INFO" "Creating calendar event"
    
    # Extract all event fields
    local title start_time end_time description location url alerts recurrence attendees allday status excluded_dates calendar_type priority start_timezone end_timezone
    title=$(extract_json_field "$event_data" "title")
    start_time=$(extract_json_field "$event_data" "start_time")
    end_time=$(extract_json_field "$event_data" "end_time")
    start_timezone=$(extract_json_field "$event_data" "start_timezone" "")
    end_timezone=$(extract_json_field "$event_data" "end_timezone" "")
    description=$(extract_json_field "$event_data" "description")
    
    # Robust title fallback (parsing can occasionally lose the title)
    title=$(echo "$title" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -z "$title" ] || [ "$title" = "None" ] || [ "$title" = "null" ]; then
        if [ -n "$description" ] && [ ${#description} -lt 100 ]; then
            title="$description"
        else
            title="Calendar Event"
        fi
        log "WARN" "Title was empty, using fallback: $title"
    fi
    
    # Robust start/end time fallback (parsing can occasionally lose times)
    start_time=$(echo "$start_time" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    end_time=$(echo "$end_time" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -z "$start_time" ] || [ "$start_time" = "None" ] || [ "$start_time" = "null" ]; then
        local today_default
        today_default=$(date "+%Y-%m-%d")
        start_time="${today_default} 09:00:00"
        if [ -z "$end_time" ] || [ "$end_time" = "None" ] || [ "$end_time" = "null" ]; then
            end_time="${today_default} 10:00:00"
        fi
        log "WARN" "Start time was empty, using fallback: $start_time (please edit the event)"
    elif [ -z "$end_time" ] || [ "$end_time" = "None" ] || [ "$end_time" = "null" ]; then
        # Start exists but end missing - default to 1 hour later
        local end_default
        end_default=$(date -j -v+1H -f "%Y-%m-%d %H:%M:%S" "$start_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || \
            date -j -v+1H -f "%Y-%m-%d %H:%M" "$start_time" "+%Y-%m-%d %H:%M:00" 2>/dev/null)
        if [ -n "$end_default" ]; then
            end_time="$end_default"
        else
            end_time="$start_time"
        fi
        log "WARN" "End time was empty, using fallback: $end_time"
    fi
    location=$(extract_json_field "$event_data" "location")
    url=$(extract_json_field "$event_data" "url")
    recurrence=$(extract_json_field "$event_data" "recurrence" "none")
    allday=$(extract_json_field "$event_data" "allday" "false")
    status=$(extract_json_field "$event_data" "status" "confirmed")
    priority=$(extract_json_field "$event_data" "priority" "medium")
    calendar_type=$(extract_json_field "$event_data" "calendar_type" "")
    
    # Get arrays
    alerts=$(extract_json_array "$event_data" "alerts")
    attendees=$(extract_json_array "$event_data" "attendees")
    excluded_dates=$(extract_json_array "$event_data" "excluded_dates")
    
    # Save original local times for multi-timezone note (before conversion)
    local original_start original_end
    original_start="$start_time"
    original_end="$end_time"
    
    # Convert times using AI-provided timezones for flights (AI looks up airport → IANA zone)
    # Target TZ: user's home from preferences or system timezone
    local target_tz
    target_tz=$(get_system_timezone)
    if echo "$user_prefs" | grep -qiE 'Amsterdam|home time zone.*Amsterdam'; then
        target_tz="Europe/Amsterdam"
    elif echo "$user_prefs" | grep -qiE 'London|home time zone.*London'; then
        target_tz="Europe/London"
    elif echo "$user_prefs" | grep -qiE 'New York|home time zone.*New York'; then
        target_tz="America/New_York"
    fi
    
    if [ -n "$start_timezone" ]; then
        start_time=$(convert_datetime_between_timezones "$start_time" "$start_timezone" "$target_tz")
        log "INFO" "Converted start from $start_timezone to $target_tz: $start_time"
    fi
    if [ -n "$end_timezone" ]; then
        end_time=$(convert_datetime_between_timezones "$end_time" "$end_timezone" "$target_tz")
        log "INFO" "Converted end from $end_timezone to $target_tz: $end_time"
    fi
    
    # Add local time reference to description for flights/multi-timezone events
    if [ -n "$start_timezone" ] && [ -n "$end_timezone" ]; then
        local place_name
        place_name() { echo "$1" | sed 's/.*\///;s/_/ /g'; }
        local start_place end_place start_local end_local
        start_place=$(place_name "$start_timezone")
        end_place=$(place_name "$end_timezone")
        start_local=$(echo "$original_start" | sed 's/^[0-9]*-[0-9]*-[0-9]* \([0-9][0-9]:[0-9][0-9]\).*/\1/')
        end_local=$(echo "$original_end" | sed 's/^[0-9]*-[0-9]*-[0-9]* \([0-9][0-9]:[0-9][0-9]\).*/\1/')
        local tz_note
        tz_note="🕐 Local times: ${start_local} ${start_place} (departure) → ${end_local} ${end_place} (arrival)"
        if [ -n "$description" ]; then
            description="${description}

${tz_note}"
        else
            description="$tz_note"
        fi
        log "INFO" "Added local time note to description"
    fi
    
    log "INFO" "Event details: title='$title', start='$start_time', end='$end_time', allday='$allday'"
    log "DEBUG" "Additional details: location='$location', url='$url', recurrence='$recurrence', status='$status', priority='$priority', calendar_type='$calendar_type', timezones='$start_timezone->$end_timezone'"
    
    # Primary: use dedicated Preferred Calendar setting (trim whitespace)
    local preferred_calendar
    preferred_calendar=$(echo "${POPCLIP_OPTION_PREFERRED_CALENDAR:-}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Fallback: check Personal Preferences for calendar names (legacy)
    if [ -z "$preferred_calendar" ] && [ -n "$user_prefs" ]; then
        for cal in Day2Day "Arie main gcal" "Work crewapp" Family work Household; do
            if echo "$user_prefs" | grep -qiF "$cal"; then
                preferred_calendar="$cal"
                break
            fi
        done
    fi
    
    # Select appropriate calendar
    local selected_calendar
    if [ -n "$preferred_calendar" ]; then
        selected_calendar="$preferred_calendar"
        log "INFO" "Using preferred calendar: $selected_calendar"
    else
    case "$calendar_type" in
        "high_priority")
            selected_calendar="High Priority"
            ;;
        "medium_priority")
            selected_calendar="Medium Priority"
            ;;
        "low_priority")
            selected_calendar="Low Priority"
            ;;
        "work")
            selected_calendar="Work"
            ;;
        "personal")
            selected_calendar="Personal"
            ;;
        "deadlines")
            selected_calendar="Deadlines"
            ;;
        "meetings")
            selected_calendar="Meetings"
            ;;
        *)
            # Fallback to keyword-based selection if LLM doesn't specify
            selected_calendar=$(select_calendar_for_event "$POPCLIP_TEXT" "$title" "$location" "$attendees")
            ;;
    esac
    fi
    log "INFO" "Selected calendar: $selected_calendar"
    
    # Create the calendar event
    if create_calendar_event "$title" "$start_time" "$end_time" "$description" "$location" "$url" "$alerts" "$recurrence" "$attendees" "$selected_calendar" "$allday" "$status" "$excluded_dates"; then
        log "INFO" "Calendar event created successfully"
        CREATED_EVENT_TITLE="$title"
        CREATED_EVENT_START_DISPLAY=$(format_datetime_for_notification "$start_time" "$allday")
        return "$ERR_SUCCESS"
    else
        log "ERROR" "Failed to create calendar event"
        local error_code
error_code=$(get_error_code)
return "$error_code"
    fi
}

# Format datetime for display in notification (e.g. "Mon Feb 16 at 2:30 PM")
format_datetime_for_notification() {
    local dt="$1"
    local allday="${2:-false}"
    dt=$(echo "$dt" | tr -d '"')
    if [ -z "$dt" ]; then
        echo ""
        return
    fi
    # Ensure HH:MM has seconds for parsing
    [[ "$dt" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}$ ]] && dt="${dt}:00"
    # All-day: YYYY-MM-DD → "Mon Feb 16"
    if [ "$allday" = "true" ]; then
        date -j -f "%Y-%m-%d" "${dt%% *}" "+%a %b %d" 2>/dev/null || \
        date -j -f "%Y-%m-%d %H:%M:%S" "$dt" "+%a %b %d" 2>/dev/null || echo "$dt"
        return
    fi
    # Timed: "Mon Feb 16 at 2:30 PM"
    date -j -f "%Y-%m-%d %H:%M:%S" "$dt" "+%a %b %d at %I:%M %p" 2>/dev/null || \
    date -j -f "%Y-%m-%d %H:%M" "$dt" "+%a %b %d at %I:%M %p" 2>/dev/null || \
    date -j -f "%Y-%m-%d" "$dt" "+%a %b %d" 2>/dev/null || echo "$dt"
}

# Show success notification with event details
show_success_notification() {
    local msg title_display time_display
    title_display="${CREATED_EVENT_TITLE:-}"
    time_display="${CREATED_EVENT_START_DISPLAY:-}"
    if [ -n "$title_display" ] && [ -n "$time_display" ]; then
        msg="${title_display} — ${time_display}"
    else
        msg=$(get_translation "success")
    fi
    # Escape double quotes for AppleScript
    msg=$(echo "$msg" | sed 's/"/\\"/g')
    osascript -e "display notification \"$msg\" with title \"AutoCal\"" 2>/dev/null || true
}

# Show error notification
show_error_notification_with_message() {
    show_error_notification "${LAST_ERROR_MESSAGE:-$(get_translation "error")}" "AutoCal"
}

# Cleanup resources
cleanup() {
    log "INFO" "Cleaning up resources"
    
    # Cleanup JSON processor
    cleanup_json_processor
    
    # Clear API cache
    clear_api_cache
    
    log "INFO" "Cleanup completed"
}

# Pre-filter: detect text too ambiguous for calendar entry (avoids API call + gives instant feedback)
check_ambiguity() {
    local text="$1"
    text=$(echo "$text" | tr '[:upper:]' '[:lower:]')
    
    # Too short to contain usable date/time info
    if [ ${#text} -lt 12 ]; then
        return 1  # ambiguous
    fi
    
    # Short text with only vague time phrases (no concrete date/time)
    if [ ${#text} -lt 40 ]; then
        if echo "$text" | grep -qiE '(^|[^a-z])(asap|tbd|to be determined|sometime)([^a-z]|$)'; then
            if ! echo "$text" | grep -qE '[0-9]|(tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday|next week|january|february|march|april|june|july|august|september|october|november|december)'; then
                return 1
            fi
        fi
    fi
    
    # No digits (dates/times almost always have numbers) AND no day/month/time keywords
    if ! echo "$text" | grep -q '[0-9]'; then
        if ! echo "$text" | grep -qE '(monday|tuesday|wednesday|thursday|friday|saturday|sunday|tomorrow|today|next week|january|february|march|april|may|june|july|august|september|october|november|december|am|pm|morning|afternoon|evening|noon|midnight|hour|clock|[0-9]{1,2}:[0-9]{2})'; then
            return 1
        fi
    fi
    
    return 0  # seems parseable
}

# Main execution flow
main() {
    # Initialize
    initialize
    
    # Show processing notification
    show_processing_notification
    
    # Validate required environment variables
    if [ -z "${POPCLIP_TEXT:-}" ]; then
        handle_error "$ERR_GENERAL" "No text provided" true true
        graceful_exit
    fi
    
    if [ -z "${POPCLIP_OPTION_ANTHROPIC_API_KEY:-}" ]; then
        handle_error "$ERR_API_KEY_MISSING" "Anthropic API key not configured" true true
        graceful_exit
    fi
    
    # Pre-filter: warn if text seems too ambiguous
    if ! check_ambiguity "${POPCLIP_TEXT}"; then
        log "INFO" "Text flagged as ambiguous, showing alert"
        osascript -e 'display dialog "This text may be lacking specific details for successful calendar entry.\n\nAdd at least a date or time, e.g.:\n• \"Meeting tomorrow at 2pm\"\n• \"Call John next Tuesday 10am\"\n• \"Standup Monday 9am\"\n\nProceed anyway?" buttons {"Cancel", "Try Anyway"} default button 2 with title "AutoCal - Ambiguous Text"' 2>/dev/null
        local alert_result=$?
        if [ $alert_result -eq 1 ]; then
            log "INFO" "User cancelled due to ambiguity"
            exit 0
        fi
        # User chose "Try Anyway", continue
    fi
    
    # Trim API key (common copy-paste issue with extra spaces)
    local api_key_trimmed
    api_key_trimmed=$(echo "$POPCLIP_OPTION_ANTHROPIC_API_KEY" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Process the event with AI
    local api_response
    api_response=$(process_event_with_ai "$POPCLIP_TEXT" "$api_key_trimmed")
    local ai_result=$?
    
    if [ $ai_result -ne "$ERR_SUCCESS" ]; then
        show_error_notification_with_message
        show_recovery_suggestion
        graceful_exit
    fi
    
    # Debug: Log the raw API response
    log "DEBUG" "Raw API response: $api_response"
    
    # Extract and validate event data
    local event_data
    event_data=$(extract_event_data "$api_response")
    local extract_result=$?
    
    if [ $extract_result -ne "$ERR_SUCCESS" ]; then
        log "ERROR" "Event extraction failed. Raw API response: $api_response"
        
        # Save the problematic response for debugging
        local debug_file="$LOG_DIR/failed_parse_$(date +%Y%m%d_%H%M%S).json"
        echo "$api_response" > "$debug_file"
        log "ERROR" "Saved failed response to: $debug_file"
        
        # Try to extract any error message from the API response
        local api_error_msg=""
        if echo "$api_response" | grep -q "error"; then
            api_error_msg=$(echo "$api_response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
        fi
        
        if [ -n "$api_error_msg" ]; then
            set_last_error "$ERR_JSON_PARSE_FAILED" "AI parsing error: $api_error_msg"
        else
            set_last_error "$ERR_JSON_PARSE_FAILED" "Failed to parse event from text: '$POPCLIP_TEXT'"
        fi
        
        show_error_notification_with_message
        show_recovery_suggestion
        graceful_exit
    fi
    
    # Create the calendar event
    if create_event "$event_data"; then
        show_success_notification
        log "INFO" "Event processing completed successfully"
    else
        show_error_notification_with_message
        show_recovery_suggestion
        graceful_exit
    fi
    
    # Cleanup and exit
    cleanup
    log "INFO" "AutoCal processing finished"
}

# Trap signals for graceful cleanup
trap 'cleanup; graceful_exit' EXIT INT TERM

# Source modules and run main function
source_modules
main "$@"