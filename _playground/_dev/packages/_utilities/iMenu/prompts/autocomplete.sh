#!/usr/bin/env bash
# iMenu Prompt: autocomplete
# Searchable autocomplete prompt

imenu_autocomplete() {
    local name="$1"
    local message="$2"
    shift 2
    local choices=("$@")
    
    # Parse flags from choices array (--preselect, --message, --limit)
    local preselect_idx=""
    local limit=10
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
        elif [ "${choices[i]}" = "--limit" ]; then
            limit="${choices[i+1]}"
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
    local initial="${IMENU_INITIAL:-}"
    if [ -n "$preselect_idx" ]; then
        initial="${choices[$preselect_idx]}"
    fi
    
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
        # Always print blank line for selection prompts (gap before options)
        printf '\n' >&2
    fi
    
    local num_options=${#choices[@]}
    if [ $num_options -eq 0 ]; then
        printf '%bNo choices provided%b\n' "${RED}" "${NC}" >&2
        return 1
    fi
    
    local input="$initial"
    local current=0
    local filtered=()
    
    _imenu_hide_cursor
    
    # Calculate message lines for total count
    local message_lines=0
    if [ -n "$message" ]; then
        message_lines=$(echo -n "$message" | grep -c '^' || echo "1")
        if [ "$message_lines" -eq 0 ]; then
            message_lines=1
        fi
    fi
    
    # Calculate menu lines displayed in loop
    local menu_lines=$((limit + 3))  # Filtered options + prompt + blank + keybindings
    
    # Total lines = message + menu
    local total_lines=$((message_lines + menu_lines))
    
    while true; do
        # Filter choices based on input
        filtered=()
        if [ -z "$input" ]; then
            filtered=("${choices[@]}")
        else
            for choice in "${choices[@]}"; do
                if [[ "$choice" =~ ^"$input" ]] || [[ "$choice" =~ "$input" ]]; then
                    filtered+=("$choice")
                fi
            done
        fi
        
        # Limit results
        if [ ${#filtered[@]} -gt $limit ]; then
            filtered=("${filtered[@]:0:$limit}")
        fi
        
        local num_filtered=${#filtered[@]}
        if [ $num_filtered -gt 0 ]; then
            if [ $current -ge $num_filtered ]; then
                current=$((num_filtered - 1))
            fi
        fi
        
        # Display prompt and input
        printf '%b?%b %s\n' "${CYAN}" "${NC}" "$input" >&2
        
        # Display filtered choices
        if [ $num_filtered -gt 0 ]; then
            for ((i=0; i<num_filtered; i++)); do
                local prefix="  "
                if [ $i -eq $current ]; then
                    prefix="${CYAN}❯${NC} "
                fi
                printf '%b%s\n' "$prefix" "${filtered[i]}" >&2
            done
        else
            printf '  %bNo matches found%b\n' "${DIM}" "${NC}" >&2
        fi
        printf '\n' >&2
        
        # Display keybindings
        local keybindings
        keybindings=$(_imenu_get_keybindings "autocomplete" "$has_back")
        if [ -n "$keybindings" ]; then
            printf '%b%s%b\n' "${GRAY}" "$keybindings" "${NC}" >&2
        fi
        
        # Read input
        local key
        key=$(_imenu_read_char)
        
        if [ "$key" = $'\n' ] || [ "$key" = $'\r' ] || [ -z "$key" ]; then
            # Enter pressed, select current or submit input
            if [ $num_filtered -gt 0 ]; then
                input="${filtered[$current]}"
            fi
            break
        fi
        
        case "$key" in
            $'\x7f'|$'\b')  # Backspace
                if [ ${#input} -gt 0 ]; then
                    input="${input:0:$((${#input}-1))}"
                fi
                current=0
                ;;
            $'\x1b')  # Escape sequence
                local arrow
                arrow=$(_imenu_read_escape)
                case "$arrow" in
                    "A")  # Up arrow
                        if [ $num_filtered -gt 0 ]; then
                            current=$(((current - 1 + num_filtered) % num_filtered))
                        fi
                        ;;
                    "B")  # Down arrow
                        if [ $num_filtered -gt 0 ]; then
                            current=$(((current + 1) % num_filtered))
                        fi
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
            "b"|"B")  # Back
                if [ "$has_back" = "true" ]; then
                    _imenu_show_cursor
                    _imenu_clear_menu $menu_lines
                    return 2
                fi
                ;;
            *)
                # Regular character - add to input
                input="${input}${key}"
                current=0
                ;;
        esac
        
        _imenu_clear_menu $menu_lines
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

