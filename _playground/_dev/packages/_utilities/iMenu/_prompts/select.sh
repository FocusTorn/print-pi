#!/usr/bin/env bash
# iMenu Prompt: select
# Single-select menu with dynamic flag parsing and line counting
# This file is a library and must be sourced, not executed directly

# Prevent direct execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "Error: This script is a library and must be sourced, not executed directly." >&2
    echo "Usage: source '$(basename "$0")' or use via iMenu.sh" >&2
    exit 1
fi

_prompt_select() {
    local name="$1"
    local message="$2"
    shift 2
    local choices=("$@")
    
    # Parse flags from choices array (--preselect, --message)
    local preselect_idx=""
    local parsed_choices=()
    local i
    local skip_indices=()
    
    for ((i=0; i<${#choices[@]}; i++)); do
        if [ "${choices[i]}" = "--preselect" ]; then
            preselect_idx="${choices[i+1]}"
            skip_indices+=("$i" "$((i+1))")
            ((i++))
        elif [ "${choices[i]}" = "--message" ]; then
            message="${choices[i+1]}"
            skip_indices+=("$i" "$((i+1))")
            ((i++))
        fi
    done
    
    # Re-pack array excluding skipped indices
    for ((i=0; i<${#choices[@]}; i++)); do
        local should_skip=false
        for skip_idx in "${skip_indices[@]}"; do
            if [ "$i" -eq "$skip_idx" ]; then
                should_skip=true
                break
            fi
        done
        if [ "$should_skip" != true ]; then
            parsed_choices+=("${choices[i]}")
        fi
    done
    choices=("${parsed_choices[@]}")
    
    # Apply preselection if provided
    if [ -n "$preselect_idx" ]; then
        export IMENU_INITIAL="$preselect_idx"
    fi
    
    local initial="${IMENU_INITIAL:-0}"
    local hint="${IMENU_HINT:-}"
    local format_func="${IMENU_FORMAT:-}"
    local has_back="${IMENU_HAS_BACK:-false}"
    
    # Display message if provided
    if [ -n "$message" ]; then
        local message_prefix="${IMENU_MESSAGE_PREFIX:-}"
        if [ -n "$message_prefix" ]; then
            printf '%b%s %s%b\n' "${BLUE}" "$message_prefix" "$message" "${NC}" >&2
        else
            printf '%b%s%b\n' "${BLUE}" "$message" "${NC}" >&2
        fi
        # Print blank line after message unless suppressed (for wizard mode step 2+)
        # We'll add blank line before options display instead
        if [ "${IMENU_NO_MESSAGE_BLANK:-false}" != "true" ]; then
            printf '\n' >&2
        fi
    fi
    
    local num_options=${#choices[@]}
    if [ $num_options -eq 0 ]; then
        printf '%bNo choices provided%b\n' "${RED}" "${NC}" >&2
        return 1
    fi
    
    local current=$initial
    if [ $current -lt 0 ] || [ $current -ge $num_options ]; then
        current=0
    fi
    
    local selected_idx=$current
    
    _imenu_hide_cursor
    
    # Calculate menu lines displayed in loop
    local menu_lines=$((num_options + 2))  # Options + blank + keybindings line
    if [ -n "$hint" ]; then
        menu_lines=$((menu_lines + 1))  # Hint line
    fi
    
    # Add blank line before options if flag is set (for spacing between message and options)
    # This blank line is printed ONCE before the loop, not inside the loop
    local blank_before_options=false
    if [ "${IMENU_MESSAGE_OPTIONS_GAP:-false}" = "true" ]; then
        printf '\n' >&2
        blank_before_options=true
        # Don't include this blank line in menu_lines - it's printed once, not redrawn
    fi
    
    # Total lines = message + menu (for clearing when transitioning steps)
    local total_lines=$((message_lines + menu_lines))
    if [ "$blank_before_options" = true ]; then
        total_lines=$((total_lines + 1))  # Include blank line in total for step transitions
    fi
    
    while true; do
        # Display menu options
        for ((i=0; i<num_options; i++)); do
            local prefix="  "
            if [ $i -eq $current ]; then
                prefix="${CYAN}❯${NC} "
            fi
            
            printf '%b%s\n' "$prefix" "${choices[i]}" >&2
        done
        printf '\n' >&2  # Blank line between options and keybindings
        
        # Display keybindings (redrawn each time)
        local keybindings
        keybindings=$(_imenu_get_keybindings "select" "$has_back")
        if [ -n "$keybindings" ]; then
            printf '%b%s%b\n' "${GRAY}" "$keybindings" "${NC}" >&2
        fi
        
        # Display hint if provided
        if [ -n "$hint" ]; then
            printf '%b%s%b\n' "${DIM}" "$hint" "${NC}" >&2
        fi
        
        # Mark that we've drawn at least once
        # Don't save cursor - we'll clear from current position next iteration
        first_iteration=false
        
        # Read input
        local key
        key=$(_imenu_read_char)
        
        if [ "$key" = $'\n' ] || [ "$key" = $'\r' ] || [ -z "$key" ]; then
            # Enter pressed, confirm selection
            selected_idx=$current
            break
        fi
        
        case "$key" in
            " ")  # Space selects current item
                selected_idx=$current
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
                    "A")  # Up arrow
                        current=$(((current - 1 + num_options) % num_options))
                        ;;
                    "B")  # Down arrow
                        current=$(((current + 1) % num_options))
                        ;;
                    "C"|"D")  # Left/Right arrows - ignore (do nothing)
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
    # iWizard handles all clearing by clearing from line 6 down
    # Don't position cursor - let iWizard handle everything
    
    # Clean up IMENU_INITIAL if we set it
    if [ -n "$preselect_idx" ]; then
        unset IMENU_INITIAL
    fi
    
    # Store ONLY menu lines (not message lines) for next step clearing
    # Messages persist across steps, so we should only clear the menu part
    # Include blank line before options if it was printed
    # (No action needed - iWizard handles all clearing)
    
    # Format
    local formatted_value="${choices[$selected_idx]}"
    if [ -n "$format_func" ] && _imenu_is_function "$format_func"; then
        formatted_value=$("$format_func" "${choices[$selected_idx]}" "$selected_idx")
    fi
    
    # Store response
    _IMENU_RESPONSES_MAP["$name"]="$formatted_value"
    
    # Output selected index to stdout
    echo "$selected_idx"
    
    return 0
}

