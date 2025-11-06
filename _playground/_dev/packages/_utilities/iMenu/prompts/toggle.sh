#!/usr/bin/env bash
# iMenu Prompt: toggle
# Toggle/confirm prompt (Yes/No with visual toggle)

imenu_toggle() {
    local name="$1"
    local message="$2"
    local initial="${3:-false}"
    local active_label="${4:-Yes}"
    local inactive_label="${5:-No}"
    
    # Convert initial to boolean
    local current_value=false
    if [ "$initial" = "true" ] || [ "$initial" = "Y" ] || [ "$initial" = "y" ] || [ "$initial" = "1" ]; then
        current_value=true
    fi
    
    local format_func="${IMENU_FORMAT:-}"
    local title="${IMENU_TITLE:-}"
    local has_back="${IMENU_HAS_BACK:-false}"
    
    # Print header with title only
    _imenu_print_header "$title"
    
    # Don't print message here - we'll print it inline with options in the loop
    # This ensures message and options are on the same line
    
    _imenu_hide_cursor
    
    # Calculate message lines for total count
    local message_lines=1  # Message + options on one line
    
    local menu_lines=3  # Prompt line + blank + keybindings line
    
    # Add blank line before prompt if flag is set (for spacing between message and options)
    local blank_before_prompt=false
    if [ "${IMENU_MESSAGE_OPTIONS_GAP:-false}" = "true" ]; then
        printf '\n' >&2
        blank_before_prompt=true
        menu_lines=$((menu_lines + 1))  # Include blank line in menu_lines
    fi
    
    # Total lines = message + menu (for clearing when transitioning steps)
    local total_lines=$((message_lines + menu_lines))
    
    local current_value=$initial_bool
    
    while true; do
        # Display toggle prompt inline: "Message? Yes / No" on same line
        # Always print message in loop so it's on same line as options
        if [ -n "$message" ]; then
            local message_prefix="${IMENU_MESSAGE_PREFIX:-}"
            if [ -n "$message_prefix" ]; then
                printf '%b%s %s%b' "${BLUE}" "$message_prefix" "$message" "${NC}" >&2
            else
                printf '%b%s%b' "${BLUE}" "$message" "${NC}" >&2
            fi
            printf ' ' >&2  # Space between message and options
        fi
        
        local yes_color="${NC}"
        local no_color="${NC}"
        
        if [ "$current_value" = true ]; then
            yes_color="${CYAN}"
        else
            no_color="${CYAN}"
        fi
        
        printf '%b%s%b / %b%s%b\n' \
            "$yes_color" "${active_label}" "${NC}" \
            "$no_color" "${inactive_label}" "${NC}" >&2
        printf '\n' >&2  # Blank line between prompt and keybindings
        
        # Display keybindings (redrawn each time)
        local keybindings
        keybindings=$(_imenu_get_keybindings "toggle" "$has_back")
        if [ -n "$keybindings" ]; then
            printf '%b%s%b\n' "${GRAY}" "$keybindings" "${NC}" >&2
        fi
        
        # Read input
        local key
        key=$(_imenu_read_char)
        
        if [ "$key" = $'\n' ] || [ "$key" = $'\r' ] || [ -z "$key" ]; then
            # Enter pressed, confirm
            break
        fi
        
        case "$key" in
            " ")  # Space toggles
                current_value=$([ "$current_value" = true ] && echo false || echo true)
                ;;
            "y"|"Y")  # Yes
                current_value=true
                break
                ;;
            "n"|"N")  # No
                current_value=false
                break
                ;;
            "b"|"B")  # Back
                _imenu_show_cursor
                _imenu_clear_menu $menu_lines
                return 2
                ;;
            $'\x1b')  # Escape sequence
                local arrow
                arrow=$(_imenu_read_escape)
                case "$arrow" in
                    "D")  # Left arrow - move to Yes (first option)
                        current_value=true
                        ;;
                    "C")  # Right arrow - move to No (second option)
                        current_value=false
                        ;;
                    "A"|"B")  # Up/Down arrows - ignore (do nothing)
                        ;;
                    *)  # ESC pressed (no arrow)
                        _imenu_show_cursor
                        _imenu_clear_menu $menu_lines
                        return 1
                        ;;
                esac
                ;;
        esac
        
        _imenu_clear_menu $menu_lines
    done
    
    _imenu_show_cursor
    # Clear menu lines (including blank before prompt if it was printed)
    local lines_to_clear=$menu_lines
    _imenu_clear_menu $lines_to_clear
    
    # Store ONLY menu lines (not message lines) for next step clearing
    # Messages persist across steps, so we should only clear the menu part
    # Don't include blank line before prompt - it's already cleared when prompt finishes
    IMENU_LAST_LINES=$menu_lines
    
    # Format
    local formatted_value="$current_value"
    if [ -n "$format_func" ] && _imenu_is_function "$format_func"; then
        formatted_value=$("$format_func" "$current_value")
    fi
    
    # Store response
    _IMENU_RESPONSES_MAP["$name"]="$formatted_value"
    
    # Output boolean value to stdout
    echo "$current_value"
    
    return 0
}

