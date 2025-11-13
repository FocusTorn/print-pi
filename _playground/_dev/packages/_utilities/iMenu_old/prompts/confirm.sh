#!/usr/bin/env bash
# iMenu Prompt: confirm
# Classic yes/no confirmation prompt
# This file is a library and must be sourced, not executed directly

# Prevent direct execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "Error: This script is a library and must be sourced, not executed directly." >&2
    echo "Usage: source '$(basename "$0")' or use via iMenu.sh" >&2
    exit 1
fi

imenu_confirm() {
    local name="$1"
    local message="$2"
    local initial="${3:-}"
    local format_func="${4:-}"
    
    # Use IMENU_INITIAL from environment if set (from --initial flag), otherwise use positional arg
    if [ -n "${IMENU_INITIAL:-}" ]; then
        initial="${IMENU_INITIAL}"
    fi
    
    # Default to false if not provided
    if [ -z "$initial" ]; then
        initial="false"
    fi
    
    # Convert initial to boolean
    local initial_bool=false
    if [ "$initial" = "true" ] || [ "$initial" = "Y" ] || [ "$initial" = "y" ] || [ "$initial" = "1" ]; then
        initial_bool=true
    fi
    
    local title="${IMENU_TITLE:-}"
    local has_back="${IMENU_HAS_BACK:-false}"
    local clear_previous_lines="${IMENU_CLEAR_PREVIOUS:-0}"
    
    # Clear previous menu if requested
    if [ "$clear_previous_lines" -gt 0 ]; then
        _imenu_clear_menu $clear_previous_lines
    fi
    
    # Print header with title only
    _imenu_print_header "$title"
    
    _imenu_hide_cursor
    
    # Calculate message lines for total count
    local message_lines=0
    if [ -n "$message" ]; then
        message_lines=$(echo -n "$message" | grep -c '^' || echo "1")
        if [ "$message_lines" -eq 0 ]; then
            message_lines=1
        fi
    fi
    
    local menu_lines=4  # Prompt line + blank + blank + keybindings line
    
    # Total lines = message + menu (for clearing when transitioning steps)
    local total_lines=$((message_lines + menu_lines))
    
    local result=$initial_bool
    local first_iteration=true
    
    while true; do
        if [ "$first_iteration" = false ]; then
            # Clear the four lines we're displaying (input, blank, blank, keybindings)
            # We're currently on the input line, so clear downward
            printf '\r' >&2
            _imenu_clear_line  # Clear input line
            printf '\033[B' >&2  # Move down to first blank line
            printf '\r' >&2
            _imenu_clear_line  # Clear first blank line
            printf '\033[B' >&2  # Move down to second blank line
            printf '\r' >&2
            _imenu_clear_line  # Clear second blank line
            printf '\033[B' >&2  # Move down to keybindings line
            printf '\r' >&2
            _imenu_clear_line  # Clear keybindings line
            # Move back up to input line (3 lines up)
            printf '\033[A\033[A\033[A' >&2
        else
            first_iteration=false
        fi
        
        # Display message and input inline (like text prompt)
        local message_display_len=0
        if [ -n "$message" ]; then
            local message_prefix="${IMENU_MESSAGE_PREFIX:-}"
            if [ -n "$message_prefix" ]; then
                printf '%b%s %s%b' "${BLUE}" "$message_prefix" "$message" "${NC}" >&2
                message_display_len=$((${#message_prefix} + 1 + ${#message}))
            else
                printf '%b%s%b' "${BLUE}" "$message" "${NC}" >&2
                message_display_len=${#message}
            fi
            # Add (y/N) or (Y/n) hint based on default
            local default_hint
            if [ "$result" = true ]; then
                default_hint="(Y/n)"
            else
                default_hint="(y/N)"
            fi
            printf ' %s ' "$default_hint" >&2
            message_display_len=$((message_display_len + ${#default_hint} + 2))  # + space + hint + space
        fi
        
        # Display prompt indicator
        printf '%b?%b ' "${CYAN}" "${NC}" >&2
        local prompt_len=2  # "? " (2 chars)
        
        # Display default value as just the letter in dimmed color (lowercase)
        local default_letter
        if [ "$result" = true ]; then
            default_letter="y"
        else
            default_letter="n"
        fi
        printf '%b%s%b' "${DIM}" "$default_letter" "${NC}" >&2
        local input_display_len=1  # Just one letter
        
        # Calculate total display length for cursor positioning
        local total_display_len=$((message_display_len + prompt_len + input_display_len))
        
        # Print newline to move to blank line (one blank line between message+input and keybindings)
        printf '\n' >&2
        # Ensure blank line is visible before keybindings
        printf '\n' >&2
        
        # Display keybindings on next line
        local keybindings
        keybindings=$(_imenu_get_keybindings "confirm" "$has_back")
        if [ -n "$keybindings" ]; then
            printf '%b%s%b\n' "${GRAY}" "$keybindings" "${NC}" >&2
        else
            printf '\n' >&2  # Newline if no keybindings
        fi
        
        # Move cursor back up three lines to the input line
        # (After printing with newlines: input line -> blank line -> blank line -> keybindings line = 3 lines down)
        printf '\033[A\033[A\033[A' >&2
        # Position cursor BEFORE the default/input (not after)
        printf '\r' >&2  # Move to start of line
        local cursor_pos=$((message_display_len + prompt_len))  # Position before input/default
        printf '\033[%dC' "$cursor_pos" >&2  # Move cursor right to position before input
        
        # Don't show cursor for confirm prompt - user just presses y/n
        
        # Read a single character
        local key
        key=$(_imenu_read_char)
        
        # Cursor was never shown, so no need to hide it
        
        if [ "$key" = $'\n' ] || [ "$key" = $'\r' ] || [ -z "$key" ]; then
            # Enter pressed, use default value
            break
        elif [ "$key" = $'\x7f' ] || [ "$key" = $'\b' ]; then
            # Backspace - ignore (no input to delete, just use default)
            continue
        elif [ "$key" = "y" ] || [ "$key" = "Y" ]; then
            # 'y' pressed - set to Yes and submit immediately
            result=true
            break
        elif [ "$key" = "n" ] || [ "$key" = "N" ]; then
            # 'n' pressed - set to No and submit immediately
            result=false
            break
        elif [ "$key" = "b" ] || [ "$key" = "B" ]; then
            if [ "$has_back" = "true" ]; then
                _imenu_show_cursor
                _imenu_clear_menu $menu_lines
                return 2
            fi
        elif [ "$key" = $'\x1b' ]; then
            # ESC sequence - check if it's arrow keys (ignore) or ESC (cancel)
            local arrow
            arrow=$(_imenu_read_escape)
            case "$arrow" in
                "A"|"B"|"C"|"D")
                    # Arrow keys - ignore them (no action)
                    continue
                    ;;
                *)
                    # ESC pressed (not arrow)
                    _imenu_show_cursor
                    _imenu_clear_menu $menu_lines
                    return 1
                    ;;
            esac
        else
            # Other characters - ignore (only y/n are valid)
            continue
        fi
    done
    
    _imenu_show_cursor
    # iWizard handles all clearing by clearing from line 6 down
    # Don't clear or position cursor - just ensure cursor is visible
    
    # Store menu lines for next step clearing (all 4 lines including keybindings)
    IMENU_LAST_LINES=$menu_lines
    
    # Format
    local formatted_value="$result"
    if [ -n "$format_func" ] && _imenu_is_function "$format_func"; then
        formatted_value=$("$format_func" "$result")
    fi
    
    # Store response
    _IMENU_RESPONSES_MAP["$name"]="$formatted_value"
    
    # Output to stdout (clean output, keybindings remain visible on stderr above)
    # The keybindings are on stderr, result is on stdout, so they won't mix
    echo "$formatted_value"
    
    return 0
}

