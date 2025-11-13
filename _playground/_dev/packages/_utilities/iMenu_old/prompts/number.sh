#!/usr/bin/env bash
# iMenu Prompt: number
# Numeric input prompt with min/max validation
# This file is a library and must be sourced, not executed directly

# Prevent direct execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "Error: This script is a library and must be sourced, not executed directly." >&2
    echo "Usage: source '$(basename "$0")' or use via iMenu.sh" >&2
    exit 1
fi

imenu_number() {
    local name="$1"
    local message="$2"
    local initial="${3:-}"
    local min="${4:-${IMENU_MIN:-}}"
    local max="${5:-${IMENU_MAX:-}}"
    local validate_func="${6:-}"
    local format_func="${7:-}"
    
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
        # Only print blank line if not suppressed (for wizard mode)
        if [ "${IMENU_NO_MESSAGE_BLANK:-false}" != "true" ]; then
            printf '\n' >&2
        fi
    fi
    
    local input="$initial"
    local num_value=0
    
    # Parse initial as number only if provided
    if [ -n "$initial" ]; then
        num_value=$(($initial + 0)) 2>/dev/null || num_value=0
    fi
    
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
    
    local menu_lines=4  # Prompt line + blank + blank + keybindings line
    
    # Total lines = message + menu
    local total_lines=$((message_lines + menu_lines))
    
    local first_iteration=true
    
    while true; do
        if [ "$first_iteration" = false ]; then
            # Clear the four lines we're displaying (input, blank, blank, keybindings)
            # We're positioned at the input line, so clear downward using cursor movement
            printf '\r' >&2
            _imenu_clear_line  # Clear input line
            printf '\033[B' >&2  # Move down to first blank line (no newline)
            printf '\r' >&2
            _imenu_clear_line  # Clear first blank line
            printf '\033[B' >&2  # Move down to second blank line (no newline)
            printf '\r' >&2
            _imenu_clear_line  # Clear second blank line
            printf '\033[B' >&2  # Move down to keybindings line (no newline)
            printf '\r' >&2
            _imenu_clear_line  # Clear keybindings line
            # Move back up to input line (3 lines up)
            printf '\033[A\033[A\033[A' >&2
        else
            first_iteration=false
        fi
        
        # Display prompt with input (line 1) - no newline, just print
        printf '%b?%b %s' "${CYAN}" "${NC}" "$input" >&2
        local display_len=$((2 + ${#input}))  # "? " (2 chars) + input length
        
        # Move cursor down 1 line for first blank line (line 2)
        printf '\033[B' >&2
        printf '\r' >&2  # Return to start of first blank line
        
        # Move cursor down 1 line for second blank line (line 3)
        printf '\033[B' >&2
        printf '\r' >&2  # Return to start of second blank line
        
        # Move cursor down 1 line for keybindings (line 4)
        printf '\033[B' >&2
        printf '\r' >&2  # Return to start of keybindings line
        
        # Display keybindings
        local keybindings
        keybindings=$(_imenu_get_keybindings "number" "$has_back")
        if [ -n "$keybindings" ]; then
            printf '%b%s%b\n' "${GRAY}" "$keybindings" "${NC}" >&2
        else
            printf '\n' >&2  # Newline if no keybindings
        fi
        
        # Move cursor back up four lines to the input line
        # (After printing keybindings with newline, we're 4 lines down from input line)
        printf '\033[A\033[A\033[A\033[A' >&2
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
            if [ -n "$input" ]; then
                # Validate number
                num_value=$(($input + 0)) 2>/dev/null
                if [ $? -ne 0 ]; then
                    printf '\r%bInvalid number%b' "${RED}" "${NC}" >&2
                    sleep 1
                    continue  # Will redraw on next iteration
                fi
                
                # Check min/max
                if [ -n "$min" ] && [ $num_value -lt $min ]; then
                    printf '\r%bValue must be at least %d%b' "${RED}" "$min" "${NC}" >&2
                    sleep 1
                    continue  # Will redraw on next iteration
                fi
                
                if [ -n "$max" ] && [ $num_value -gt $max ]; then
                    printf '\r%bValue must be at most %d%b' "${RED}" "$max" "${NC}" >&2
                    sleep 1
                    continue  # Will redraw on next iteration
                fi
            fi
            # Allow empty input to be submitted (break out of loop)
            break
        elif [ "$key" = $'\x7f' ] || [ "$key" = $'\b' ]; then
            # Backspace
            if [ ${#input} -gt 0 ]; then
                input="${input:0:$((${#input}-1))}"
                if [ -z "$input" ]; then
                    input=""
                    num_value=0
                else
                    num_value=$(($input + 0)) 2>/dev/null || num_value=0
                fi
            fi
        elif [ "$key" = $'\x09' ]; then
            # Tab - autocomplete to initial
            if [ -n "$initial" ]; then
                input="$initial"
                num_value=$(($initial + 0)) 2>/dev/null || num_value=0
            fi
        elif [ "$key" = $'\x1b' ]; then
            # Escape sequence (arrow keys)
            local arrow
            arrow=$(_imenu_read_escape)
            case "$arrow" in
                "A")  # Up arrow - increment
                    if [ -n "$input" ]; then
                        num_value=$(($input + 0)) 2>/dev/null || num_value=0
                    fi
                    num_value=$((num_value + 1))
                    if [ -n "$max" ] && [ $num_value -gt $max ]; then
                        num_value=$max
                    fi
                    input="$num_value"
                    ;;
                "B")  # Down arrow - decrement
                    if [ -n "$input" ]; then
                        num_value=$(($input + 0)) 2>/dev/null || num_value=0
                    fi
                    num_value=$((num_value - 1))
                    if [ -n "$min" ] && [ $num_value -lt $min ]; then
                        num_value=$min
                    fi
                    input="$num_value"
                    ;;
                "C"|"D")  # Left/Right arrows - ignore (do nothing)
                    ;;
                *)  # ESC pressed (no arrow)
                    _imenu_show_cursor
                    _imenu_clear_menu 3
                    return 1
                    ;;
            esac
        elif [ "$key" = "b" ] || [ "$key" = "B" ]; then
            # Back
            if [ "$has_back" = "true" ]; then
                _imenu_show_cursor
                _imenu_clear_menu 3
                return 2
            fi
        elif [[ "$key" =~ [0-9] ]]; then
            # Number - add to input
            input="${input}${key}"
            num_value=$(($input + 0)) 2>/dev/null || num_value=0
        fi
        
        # Validate if function provided
        if [ -n "$validate_func" ] && _imenu_is_function "$validate_func"; then
            local validation_result
            validation_result=$("$validate_func" "$num_value")
            if [ "$validation_result" != "true" ] && [ -n "$validation_result" ]; then
                printf '\r%b%s%b' "${RED}" "$validation_result" "${NC}" >&2
                sleep 1
                continue  # Will redraw on next iteration
            fi
        fi
    done
    
    _imenu_show_cursor
    # iWizard handles all clearing by clearing from line 6 down
    # Don't clear or position cursor - just ensure cursor is visible
    
    # Store ONLY menu lines (not message lines) for next step clearing
    # Messages persist across steps, so we should only clear the menu part
    IMENU_LAST_LINES=$menu_lines
    
    # Format
    local formatted_value="$num_value"
    if [ -n "$format_func" ] && _imenu_is_function "$format_func"; then
        formatted_value=$("$format_func" "$num_value")
    fi
    
    # Store response
    _IMENU_RESPONSES_MAP["$name"]="$formatted_value"
    
    # Output to stdout
    # If input was empty and no initial was provided, return empty string
    # Otherwise return the numeric value (or 0 if input was empty but initial was set)
    if [ -z "$initial" ] && [ -z "$input" ]; then
        echo ""
    else
        echo "$formatted_value"
    fi
    
    return 0
}

