#!/usr/bin/env bash
# iMenu Prompt: list
# List prompt that returns an array (comma-separated input)

imenu_list() {
    local name="$1"
    local message="$2"
    local initial="${3:-}"
    local separator="${4:-,}"
    local format_func="${5:-}"
    
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
    
    local input="$initial"
    
    # Show cursor for input prompts
    _imenu_show_cursor
    
    # Calculate message lines for total count
    local message_lines=1
    if [ -n "$message" ]; then
        message_lines=$(echo -n "$message" | grep -c '^' || echo "1")
        if [ "$message_lines" -eq 0 ]; then
            message_lines=1
        fi
    fi
    
    local menu_lines=3  # Prompt line + blank + keybindings line
    
    # Total lines = message + menu
    local total_lines=$((message_lines + menu_lines))
    
    local first_iteration=true
    
    while true; do
        if [ "$first_iteration" = false ]; then
            # Clear the three lines we're displaying (input, blank, keybindings)
            # We're positioned at the input line, so clear downward using cursor movement
            printf '\r' >&2
            _imenu_clear_line  # Clear input line
            printf '\033[B' >&2  # Move down to blank line (no newline)
            printf '\r' >&2
            _imenu_clear_line  # Clear blank line
            printf '\033[B' >&2  # Move down to keybindings line (no newline)
            printf '\r' >&2
            _imenu_clear_line  # Clear keybindings line
            # Move back up to input line (2 lines up)
            printf '\033[A\033[A' >&2
        else
            first_iteration=false
        fi
        
        # Display prompt with input (line 1) - no newline, just print
        printf '%b?%b %s' "${CYAN}" "${NC}" "$input" >&2
        local display_len=$((2 + ${#input}))  # "? " (2 chars) + input length
        
        # Move cursor down 1 line for blank line (line 2)
        printf '\033[B' >&2
        printf '\r' >&2  # Return to start of blank line
        
        # Move cursor down 1 line for keybindings (line 3)
        printf '\033[B' >&2
        printf '\r' >&2  # Return to start of keybindings line
        
        # Display keybindings
        local keybindings
        keybindings=$(_imenu_get_keybindings "list" "$has_back")
        if [ -n "$keybindings" ]; then
            printf '%b%s%b' "${GRAY}" "$keybindings" "${NC}" >&2
        fi
        
        # Move cursor back up two lines to the input line
        printf '\033[A\033[A' >&2
        # Position cursor at the end of the displayed text (after input)
        printf '\r' >&2  # Move to start of line
        printf '\033[%dC' "$display_len" >&2  # Move cursor right to end of display
        
        # Show cursor at the correct position for input
        _imenu_show_cursor
        
        # Read a single character
        local key
        key=$(_imenu_read_char)
        
        # Hide cursor again immediately after reading for clean redraw
        _imenu_hide_cursor
        
        if [ "$key" = $'\n' ] || [ "$key" = $'\r' ] || [ -z "$key" ]; then
            # Enter pressed, submit
            break
        elif [ "$key" = $'\x7f' ] || [ "$key" = $'\b' ]; then
            # Backspace
            if [ ${#input} -gt 0 ]; then
                input="${input:0:$((${#input}-1))}"
            fi
        elif [ "$key" = $'\x09' ]; then
            # Tab - autocomplete to initial if provided
            if [ -n "$initial" ] && [ "$input" != "$initial" ]; then
                input="$initial"
            fi
        elif [ "$key" = $'\x1b' ]; then
            local arrow
            arrow=$(_imenu_read_escape)
            case "$arrow" in
                "A"|"B"|"C"|"D")  # Arrow keys - ignore (do nothing for list input)
                    ;;
                *)
                    _imenu_show_cursor
                    _imenu_clear_menu 3
                    return 1
                    ;;
            esac
        elif [ "$key" = "b" ] || [ "$key" = "B" ]; then
            if [ "$has_back" = "true" ]; then
                _imenu_show_cursor
                _imenu_clear_menu 3
                return 2
            fi
        else
            # Regular character
            input="${input}${key}"
        fi
    done
    
    _imenu_show_cursor
    # Clear all three lines (prompt + blank + keybindings)
    # We're at the input line, so clear downward using cursor movement
    printf '\r' >&2
    _imenu_clear_line  # Clear input line
    printf '\033[B' >&2  # Move down to blank line (no newline)
    printf '\r' >&2
    _imenu_clear_line  # Clear blank line
    printf '\033[B' >&2  # Move down to keybindings line (no newline)
    printf '\r' >&2
    _imenu_clear_line  # Clear keybindings line
    printf '\033[A\033[A' >&2  # Move back up to input line
    
    # Store ONLY menu lines (not message lines) for next step clearing
    # Messages persist across steps, so we should only clear the menu part
    IMENU_LAST_LINES=$menu_lines
    
    # Split input by separator and trim whitespace
    local result_array=()
    if [ -n "$input" ]; then
        # Replace separator with newline, then read into array
        local IFS=$'\n'
        local temp_array
        temp_array=($(echo -n "$input" | tr "$separator" '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'))
        result_array=("${temp_array[@]}")
    fi
    
    # Format
    local formatted_value="${result_array[*]}"
    if [ -n "$format_func" ] && _imenu_is_function "$format_func"; then
        formatted_value=$("$format_func" "${result_array[@]}")
    fi
    
    # Store response
    _IMENU_RESPONSES_MAP["$name"]="$formatted_value"
    
    # Output array as space-separated string to stdout
    echo "${result_array[*]}"
    
    return 0
}

