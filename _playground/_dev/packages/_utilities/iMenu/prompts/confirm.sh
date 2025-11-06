#!/usr/bin/env bash
# iMenu Prompt: confirm
# Classic yes/no confirmation prompt

imenu_confirm() {
    local name="$1"
    local message="$2"
    local initial="${3:-false}"
    local format_func="${4:-}"
    
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
    
    # Display message if provided
    if [ -n "$message" ]; then
        local message_prefix="${IMENU_MESSAGE_PREFIX:-}"
        # Append (y/N) or (Y/n) based on initial value
        local default_hint
        if [ "$initial_bool" = true ]; then
            default_hint="(Y/n)"
        else
            default_hint="(y/N)"
        fi
        
        if [ -n "$message_prefix" ]; then
            printf '%b%s %s %s%b\n' "${BLUE}" "$message_prefix" "$message" "$default_hint" "${NC}" >&2
        else
            printf '%b%s %s%b\n' "${BLUE}" "$message" "$default_hint" "${NC}" >&2
        fi
        # Print blank line after message unless suppressed (for wizard mode step 2+)
        # We'll add blank line before prompt display instead
        if [ "${IMENU_NO_MESSAGE_BLANK:-false}" != "true" ]; then
            printf '\n' >&2
        fi
    fi
    
    local result=$initial_bool
    
    _imenu_hide_cursor
    
    # Calculate message lines for total count
    local message_lines=0
    if [ -n "$message" ]; then
        message_lines=$(echo -n "$message" | grep -c '^' || echo "1")
        if [ "$message_lines" -eq 0 ]; then
            message_lines=1
        fi
        message_lines=$((message_lines + 1))  # +1 for blank line after message
    fi
    
    local menu_lines=4  # Two options (Yes/No) + blank + keybindings
    
    # Add blank line before options if flag is set (for spacing between message and options)
    local blank_before_options=false
    if [ "${IMENU_MESSAGE_OPTIONS_GAP:-false}" = "true" ]; then
        printf '\n' >&2
        blank_before_options=true
        menu_lines=$((menu_lines + 1))  # Include blank line in menu_lines
    fi
    
    # Total lines = message + menu (for clearing when transitioning steps)
    local total_lines=$((message_lines + menu_lines))
    
    # Current selection index (0 = Yes, 1 = No)
    local current_idx=0
    if [ "$result" = false ]; then
        current_idx=1
    fi
    
    local choices=("Yes" "No")
    
    while true; do
        # Display select menu with Yes/No options
        for ((i=0; i<${#choices[@]}; i++)); do
            local prefix="  "
            if [ $i -eq $current_idx ]; then
                prefix="${CYAN}❯${NC} "
            fi
            printf '%b%s%b\n' "$prefix" "${choices[i]}" "${NC}" >&2
        done
        printf '\n' >&2  # Blank line between options and keybindings
        
        # Display keybindings
        local keybindings
        keybindings=$(_imenu_get_keybindings "confirm" "$has_back")
        if [ -n "$keybindings" ]; then
            printf '%b%s%b\n' "${GRAY}" "$keybindings" "${NC}" >&2
        fi
        
        # Read input
        local key
        key=$(_imenu_read_char)
        
        if [ "$key" = $'\n' ] || [ "$key" = $'\r' ] || [ -z "$key" ]; then
            # Enter pressed, confirm selection
            result=$([ $current_idx -eq 0 ] && echo true || echo false)
            break
        fi
        
        case "$key" in
            "y"|"Y")
                result=true
                break
                ;;
            "n"|"N")
                result=false
                break
                ;;
            "b"|"B")
                if [ "$has_back" = "true" ]; then
                    _imenu_show_cursor
                    _imenu_clear_menu $menu_lines
                    return 2
                fi
                ;;
            $'\x1b')
                local arrow
                arrow=$(_imenu_read_escape)
                case "$arrow" in
                    "A")  # Up arrow
                        current_idx=$(((current_idx - 1 + 2) % 2))
                        result=$([ $current_idx -eq 0 ] && echo true || echo false)
                        ;;
                    "B")  # Down arrow
                        current_idx=$(((current_idx + 1) % 2))
                        result=$([ $current_idx -eq 0 ] && echo true || echo false)
                        ;;
                    "C"|"D")  # Left/Right arrows - ignore (do nothing)
                        ;;
                    *)
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
    # Clear menu lines (including blank before options if it was printed)
    local lines_to_clear=$menu_lines
    _imenu_clear_menu $lines_to_clear
    
    # Store ONLY menu lines (not message lines) for next step clearing
    # Messages persist across steps, so we should only clear the menu part
    # Don't include blank line before prompt - it's already cleared when prompt finishes
    IMENU_LAST_LINES=$menu_lines
    
    # Format
    local formatted_value="$result"
    if [ -n "$format_func" ] && _imenu_is_function "$format_func"; then
        formatted_value=$("$format_func" "$result")
    fi
    
    # Store response
    _IMENU_RESPONSES_MAP["$name"]="$formatted_value"
    
    # Output to stdout
    echo "$formatted_value"
    
    return 0
}

