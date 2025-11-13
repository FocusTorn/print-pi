#!/usr/bin/env bash
# iWizard - Multi-step wizard system for iMenu
# Handles dynamic message accumulation and step transitions using cumulative math
# Uses iPrompt internally for consistent prompt handling

# Usage:
#   local step1=("multiselect" "ℹ️  Which services?" "Option 1" "Option 2")
#   local step2=("select" "ℹ️  Which installation?" "Option A" "Option B")
#   iwizard_run "Wizard Title" step1 step2
#
#   Or with JSON:
#   iwizard_run_json "/path/to/wizard.json"
#
# Debug mode:
#   export IMENU_WIZARD_DEBUG=true
#   iwizard_run_json "/path/to/wizard.json"
#   (Pauses after each step clear for debugging)

# Global debug flag (can be set via environment variable)
# Note: This is set at module load time. For runtime changes, the debug check
# reads directly from the environment using printenv
IMENU_WIZARD_DEBUG="${IMENU_WIZARD_DEBUG:-false}"

# Print standard wizard header (lines 1-5)
# Arguments: title
_iwizard_print_header() {
    local title="$1"
    printf '\n' >&2
    printf '%b════════════════════════════════════════%b\n' "${CYAN}" "${NC}" >&2
    printf '%b  %s%b\n' "${CYAN}" "$title" "${NC}" >&2
    printf '%b════════════════════════════════════════%b\n' "${CYAN}" "${NC}" >&2
    printf '\n' >&2
}

# Clear a specified number of lines (moves cursor up and clears)
# Arguments: line_count
_iwizard_clear_lines() {
    local line_count=$1
    if [ "$line_count" -gt 0 ]; then
        _imenu_clear_menu $line_count
    fi
}

# Clear everything from line 6 down (after the banner)
# The banner is always at lines 1-5 and never changes
# After clearing, cursor is always at line 6, ready to draw content
_iwizard_clear_content() {
    # Move cursor to line 6, column 0
    # Line 6 is where content starts (after banner: blank, separator, title, separator, blank)
    printf '\033[6;1H' >&2 2>/dev/null || tput cup 6 0 >&2 2>/dev/null || true
    # Clear from cursor to end of screen (ED - Erase Display)
    # \033[J clears from cursor to end of screen
    # \033[0J is more explicit (clear from cursor to end)
    printf '\033[0J' >&2 2>/dev/null || printf '\033[J' >&2 2>/dev/null || tput ed >&2 2>/dev/null || true
    # Also clear the current line to be sure
    printf '\033[K' >&2 2>/dev/null || tput el >&2 2>/dev/null || true
    # Ensure cursor is at start of line 6
    printf '\033[6;1H' >&2 2>/dev/null || tput cup 6 0 >&2 2>/dev/null || true
    printf '\r' >&2
}

# Draw the submitted section (all completed steps, dimmed)
# Arguments: accumulated_messages accumulated_results accumulated_step_types
_iwizard_draw_submitted() {
    local -n messages_ref=$1
    local -n results_ref=$2
    local -n types_ref=$3
    
    # Draw all completed steps as dimmed (no gaps between steps)
    local i
    for ((i=0; i<${#messages_ref[@]}; i++)); do
        if [ -n "${messages_ref[$i]:-}" ]; then
            local step_msg="${messages_ref[$i]}"
            local step_result="${results_ref[$i]:-}"
            local step_type="${types_ref[$i]:-text}"
            
            if [ "$step_type" = "confirm" ] || [ "$step_type" = "text" ] || [ "$step_type" = "number" ] || [ "$step_type" = "list" ]; then
                # For confirm/text/number/list, show message and answer inline, both dimmed
                printf '%b%s%s%b\n' "${DIM}" "$step_msg" "$step_result" "${NC}" >&2
            elif [ "$step_type" = "multiselect" ] || [ "$step_type" = "select" ]; then
                # For multiselect/select, show message dimmed, then result on separate lines (indented)
                # Result already has dimming codes and starts with newline + indentation
                # Print message without newline, then result (ensure it ends with newline)
                printf '%b%s%b' "${DIM}" "$step_msg" "${NC}" >&2
                if [ -n "$step_result" ]; then
                    printf '%b' "$step_result" >&2  # Use %b to interpret ANSI codes
                fi
            else
                # For other types, show message dimmed, result on next line if it has newline
                printf '%b%s%b\n' "${DIM}" "$step_msg" "${NC}" >&2
                if [ -n "$step_result" ]; then
                    printf '%s\n' "$step_result" >&2
                fi
            fi
            # No blank line between steps - they should be butted up
        fi
    done
    # Add a single blank line after all submitted steps (before active prompt)
    if [ ${#messages_ref[@]} -gt 0 ]; then
        printf '\n' >&2
    fi
}

# Draw the active prompt section (current step being displayed)
# This is handled by the prompt itself, but we can prepare the space
_iwizard_prepare_active_prompt() {
    # The prompt will draw itself, we just ensure cursor is positioned correctly
    # Cursor should be at the start of the line where the prompt will appear
    printf '\r' >&2
}

# Run a wizard with multiple steps
# Arguments: title step1 step2 step3 ...
iwizard_run() {
    local title="$1"
    shift
    local step_refs=("$@")
    
    # Print header once at the start (lines 1-5)
    _iwizard_print_header "$title"
    
    # Set flag to skip header printing in prompt calls
    export IMENU_TITLE=""
    
    # Accumulated messages and results for dynamic display
    local accumulated_messages=()
    local accumulated_results=()  # Store formatted results for each step
    local accumulated_step_types=()  # Store step types for each step
    local accumulated_step_line_counts=()  # Store total line counts (message + menu) for each step
    
    local step_idx=0
    while [ $step_idx -lt ${#step_refs[@]} ]; do
        local step_ref="${step_refs[$step_idx]}"
        
        # Get the step array (indirect reference)
        # First check if the variable exists
        local step_array
        if ! declare -p "$step_ref" &>/dev/null; then
            echo "Error: Step variable '$step_ref' (index $step_idx) is not defined" >&2
            return 1
        fi
        
        # Safely get the array contents
        eval "step_array=(\"\${${step_ref}[@]}\")"
        
        # Validate array is not empty
        if [ ${#step_array[@]} -eq 0 ]; then
            echo "Error: Step '$step_ref' (index $step_idx) is empty" >&2
            return 1
        fi
        
        # Step format: [type] [message] [options...] [--preselect "idx"]
        local step_type="${step_array[0]}"
        local step_message="${step_array[1]}"
        
        # Validate step type is not empty
        if [ -z "$step_type" ]; then
            echo "Error: Step '$step_ref' (index $step_idx) has an empty prompt type" >&2
            return 1
        fi
        
        # Previous steps are already displayed on screen (redrawn dimmed after each step completes)
        # No need to redraw them here - just show the next prompt
        
        # Check if this is a substep (has back button)
        local has_back="false"
        if [ $step_idx -gt 0 ]; then
            has_back="true"
        fi
        
        # Set environment for iMenu
        export IMENU_HAS_BACK="$has_back"
        # We handle all clearing ourselves (submitted section is already drawn, cursor is positioned)
        # The prompt should not clear anything - we've already done all the clearing and positioning
        export IMENU_CLEAR_PREVIOUS=0
        # Apply wizard preset: messages butted up, no gap by default
        imenu_config_preset "wizard"
        
        # Keep cursor visible before starting next prompt (for debugging)
        _imenu_show_cursor
        
        # Debug mode: pause before drawing active prompt
        # Read directly from environment
        local debug_val="false"
        if printenv IMENU_WIZARD_DEBUG >/dev/null 2>&1; then
            debug_val=$(printenv IMENU_WIZARD_DEBUG)
        elif [ -n "${IMENU_WIZARD_DEBUG:-}" ]; then
            debug_val="$IMENU_WIZARD_DEBUG"
        fi
        local debug_enabled=false
        case "$debug_val" in
            [Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]|1|[Oo][Nn])
                debug_enabled=true
                ;;
        esac
        
        # Debug pause: happens right before active prompt is drawn
        if [ "$debug_enabled" = "true" ]; then
            # Read a single character (wait for any key)
            local saved_stty
            saved_stty=$(stty -g 2>/dev/null || echo "")
            stty -echo -icanon -isig min 1 time 0 2>/dev/null || stty -echo -icanon -isig 2>/dev/null || true
            local key=""
            if [ -t 0 ] && [ -r /dev/tty ]; then
                read -rsn1 key < /dev/tty 2>/dev/null
            else
                read -rsn1 key 2>/dev/null || read -n 1 -s key
            fi
            [ -n "$saved_stty" ] && stty "$saved_stty" 2>/dev/null || true
        fi
        
        # Use iPrompt to handle the prompt
        local result=""
        local exit_code=0
        
        result=$(iprompt_run "step$step_idx" "${step_array[@]}")
        exit_code=$?
        
        # Handle exit codes
        if [ $exit_code -eq 1 ]; then
            # Cancel
            return 1
        elif [ $exit_code -eq 2 ]; then
            # Back - go to previous step
            if [ $step_idx -gt 0 ]; then
                # Remove last message from accumulation
                unset 'accumulated_messages[-1]'
                unset 'accumulated_results[-1]'
                unset 'accumulated_step_types[-1]'
                unset 'accumulated_step_line_counts[-1]'
                step_idx=$((step_idx - 1))  # Go back to previous step
                continue
            else
                return 1
            fi
        fi
        
        # Get menu lines used by this prompt (set by the prompt)
        local menu_lines="${IMENU_LAST_LINES:-0}"
        # Total lines for this step: message (1) + menu lines
        local step_total_lines=$((1 + menu_lines))
        
        # Format result for display in subsequent steps
        local formatted_result=""
        local step_options_str=""
        local step_default=""
        
        if [ "$step_type" = "multiselect" ] || [ "$step_type" = "select" ]; then
            # Extract options (skip type and message)
            local step_opts=("${step_array[@]:2}")
            # Filter out flags like --preselect
            local clean_opts=()
            local i
            for ((i=0; i<${#step_opts[@]}; i++)); do
                if [ "${step_opts[i]}" = "--preselect" ] || [ "${step_opts[i]}" = "--message" ]; then
                    ((i++))  # Skip flag and its value
                    continue
                fi
                clean_opts+=("${step_opts[i]}")
            done
            # Join options with a delimiter that won't appear in option text
            local IFS=$'\x1F'  # Use unit separator character
            step_options_str="${clean_opts[*]}"
            
            # Format selected options with bullets (dimmed for display in subsequent steps)
            if [ "$step_type" = "multiselect" ]; then
                # Parse result (space-separated indices)
                read -ra selected_indices <<< "$result"
                # Parse options
                IFS=$'\x1F' read -ra options_array <<< "$step_options_str"
                # Build formatted result (store as string with dimmed color codes, each selection on separate line)
                local first=true
                for idx in "${selected_indices[@]}"; do
                    if [ -n "$idx" ] && [ "$idx" -ge 0 ] && [ "$idx" -lt ${#options_array[@]} ]; then
                        if [ "$first" = true ]; then
                            formatted_result=$'\n    '"${DIM}●${NC}${DIM} ${options_array[$idx]}${NC}"
                            first=false
                        else
                            formatted_result="$formatted_result"$'\n    '"${DIM}●${NC}${DIM} ${options_array[$idx]}${NC}"
                        fi
                    fi
                done
                # Ensure result ends with newline so function can add blank line after all steps
                if [ -n "$formatted_result" ] && [[ ! "$formatted_result" =~ $'\n'$ ]]; then
                    formatted_result="$formatted_result"$'\n'
                fi
            elif [ "$step_type" = "select" ]; then
                # Parse result (single index)
                selected_idx="$result"
                # Parse options
                IFS=$'\x1F' read -ra options_array <<< "$step_options_str"
                # Build formatted result (dimmed, on separate line)
                if [ -n "$selected_idx" ] && [ "$selected_idx" -ge 0 ] && [ "$selected_idx" -lt ${#options_array[@]} ]; then
                    formatted_result=$'\n    '"${DIM}●${NC}${DIM} ${options_array[$selected_idx]}${NC}"$'\n'
                fi
            fi
        elif [ "$step_type" = "confirm" ]; then
            # Extract default value (3rd argument, or "false" if not provided)
            if [ ${#step_array[@]} -ge 3 ] && [ -n "${step_array[2]}" ]; then
                step_default="${step_array[2]}"
            else
                step_default="false"
            fi
            
            # Format result as "Yes" or "No" (inline, will be dimmed when displayed)
            if [ "$result" = "true" ]; then
                formatted_result=" Yes"
            else
                formatted_result=" No"
            fi
        elif [ "$step_type" = "text" ] || [ "$step_type" = "number" ] || [ "$step_type" = "list" ]; then
            # Format result inline (with space prefix, will be dimmed when displayed)
            formatted_result=" $result"
        fi
        
        # Store message, formatted result, step type, and total line count for next step
        accumulated_messages+=("$step_message")
        accumulated_results+=("$formatted_result")
        accumulated_step_types+=("$step_type")
        accumulated_step_line_counts+=("$step_total_lines")
        
        # Output to step info file if set (for demo to capture)
        if [ -n "${IMENU_STEP_INFO_FILE:-}" ]; then
            printf "IMENU_STEP_INFO:%d:%s:%s:%s:%s|%s\n" "$step_idx" "$step_type" "$step_message" "$step_options_str" "$step_default" "$result" >> "$IMENU_STEP_INFO_FILE"
        fi
        
        # If not the last step, clear everything from line 6 down and redraw submitted section + prepare for active prompt
        if [ $step_idx -lt $((${#step_refs[@]} - 1)) ]; then
            # Clear everything from line 6 down (banner at lines 1-5 never changes)
            # Cursor will always be at line 6 after clearing, ready to draw content
            _iwizard_clear_content
            
            # After clearing, cursor should be at the correct position
            # Ensure cursor is visible and at start of line
            _imenu_show_cursor
            printf '\r' >&2
            
            # All cursor movements are complete - cursor is now positioned for drawing
            # Debug mode: pause right before any drawing occurs
            # Read directly from environment (not the module-level variable which was set at load time)
            # Check both exported environment variable and shell variable
            local debug_val="false"
            # First try printenv (for exported variables)
            if printenv IMENU_WIZARD_DEBUG >/dev/null 2>&1; then
                debug_val=$(printenv IMENU_WIZARD_DEBUG)
            # Then check if it's set as a shell variable (even if not exported)
            elif [ -n "${IMENU_WIZARD_DEBUG:-}" ]; then
                debug_val="$IMENU_WIZARD_DEBUG"
            fi
            local debug_enabled=false
            
            # Check if debug is enabled (case-insensitive)
            case "$debug_val" in
                [Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]|1|[Oo][Nn])
                    debug_enabled=true
                    ;;
            esac
            
            # Debug pause: happens after all cursor movements, right before any drawing
            # This allows inspection of cursor position exactly where drawing will occur
            if [ "$debug_enabled" = "true" ]; then
                # Read a single character (wait for any key)
                # Save terminal settings and set to raw mode
                local saved_stty
                saved_stty=$(stty -g 2>/dev/null || echo "")
                # Set terminal to raw mode for single character input
                stty -echo -icanon -isig min 1 time 0 2>/dev/null || stty -echo -icanon -isig 2>/dev/null || true
                # Read from /dev/tty to ensure we read from the terminal
                local key=""
                # Try reading from /dev/tty first, fallback to stdin
                if [ -t 0 ] && [ -r /dev/tty ]; then
                    read -rsn1 key < /dev/tty 2>/dev/null
                else
                    read -rsn1 key 2>/dev/null || read -n 1 -s key
                fi
                # Restore terminal settings
                [ -n "$saved_stty" ] && stty "$saved_stty" 2>/dev/null || true
            fi
            
            # DRAW 1: Draw the submitted section (all completed steps, dimmed)
            # This draws all accumulated completed steps
            _iwizard_draw_submitted accumulated_messages accumulated_results accumulated_step_types
            
            # Calculate total lines used by submitted section for next step clearing
            # Each submitted step = 1 line (message+result) + selection lines for select/multiselect
            local submitted_lines=${#accumulated_messages[@]}
            # Count selection lines from all select/multiselect steps
            local i
            for ((i=0; i<${#accumulated_step_types[@]}; i++)); do
                local prev_step_type="${accumulated_step_types[$i]:-}"
                if [ "$prev_step_type" = "select" ]; then
                    # Select adds 1 selection line
                    submitted_lines=$((submitted_lines + 1))
                elif [ "$prev_step_type" = "multiselect" ]; then
                    # Multiselect adds N selection lines (count newlines in result)
                    local prev_result="${accumulated_results[$i]:-}"
                    if [ -n "$prev_result" ]; then
                        # Count newlines in the result (each selection is on its own line)
                        local newline_count=$(echo -n "$prev_result" | grep -o $'\n' | wc -l)
                        submitted_lines=$((submitted_lines + newline_count))
                    fi
                fi
            done
            # Add 1 for the blank line after all submitted steps
            submitted_lines=$((submitted_lines + 1))
            IMENU_LAST_LINES=$submitted_lines
            
            # DRAW 2: Prepare for active prompt (next step will draw itself)
            _iwizard_prepare_active_prompt
            
            # Keep cursor visible
            _imenu_show_cursor
            
            # Not last step, continue
            # IMENU_LAST_LINES is already set above to include the trailing blank line
            unset IMENU_CLEAR_PREVIOUS
            ((step_idx++))
        else
            # Last step - clear everything from line 6 down and redraw all submitted steps (including last one)
            # Clear everything from line 6 down (banner at lines 1-5 never changes)
            # Cursor will always be at line 6 after clearing, ready to draw content
            _iwizard_clear_content
            
            # After clearing, cursor should be at the correct position
            # Ensure cursor is visible and at start of line
            _imenu_show_cursor
            printf '\r' >&2
            
            # Debug mode: pause right before any drawing occurs
            local debug_val="false"
            if printenv IMENU_WIZARD_DEBUG >/dev/null 2>&1; then
                debug_val=$(printenv IMENU_WIZARD_DEBUG)
            elif [ -n "${IMENU_WIZARD_DEBUG:-}" ]; then
                debug_val="$IMENU_WIZARD_DEBUG"
            fi
            local debug_enabled=false
            case "$debug_val" in
                [Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]|1|[Oo][Nn])
                    debug_enabled=true
                    ;;
            esac
            
            # Debug pause: happens after all cursor movements, right before any drawing
            if [ "$debug_enabled" = "true" ]; then
                # Read a single character (wait for any key)
                local saved_stty
                saved_stty=$(stty -g 2>/dev/null || echo "")
                stty -echo -icanon -isig min 1 time 0 2>/dev/null || stty -echo -icanon -isig 2>/dev/null || true
                local key=""
                if [ -t 0 ] && [ -r /dev/tty ]; then
                    read -rsn1 key < /dev/tty 2>/dev/null
                else
                    read -rsn1 key 2>/dev/null || read -n 1 -s key
                fi
                [ -n "$saved_stty" ] && stty "$saved_stty" 2>/dev/null || true
            fi
            
            # Draw all submitted steps (including the last one, no blank line after since it's the end)
            # For the last step, we don't want the trailing blank line
            local i
            for ((i=0; i<${#accumulated_messages[@]}; i++)); do
                if [ -n "${accumulated_messages[$i]:-}" ]; then
                    local step_msg="${accumulated_messages[$i]}"
                    local step_result="${accumulated_results[$i]:-}"
                    local step_type="${accumulated_step_types[$i]:-text}"
                    
                    if [ "$step_type" = "confirm" ] || [ "$step_type" = "text" ] || [ "$step_type" = "number" ] || [ "$step_type" = "list" ]; then
                        # For confirm/text/number/list, show message and answer inline, both dimmed
                        printf '%b%s%s%b\n' "${DIM}" "$step_msg" "$step_result" "${NC}" >&2
                    elif [ "$step_type" = "multiselect" ] || [ "$step_type" = "select" ]; then
                        # For multiselect/select, show message dimmed, then result on separate lines (indented)
                        # Result already has dimming codes and starts with newline + indentation
                        # Print message without newline, then result (which has its own newline)
                        printf '%b%s%b' "${DIM}" "$step_msg" "${NC}" >&2
                        if [ -n "$step_result" ]; then
                            printf '%b' "$step_result" >&2  # Use %b to interpret ANSI codes (includes newline)
                        fi
                    else
                        # For other types, show message dimmed, result on next line if it has newline
                        printf '%b%s%b\n' "${DIM}" "$step_msg" "${NC}" >&2
                        if [ -n "$step_result" ]; then
                            printf '%b\n' "$step_result" >&2  # Use %b to interpret ANSI codes
                        fi
                    fi
                    # No blank line between steps - they should be butted up
                fi
            done
            # No trailing blank line for last step (it's the end)
            
            # Output all results
            # Output all responses from the map (sorted by key for consistent output)
            local saved_setu
            saved_setu="${-//[^u]/}"  # Save current 'set -u' state
            set +u  # Temporarily disable nounset for safe array access
            
            # Output all responses in the map (sorted by key for consistent output)
            local keys
            keys=($(printf '%s\n' "${!_IMENU_RESPONSES_MAP[@]}" | sort))
            local key
            for key in "${keys[@]}"; do
                if [ -n "$key" ]; then
                    echo "step_response:$key=${_IMENU_RESPONSES_MAP[$key]}"
                fi
            done
            
            # Restore original 'set -u' state if it was set
            [ -n "$saved_setu" ] && set -u || true
            
            # Output final result on last line
            echo "$result"
            return 0
        fi
    done
}

# Parse JSON file and run wizard
# Arguments: json_file_path
iwizard_run_json() {
    local json_file="$1"
    
    if [ -z "$json_file" ]; then
        echo "Error: JSON file path required" >&2
        return 1
    fi
    
    if [ ! -f "$json_file" ]; then
        echo "Error: JSON file not found: $json_file" >&2
        return 1
    fi
    
    if ! command -v jq &>/dev/null; then
        echo "Error: jq is required for JSON parsing. Install with: apt install jq" >&2
        return 1
    fi
    
    local temp_json=$(mktemp)
    sed 's|//.*||' "$json_file" | jq -c '.' > "$temp_json" 2>/dev/null || {
        echo "Error: Failed to parse JSON file (may contain invalid comments)" >&2
        rm -f "$temp_json"
        return 1
    }
    
    local title=$(jq -r '.title' "$temp_json")
    if [ "$title" = "null" ] || [ -z "$title" ]; then
        echo "Error: JSON file missing 'title' field" >&2
        rm -f "$temp_json"
        return 1
    fi
    
    local step_count=$(jq '.steps | length' "$temp_json")
    if [ "$step_count" -eq 0 ]; then
        echo "Error: JSON file has no steps" >&2
        rm -f "$temp_json"
        return 1
    fi
    
    local step_refs=()
    
    local i
    for ((i=0; i<step_count; i++)); do
        local step_type=$(jq -r ".steps[$i].type" "$temp_json")
        local step_message=$(jq -r ".steps[$i].message" "$temp_json")
        
        if [ "$step_type" = "null" ] || [ -z "$step_type" ]; then
            echo "Error: Step $i missing 'type' field" >&2
            rm -f "$temp_json"
            return 1
        fi
        
        local step_array=("$step_type" "$step_message")
        
        if [ "$step_type" = "confirm" ]; then
            local initial=$(jq -r ".steps[$i].initial // false" "$temp_json")
            if [ "$initial" != "null" ] && [ "$initial" != "false" ]; then
                step_array+=("--initial" "$initial")
            fi
        elif [ "$step_type" = "text" ] || [ "$step_type" = "number" ]; then
            local initial=$(jq -r ".steps[$i].initial // empty" "$temp_json")
            if [ "$initial" != "null" ] && [ -n "$initial" ]; then
                step_array+=("--initial" "$initial")
            fi
            if [ "$step_type" = "number" ]; then
                local min=$(jq -r ".steps[$i].min // empty" "$temp_json")
                local max=$(jq -r ".steps[$i].max // empty" "$temp_json")
                if [ "$min" != "null" ] && [ -n "$min" ]; then
                    step_array+=("--min" "$min")
                fi
                if [ "$max" != "null" ] && [ -n "$max" ]; then
                    step_array+=("--max" "$max")
                fi
            fi
        elif [ "$step_type" = "select" ] || [ "$step_type" = "multiselect" ]; then
            local options_count=$(jq ".steps[$i].options | length" "$temp_json")
            if [ "$options_count" -eq 0 ]; then
                echo "Error: Step $i (type: $step_type) missing 'options' array" >&2
                rm -f "$temp_json"
                return 1
            fi
            local j
            for ((j=0; j<options_count; j++)); do
                local option=$(jq -r ".steps[$i].options[$j]" "$temp_json")
                step_array+=("$option")
            done
            if [ "$step_type" = "multiselect" ]; then
                local preselect_count=$(jq ".steps[$i].preselect // [] | length" "$temp_json")
                if [ "$preselect_count" -gt 0 ]; then
                    step_array+=("--preselect")
                    local preselect_indices=""
                    local k
                    for ((k=0; k<preselect_count; k++)); do
                        local idx=$(jq -r ".steps[$i].preselect[$k]" "$temp_json")
                        if [ "$k" -eq 0 ]; then
                            preselect_indices="$idx"
                        else
                            preselect_indices="$preselect_indices $idx"
                        fi
                    done
                    step_array+=("$preselect_indices")
                fi
            fi
        elif [ "$step_type" = "toggle" ]; then
            local initial=$(jq -r ".steps[$i].initial // false" "$temp_json")
            if [ "$initial" != "null" ] && [ "$initial" != "false" ]; then
                step_array+=("$initial")
            fi
        fi
        
        local step_name="step$i"
        eval "$step_name=(\"\${step_array[@]}\")"
        step_refs+=("$step_name")
    done
    
    rm -f "$temp_json"
    
    iwizard_run "$title" "${step_refs[@]}"
}

