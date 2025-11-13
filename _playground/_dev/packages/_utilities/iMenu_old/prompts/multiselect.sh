#!/usr/bin/env bash
# iMenu Prompt: multiselect
# Multi-select menu with dynamic flag parsing and line counting
# This file is a library and must be sourced, not executed directly

# Prevent direct execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "Error: This script is a library and must be sourced, not executed directly." >&2
    echo "Usage: source '$(basename "$0")' or use via iMenu.sh" >&2
    exit 1
fi

imenu_multiselect() {
    local name="$1"
    local message="$2"
    shift 2
    local choices=("$@")
    
    # Parse flags from choices array (--preselect, --message)
    local preselect_indices=""
    local parsed_choices=()
    local i
    local skip_indices=()
    
    for ((i=0; i<${#choices[@]}; i++)); do
        if [ "${choices[i]}" = "--preselect" ]; then
            preselect_indices="${choices[i+1]}"
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
    if [ -n "$preselect_indices" ]; then
        export IMENU_INITIAL="$preselect_indices"
    fi
    
    local max="${IMENU_MAX:-}"
    local min="${IMENU_MIN:-}"
    local hint="${IMENU_HINT:-}"
    local format_func="${IMENU_FORMAT:-}"
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
        # Print blank line after message unless suppressed (for wizard mode)
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
    
    local selected=()
    local current=0
    
    # Initialize - nothing selected
    for ((i=0; i<num_options; i++)); do
        selected[i]=false
    done
    
    # Apply preselection if provided via IMENU_INITIAL
    if [ -n "${IMENU_INITIAL:-}" ]; then
        for idx in $IMENU_INITIAL; do
            if [ "$idx" -ge 0 ] && [ "$idx" -lt "$num_options" ]; then
                selected[$idx]=true
            fi
        done
    fi
    
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
            local marker="○"
            if [ "${selected[i]}" = true ]; then
                marker="●"
            fi
            
            local prefix="  "
            if [ $i -eq $current ]; then
                prefix="${CYAN}❯${NC} "
            fi
            
            printf '%b%s %s\n' "$prefix" "$marker" "${choices[i]}" >&2
        done
        printf '\n' >&2  # Blank line between options and keybindings
        
        # Display keybindings (redrawn each time)
        local keybindings
        keybindings=$(_imenu_get_keybindings "multiselect" "$has_back")
        if [ -n "$keybindings" ]; then
            printf '%b%s%b\n' "${GRAY}" "$keybindings" "${NC}" >&2
        fi
        
        # Display hint if provided
        if [ -n "$hint" ]; then
            printf '%b%s%b\n' "${DIM}" "$hint" "${NC}" >&2
        fi
        
        # Read input
        local key
        key=$(_imenu_read_char)
        
        if [ "$key" = $'\n' ] || [ "$key" = $'\r' ] || [ -z "$key" ]; then
            # Enter pressed, submit
            local count=0
            for ((i=0; i<num_options; i++)); do
                if [ "${selected[i]}" = true ]; then
                    ((count++))
                fi
            done
            
            if [ -n "$min" ] && [ $count -lt $min ]; then
                printf '%bPlease select at least %d option(s)%b\n' "${RED}" "$min" "${NC}" >&2
                sleep 1
                _imenu_clear_menu $menu_lines
                continue
            fi
            
            break
        fi
        
        case "$key" in
            " ")  # Space toggles selection
                selected[$current]=$([ "${selected[$current]}" = true ] && echo false || echo true)
                
                if [ -n "$max" ]; then
                    local count=0
                    for ((i=0; i<num_options; i++)); do
                        if [ "${selected[i]}" = true ]; then
                            ((count++))
                        fi
                    done
                    if [ $count -gt $max ]; then
                        selected[$current]=false
                        printf '%bMaximum %d option(s) allowed%b\n' "${RED}" "$max" "${NC}" >&2
                        sleep 1
                    fi
                fi
                ;;
            "a"|"A")  # Select all
                local all_selected=true
                for ((i=0; i<num_options; i++)); do
                    if [ "${selected[i]}" != true ]; then
                        all_selected=false
                        break
                    fi
                done
                if [ "$all_selected" = true ]; then
                    for ((i=0; i<num_options; i++)); do selected[i]=false; done
                else
                    for ((i=0; i<num_options; i++)); do selected[i]=true; done
                    if [ -n "$max" ] && [ $num_options -gt $max ]; then
                        for ((i=$max; i<num_options; i++)); do selected[i]=false; done
                    fi
                fi
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
    if [ -n "$preselect_indices" ]; then
        unset IMENU_INITIAL
    fi
    
    # Store ONLY menu lines (not message lines) for next step clearing
    # Messages persist across steps, so we should only clear the menu part
    # Include blank line before options if it was printed
    if [ "$blank_before_options" = true ]; then
        IMENU_LAST_LINES=$((menu_lines + 1))
    else
        IMENU_LAST_LINES=$menu_lines
    fi
    
    # Collect selected values
    local selected_values=()
    local selected_indices=()
    for ((i=0; i<num_options; i++)); do
        if [ "${selected[i]}" = true ]; then
            selected_values+=("${choices[i]}")
            selected_indices+=("$i")
        fi
    done
    
    # Format
    local formatted_value="${selected_values[*]}"
    if [ -n "$format_func" ] && _imenu_is_function "$format_func"; then
        formatted_value=$("$format_func" "${selected_values[@]}")
    fi
    
    # Store response
    _IMENU_RESPONSES_MAP["$name"]="$formatted_value"
    
    # Output selected indices (space-separated) to stdout
    local result="${selected_indices[*]}"
    result="${result// / }"
    echo "$result"
    
    return 0
}

