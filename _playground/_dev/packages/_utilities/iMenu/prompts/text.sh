#!/usr/bin/env bash
# iMenu Prompt: text
# Free text input prompt

imenu_text() {
    local name="$1"
    local message="$2"
    local initial="${3:-}"
    local style="${4:-default}"
    local validate_func="${5:-}"
    local format_func="${6:-}"
    
    local title="${IMENU_TITLE:-}"
    local has_back="${IMENU_HAS_BACK:-false}"
    local clear_previous_lines="${IMENU_CLEAR_PREVIOUS:-0}"
    local input_inline="${IMENU_INPUT_INLINE:-false}"
    
    # Clear previous menu if requested
    if [ "$clear_previous_lines" -gt 0 ]; then
        _imenu_clear_menu $clear_previous_lines
    fi
    
    # Print header with title only
    _imenu_print_header "$title"
    
    local input="$initial"
    local show_input=true
    local mask_input=false
    
    # Handle style
    case "$style" in
        password)
            show_input=false
            mask_input=true
            ;;
        invisible)
            show_input=false
            mask_input=false
            ;;
        default|*)
            show_input=true
            mask_input=false
            ;;
    esac
    
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
    
    local menu_lines=3  # Prompt line + blank + keybindings line
    if [ "$input_inline" = true ]; then
        menu_lines=2  # Blank + keybindings line (input is on same line as message)
    fi
    
    # Total lines = message + menu
    local total_lines=$((message_lines + menu_lines))
    
    local first_iteration=true
    
    while true; do
        if [ "$first_iteration" = false ]; then
            if [ "$input_inline" = true ]; then
                # Clear two lines (blank + keybindings)
                printf '\033[B' >&2  # Move down to blank line
                printf '\r' >&2
                _imenu_clear_line  # Clear blank line
                printf '\033[B' >&2  # Move down to keybindings line
                printf '\r' >&2
                _imenu_clear_line  # Clear keybindings line
                # Move back up to message line (2 lines up)
                printf '\033[A\033[A' >&2
            else
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
            fi
        else
            first_iteration=false
        fi
        
        # Display message and input
        if [ "$input_inline" = true ]; then
            # Inline mode: message and input on same line
            if [ -n "$message" ]; then
                local message_prefix="${IMENU_MESSAGE_PREFIX:-}"
                if [ -n "$message_prefix" ]; then
                    printf '%b%s %s%b' "${BLUE}" "$message_prefix" "$message" "${NC}" >&2
                else
                    printf '%b%s%b' "${BLUE}" "$message" "${NC}" >&2
                fi
                printf ' ' >&2  # Space between message and input
            fi
            
            # Display input inline
            if [ "$show_input" = true ]; then
                printf '%b%s%b' "${CYAN}" "$input" "${NC}" >&2
                local display_len=$((${#message} + 1 + ${#input}))  # message + space + input
                if [ -n "$message_prefix" ]; then
                    display_len=$((display_len + ${#message_prefix} + 1))  # + prefix + space
                fi
            elif [ "$mask_input" = true ]; then
                # Show masked characters (password style)
                local masked=""
                local len=${#input}
                for ((i=0; i<len; i++)); do
                    masked="${masked}*"
                done
                printf '%b%s%b' "${CYAN}" "$masked" "${NC}" >&2
                local display_len=$((${#message} + 1 + len))  # message + space + masked
                if [ -n "$message_prefix" ]; then
                    display_len=$((display_len + ${#message_prefix} + 1))  # + prefix + space
                fi
            else
                # Invisible style - show nothing
                local display_len=$((${#message} + 1))  # message + space
                if [ -n "$message_prefix" ]; then
                    display_len=$((display_len + ${#message_prefix} + 1))  # + prefix + space
                fi
            fi
            # Don't print newline yet - we'll position cursor first
            # printf '\n' >&2  # Newline after message+input
            
            # Move cursor down 1 line for blank line (line 2)
            printf '\033[B' >&2
            printf '\r' >&2  # Return to start of blank line
            
            # Move cursor down 1 line for keybindings (line 3)
            printf '\033[B' >&2
            printf '\r' >&2  # Return to start of keybindings line
            
            # Display keybindings
            local keybindings
            keybindings=$(_imenu_get_keybindings "text" "$has_back")
            if [ -n "$keybindings" ]; then
                printf '%b%s%b\n' "${GRAY}" "$keybindings" "${NC}" >&2
            else
                printf '\n' >&2  # Newline if no keybindings
            fi
            
            # Move cursor back up two lines to the message line
            printf '\033[A\033[A' >&2
            # Position cursor at the end of the displayed text (after input)
            printf '\r' >&2  # Move to start of line
            printf '\033[%dC' "$display_len" >&2  # Move cursor right to end of display
        else
            # Display message if provided (non-inline mode)
            if [ -n "$message" ]; then
                local message_prefix="${IMENU_MESSAGE_PREFIX:-}"
                if [ -n "$message_prefix" ]; then
                    printf '%b%s %s%b\n' "${BLUE}" "$message_prefix" "$message" "${NC}" >&2
                else
                    printf '%b%s%b\n' "${BLUE}" "$message" "${NC}" >&2
                fi
                # Only print blank line if not suppressed (for wizard mode)
                if [ "${IMENU_NO_MESSAGE_BLANK:-false}" != "true" ]; then
                    printf '\n' >&2
                fi
            fi
            
            # Display prompt with input (line 1) - no newline, just print
            if [ "$show_input" = true ]; then
                printf '%b?%b %s' "${CYAN}" "${NC}" "$input" >&2
                local display_len=$((2 + ${#input}))  # "? " (2 chars) + input length
            elif [ "$mask_input" = true ]; then
                # Show masked characters (password style)
                local masked=""
                local len=${#input}
                for ((i=0; i<len; i++)); do
                    masked="${masked}*"
                done
                printf '%b?%b %s' "${CYAN}" "${NC}" "$masked" >&2
                local display_len=$((2 + len))  # "? " (2 chars) + masked length
            else
                # Invisible style - show nothing, just the prompt
                printf '%b?%b ' "${CYAN}" "${NC}" >&2
                local display_len=2  # "? " (2 chars), input is invisible
            fi
            
            # Move cursor down 1 line for blank line (line 2)
            printf '\033[B' >&2
            printf '\r' >&2  # Return to start of blank line
            
            # Move cursor down 1 line for keybindings (line 3)
            printf '\033[B' >&2
            printf '\r' >&2  # Return to start of keybindings line
            
            # Display keybindings
            local keybindings
            keybindings=$(_imenu_get_keybindings "text" "$has_back")
            if [ -n "$keybindings" ]; then
                printf '%b%s%b' "${GRAY}" "$keybindings" "${NC}" >&2
            fi
            
            # Move cursor back up two lines to the input line
            printf '\033[A\033[A' >&2
            # Position cursor at the end of the displayed text (after input)
            printf '\r' >&2  # Move to start of line
            printf '\033[%dC' "$display_len" >&2  # Move cursor right to end of display
        fi
        
        # Show cursor at the correct position for input
        _imenu_show_cursor
        
        # Read a single character
        local key
        key=$(_imenu_read_char)
        
        # Hide cursor again immediately after reading for clean redraw
        _imenu_hide_cursor
        
        if [ "$key" = $'\n' ] || [ "$key" = $'\r' ] || [ -z "$key" ]; then
            # Enter pressed, submit
            if [ -n "$input" ] || [ -z "$initial" ]; then
                break
            fi
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
            # Escape sequence
            local arrow
            arrow=$(_imenu_read_escape)
            case "$arrow" in
                "A"|"B"|"C"|"D")  # Arrow keys - ignore (do nothing for text input)
                    ;;
                *)  # ESC pressed (no arrow)
                    _imenu_show_cursor
                    _imenu_clear_menu $menu_lines
                    return 1
                    ;;
            esac
        elif [ "$key" = "b" ] || [ "$key" = "B" ]; then
            # Back
            if [ "$has_back" = "true" ]; then
                _imenu_show_cursor
                _imenu_clear_menu $menu_lines
                return 2
            fi
        else
            # Regular character
            input="${input}${key}"
        fi
        
        # Validate if function provided
        if [ -n "$validate_func" ] && _imenu_is_function "$validate_func"; then
            local validation_result
            validation_result=$("$validate_func" "$input")
            if [ "$validation_result" != "true" ] && [ -n "$validation_result" ]; then
                # Show error on input line and continue
                printf '\r%b%s%b' "${RED}" "$validation_result" "${NC}" >&2
                sleep 1
                continue  # Will redraw on next iteration
            fi
        fi
    done
    
    _imenu_show_cursor
    # Clear menu lines based on mode
    if [ "$input_inline" = true ]; then
        # Clear two lines (blank + keybindings)
        printf '\033[B' >&2  # Move down to blank line
        printf '\r' >&2
        _imenu_clear_line  # Clear blank line
        printf '\033[B' >&2  # Move down to keybindings line
        printf '\r' >&2
        _imenu_clear_line  # Clear keybindings line
    else
        # Clear all three lines (input, blank, keybindings)
        printf '\r' >&2
        _imenu_clear_line  # Clear input line
        printf '\033[B' >&2  # Move down to blank line
        printf '\r' >&2
        _imenu_clear_line  # Clear blank line
        printf '\033[B' >&2  # Move down to keybindings line
        printf '\r' >&2
        _imenu_clear_line  # Clear keybindings line
    fi
    
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

