#!/usr/bin/env bash
# iMenu Prompt: date
# Interactive date prompt (simplified version)

imenu_date() {
    local name="$1"
    local message="$2"
    local initial="${3:-}"
    local mask="${4:-YYYY-MM-DD HH:mm:ss}"
    local validate_func="${5:-}"
    local format_func="${6:-}"
    
    local title="${IMENU_TITLE:-}"
    local has_back="${IMENU_HAS_BACK:-false}"
    local clear_previous_lines="${IMENU_CLEAR_PREVIOUS:-0}"
    
    # Clear previous menu if requested
    if [ "$clear_previous_lines" -gt 0 ]; then
        _imenu_clear_menu $clear_previous_lines
    fi
    
    # Print header with title only
    _imenu_print_header "$title"
    
    # Display message if provided
    if [ -n "$message" ]; then
        local message_prefix="${IMENU_MESSAGE_PREFIX:-}"
        if [ -n "$message_prefix" ]; then
            printf '%b%s %s%b\n' "${BLUE}" "$message_prefix" "$message" "${NC}" >&2
        else
            printf '%b%s%b\n' "${BLUE}" "$message" "${NC}" >&2
        fi
    fi
    
    # Parse initial date or use current date
    local date_str="$initial"
    if [ -z "$date_str" ]; then
        # Generate current date using standard format (not mask format)
        date_str=$(date "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date "+%Y-%m-%d %H:%M:%S")
    fi
    
    # For simplicity, we'll use a text input that accepts date strings
    # In a full implementation, this would parse the mask and allow field-by-field editing
    local input="$date_str"
    
    # Hide cursor during input - we'll show it at the correct position
    _imenu_hide_cursor
    
    # Calculate message lines for total count
    local message_lines=1
    if [ -n "$message" ]; then
        message_lines=$(echo -n "$message" | grep -c '^' || echo "1")
        if [ "$message_lines" -eq 0 ]; then
            message_lines=1
        fi
    fi
    
    local menu_lines=3  # Prompt + hint (conditional) + keybindings
    # Adjust if format hint won't be shown
    if [[ "$message" =~ "$mask" ]]; then
        menu_lines=2  # Prompt + keybindings (no format hint)
    fi
    
    # Total lines = message + menu
    local total_lines=$((message_lines + menu_lines))
    
    while true; do
        # Display prompt with input (no newline, we'll position cursor)
        printf '%b?%b %s' "${CYAN}" "${NC}" "$input" >&2
        local display_len=$((2 + ${#input}))  # "? " (2 chars) + input length
        
        # Only show format hint if mask is not already in the message
        if [[ ! "$message" =~ "$mask" ]]; then
            printf '%bFormat: %s%b\n' "${DIM}" "$mask" "${NC}" >&2
            # Move cursor down 1 line for keybindings
            printf '\033[B' >&2
            printf '\r' >&2  # Return to start of keybindings line
        else
            # Still need a blank line for spacing
            printf '\n' >&2
            # Move cursor down 1 line for keybindings
            printf '\033[B' >&2
            printf '\r' >&2  # Return to start of keybindings line
        fi
        
        # Display keybindings
        local keybindings
        keybindings=$(_imenu_get_keybindings "date" "$has_back")
        if [ -n "$keybindings" ]; then
            printf '%b%s%b\n' "${GRAY}" "$keybindings" "${NC}" >&2
        else
            printf '\n' >&2  # Newline if no keybindings
        fi
        
        # Move cursor back up to the input line
        # After printing keybindings with newline, we're 2 lines down from input line
        if [[ ! "$message" =~ "$mask" ]]; then
            # Format hint shown: move up 2 lines (format hint + keybindings)
            printf '\033[A\033[A' >&2
        else
            # No format hint: move up 2 lines (blank + keybindings)
            printf '\033[A\033[A' >&2
        fi
        
        # Position cursor at the end of the displayed text (after input)
        printf '\r' >&2  # Move to start of line
        printf '\033[%dC' "$display_len" >&2  # Move cursor right to end of display
        
        # Show cursor at the correct position for input
        _imenu_show_cursor
        
        # Read input
        local key
        key=$(_imenu_read_char)
        
        # Hide cursor again immediately after reading for clean redraw
        _imenu_hide_cursor
        
        if [ "$key" = $'\n' ] || [ "$key" = $'\r' ] || [ -z "$key" ]; then
            # Enter pressed, submit
            # Allow empty input to be submitted
            if [ -z "$input" ]; then
                break
            fi
            # Validate date format (basic check)
            if date -d "$input" >/dev/null 2>&1 || date -j -f "%Y-%m-%d %H:%M:%S" "$input" >/dev/null 2>&1 2>/dev/null; then
                break
            fi
            printf '\r%bInvalid date format%b' "${RED}" "${NC}" >&2
            sleep 1
            _imenu_clear_line
            continue
        elif [ "$key" = $'\x7f' ] || [ "$key" = $'\b' ]; then
            # Backspace
            if [ ${#input} -gt 0 ]; then
                input="${input:0:$((${#input}-1))}"
            fi
        elif [ "$key" = $'\x1b' ]; then
            local arrow
            arrow=$(_imenu_read_escape)
            case "$arrow" in
                "A"|"B"|"C"|"D")  # Arrow keys - ignore (do nothing for date input)
                    ;;
                *)
                    _imenu_show_cursor
                    _imenu_clear_menu $menu_lines
                    return 1
                    ;;
            esac
        elif [ "$key" = "b" ] || [ "$key" = "B" ]; then
            if [ "$has_back" = "true" ]; then
                _imenu_show_cursor
                _imenu_clear_menu $menu_lines
                return 2
            fi
        else
            # Regular character
            input="${input}${key}"
        fi
        
        # Hide cursor again immediately after reading for clean redraw
        _imenu_hide_cursor
        
        # Validate if function provided
        if [ -n "$validate_func" ] && _imenu_is_function "$validate_func"; then
            local validation_result
            validation_result=$("$validate_func" "$input")
            if [ "$validation_result" != "true" ] && [ -n "$validation_result" ]; then
                printf '\r%b%s%b' "${RED}" "$validation_result" "${NC}" >&2
                sleep 1
                continue  # Will redraw on next iteration
            fi
        fi
        
        # Clear menu lines for redraw (similar to other prompts)
        # We're at the input line, so clear downward
        printf '\r' >&2
        _imenu_clear_line  # Clear input line
        if [[ ! "$message" =~ "$mask" ]]; then
            printf '\033[B' >&2  # Move down to format hint line
            printf '\r' >&2
            _imenu_clear_line  # Clear format hint line
        else
            printf '\033[B' >&2  # Move down to blank line
            printf '\r' >&2
            _imenu_clear_line  # Clear blank line
        fi
        printf '\033[B' >&2  # Move down to keybindings line
        printf '\r' >&2
        _imenu_clear_line  # Clear keybindings line
        # Move back up to input line
        if [[ ! "$message" =~ "$mask" ]]; then
            printf '\033[A\033[A' >&2  # Up 2 lines (format hint + keybindings)
        else
            printf '\033[A\033[A' >&2  # Up 2 lines (blank + keybindings)
        fi
    done
    
    _imenu_show_cursor
    _imenu_clear_menu $menu_lines
    
    # Store ONLY menu lines (not message lines) for next step clearing
    # Messages persist across steps, so we should only clear the menu part
    IMENU_LAST_LINES=$menu_lines
    
    # Format
    local formatted_value="$input"
    if [ -n "$format_func" ] && _imenu_is_function "$format_func"; then
        formatted_value=$("$format_func" "$input")
    fi
    
    # Store response
    _IMENU_RESPONSES_MAP["$name"]="$formatted_value"
    
    # Output to stdout
    echo "$formatted_value"
    
    return 0
}

