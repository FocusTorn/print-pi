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

_prompt_multiselect() {
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
    local has_back="${IMENU_HAS_BACK:-false}"
    
    # Display message if provided
    if [ -n "$message" ]; then
        local message_prefix="${IMENU_MESSAGE_PREFIX:-}"
        if [ -n "$message_prefix" ]; then
            printf '%b%s %s%b\n' "${BLUE}" "$message_prefix" "$message" "${NC}" >&2
        else
            printf '%b%s%b\n' "${BLUE}" "$message" "${NC}" >&2
        fi
        # Single blank line after message (separates message from choices)
        printf '\n' >&2
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
        # Split IMENU_INITIAL by whitespace and process each index
        # Use read to properly split the string into an array
        local preselect_array=()
        IFS=' ' read -ra preselect_array <<< "$IMENU_INITIAL" || true
        for idx in "${preselect_array[@]}"; do
            # Validate idx is a number before comparing
            if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -ge 0 ] && [ "$idx" -lt "$num_options" ]; then
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
        message_lines=$((message_lines + 1))  # +1 for single blank line after message
    fi
    
    # Calculate menu lines displayed in loop
    local menu_lines=$((num_options + 2))  # Options + blank + keybindings line
    if [ -n "$hint" ]; then
        menu_lines=$((menu_lines + 1))  # Hint line
    fi
    
    # Total lines = message + menu (for clearing when transitioning steps)
    local total_lines=$((message_lines + menu_lines))
    
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
        
        # Mark that we've drawn at least once
        # Don't save cursor - we'll clear from current position next iteration
        first_iteration=false
        
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
    # (No action needed - iWizard handles all clearing)
    
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

