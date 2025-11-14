#!/usr/bin/env bash
# iWizard Core - Orchestrator
# Handles JSON parsing, comment stripping, and main step orchestration loop

# Strip comments from JSON (file or string)
# Arguments: json_file_path OR json_string
# Returns: path to cleaned temp file
_wizard_strip_json_comments() {
    local json_input="$1"
    local temp_file
    temp_file=$(mktemp)
    
    # Determine if input is a file path or JSON string
    local is_file=false
    local input_file=""
    if [ -f "$json_input" ] 2>/dev/null; then
        is_file=true
        input_file="$json_input"
    else
        # For string input, write to temp file first to ensure proper handling
        is_file=false
        input_file=$(mktemp)
        printf '%s' "$json_input" > "$input_file"
    fi
    
    # Read input line by line and strip comments
    # Remove // single-line comments (but not in strings)
    # Remove /* */ multi-line comments (but not in strings)
    # This is a simplified approach - assumes comments are outside strings
    local in_string=false
    local in_multiline_comment=false
    local multiline_buffer=""
    
    while IFS= read -r line || [ -n "$line" ]; do
        local output_line=""
        local i=0
        local len=${#line}
        
        while [ $i -lt $len ]; do
            local char="${line:$i:1}"
            local next_char=""
            [ $((i+1)) -lt $len ] && next_char="${line:$((i+1)):1}"
            
            if [ "$in_multiline_comment" = true ]; then
                # Inside multi-line comment, look for */
                if [ "$char" = "*" ] && [ "$next_char" = "/" ]; then
                    in_multiline_comment=false
                    i=$((i+2))
                    continue
                fi
                i=$((i+1))
                continue
            fi
            
            if [ "$char" = '"' ]; then
                # Toggle string state
                in_string=$([ "$in_string" = true ] && echo false || echo true)
                output_line="$output_line$char"
                i=$((i+1))
            elif [ "$in_string" = false ]; then
                # Outside string, check for comments
                if [ "$char" = "/" ] && [ "$next_char" = "/" ]; then
                    # Single-line comment - skip rest of line
                    break
                elif [ "$char" = "/" ] && [ "$next_char" = "*" ]; then
                    # Start of multi-line comment
                    in_multiline_comment=true
                    i=$((i+2))
                    continue
                else
                    output_line="$output_line$char"
                    i=$((i+1))
                fi
            else
                # Inside string, keep character
                output_line="$output_line$char"
                i=$((i+1))
            fi
        done
        
        # Only output line if not entirely in multi-line comment or has content
        if [ "$in_multiline_comment" = false ] && [ -n "$output_line" ]; then
            echo "$output_line" >> "$temp_file"
        fi
    done < "$input_file"
    
    # Clean up temp input file if we created it for string input
    if [ "$is_file" = false ]; then
        rm -f "$input_file" 2>/dev/null || true
    fi
    
    echo "$temp_file"
}

# Main entry point for JSON-based wizard
# Arguments: json_file_path OR json_string
# If argument is a file path (exists as file), reads from file
# Otherwise, treats argument as JSON string content
iwizard_run_json() {
    local json_input="$1"
    
    # Validate jq is installed
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required for JSON parsing but is not installed." >&2
        echo "Please install jq: sudo apt-get install jq" >&2
        return 1
    fi
    
    # Determine if input is a file path or JSON string
    local is_file=false
    local json_source=""
    if [ -f "$json_input" ] 2>/dev/null; then
        is_file=true
        json_source="$json_input"
    else
        # Treat as JSON string
        is_file=false
        json_source="-"
    fi
    
    # Set up cleanup function early (before entering alternate screen)
    # This ensures Ctrl+C works even if called before orchestrator
    # Make it a global function so it's accessible from anywhere
    declare -g _WIZARD_CLEANED_JSON_PATH=""  # Global variable for cleanup function
    
    _wizard_cleanup_early() {
        local show_message="${1:-false}"  # Optional: show cancellation message
        _imenu_show_cursor
        _imenu_exit_alternate_screen
        # Show cancellation message in original buffer if requested
        if [ "$show_message" = "true" ]; then
            printf '\n%b⚠️  Wizard cancelled%b\n' "${YELLOW}" "${NC}" >&2
        fi
        # Clean up temp cleaned JSON file if it exists (NOT the original file if it was a file!)
        [ -n "$_WIZARD_CLEANED_JSON_PATH" ] && [ -f "$_WIZARD_CLEANED_JSON_PATH" ] && rm -f "$_WIZARD_CLEANED_JSON_PATH" 2>/dev/null || true
    }
    declare -g -f _wizard_cleanup_early >/dev/null 2>&1 || true  # Make function global (suppress output)
    
    # Validate input BEFORE entering alternate screen
    if [ "$is_file" = true ]; then
        # File mode: validate file exists
        if [ ! -f "$json_input" ]; then
            echo "Error: JSON file not found: $json_input" >&2
            return 1
        fi
    else
        # String mode: validate it looks like JSON (starts with { or [)
        if [[ ! "$json_input" =~ ^[[:space:]]*[\{\[] ]]; then
            echo "Error: JSON string must start with '{' or '['" >&2
            return 1
        fi
    fi
    
    # Trap signals early to ensure cleanup happens
    # Use EXIT trap as well to catch any exit (including from child processes)
    # For INT (Ctrl+C), show cancellation message
    # Note: exit in command substitution exits the subshell with that code
    trap '_wizard_cleanup_early true; exit 130' INT    # Ctrl+C
    trap '_wizard_cleanup_early false; exit 143' TERM  # SIGTERM
    trap '_wizard_cleanup_early false' EXIT            # Any exit (will be overridden in orchestrator)
    
    # Enter alternate screen buffer (prevents affecting scrollback)
    _imenu_enter_alternate_screen
    
    # Clear screen immediately to ensure we start at line 1
    _imenu_clear_screen
    
    # Strip comments from JSON (works with both files and strings)
    local cleaned_json
    cleaned_json=$(_wizard_strip_json_comments "$json_input")
    _WIZARD_CLEANED_JSON_PATH="$cleaned_json"  # Store for cleanup function (global)
    
    # Parse JSON using jq
    local title
    title=$(jq -r '.title // ""' "$cleaned_json" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        rm -f "$cleaned_json"
        _wizard_cleanup_early false
        echo "Error: Failed to parse JSON file: $json_file" >&2
        return 1
    fi
    
    # Get steps array length
    local steps_count
    steps_count=$(jq '.steps | length' "$cleaned_json" 2>/dev/null)
    
    if [ "$steps_count" -eq 0 ]; then
        rm -f "$cleaned_json"
        _wizard_cleanup_early false
        echo "Error: No steps found in JSON file" >&2
        return 1
    fi
    
    # Store cleaned JSON path for orchestrator to parse
    # The orchestrator will parse JSON directly to avoid space issues
    local temp_cleaned_json="$cleaned_json"
    
    # Call orchestrator with JSON file path
    local result
    result=$(_wizard_orchestrate_steps_json "$title" "$temp_cleaned_json")
    local exit_code=$?
    
    # Clean up temp file
    rm -f "$cleaned_json" 2>/dev/null || true
    
    # Output result if successful
    if [ $exit_code -eq 0 ]; then
        echo "$result"
    fi
    
    return $exit_code
}

# Main orchestration loop (JSON-based)
# Arguments: title json_file_path
_wizard_orchestrate_steps_json() {
    local title="$1"
    local json_file="$2"
    
    # Set up signal handlers to restore cursor and exit alternate screen on interrupt
    # Make cleanup function global so it's accessible from signal handlers
    # Note: json_file here is the cleaned temp file, not the original
    local temp_json_file="$json_file"
    
    _wizard_cleanup() {
        local show_message="${1:-false}"  # Optional: show cancellation message
        _imenu_show_cursor
        _imenu_exit_alternate_screen
        # Show cancellation message in original buffer if requested
        if [ "$show_message" = "true" ]; then
            printf '\n%b⚠️  Wizard cancelled%b\n' "${YELLOW}" "${NC}" >&2
        fi
        # Clean up temp cleaned JSON file if it exists (NOT the original file!)
        [ -n "$temp_json_file" ] && [ -f "$temp_json_file" ] && rm -f "$temp_json_file" 2>/dev/null || true
    }
    declare -g -f _wizard_cleanup >/dev/null 2>&1 || true  # Make function global (suppress output)
    
    # Update traps to use cleanup function
    # Ensure cleanup happens on any signal or exit
    # For INT (Ctrl+C), show cancellation message
    # Note: exit in command substitution exits the subshell with that code
    trap '_wizard_cleanup true; exit 130' INT    # Ctrl+C
    trap '_wizard_cleanup false; exit 143' TERM  # SIGTERM
    trap '_wizard_cleanup false' EXIT            # Normal exit or any other exit
    
    # Initialize data manager
    _wizard_data_init
    
    # Print header once (static, lines 1-5)
    _wizard_display_print_header "$title"
    
    # Get steps count
    local steps_count
    steps_count=$(jq '.steps | length' "$json_file" 2>/dev/null)
    
    local step_idx=0
    while [ $step_idx -lt "$steps_count" ]; do
        # Parse step from JSON
        local step_json
        step_json=$(jq -c ".steps[$step_idx]" "$json_file" 2>/dev/null)
        
        local step_type
        local step_message
        step_type=$(echo "$step_json" | jq -r '.type' 2>/dev/null)
        step_message=$(echo "$step_json" | jq -r '.message // ""' 2>/dev/null)
        
        # Build step options array from JSON
        local step_options=()
        
        case "$step_type" in
            multiselect|select|autocomplete)
                # Get options array
                local options_count
                options_count=$(echo "$step_json" | jq '.options | length' 2>/dev/null)
                local j
                for ((j=0; j<options_count; j++)); do
                    local option
                    option=$(echo "$step_json" | jq -r ".options[$j]" 2>/dev/null)
                    step_options+=("$option")
                done
                # Add preselect if present
                local preselect
                preselect=$(echo "$step_json" | jq -c '.preselect // []' 2>/dev/null)
                if [ "$preselect" != "[]" ] && [ "$preselect" != "null" ]; then
                    # Convert array to space-separated string
                    local preselect_str
                    preselect_str=$(echo "$preselect" | jq -r 'join(" ")' 2>/dev/null)
                    step_options+=("--preselect" "$preselect_str")
                fi
                ;;
            confirm)
                # Add initial if present
                local initial
                initial=$(echo "$step_json" | jq -r '.initial // "false"' 2>/dev/null)
                step_options+=("--initial" "$initial")
                ;;
            text|number|list|date)
                # Add initial if present
                local initial
                initial=$(echo "$step_json" | jq -r '.initial // ""' 2>/dev/null)
                if [ -n "$initial" ] && [ "$initial" != "null" ]; then
                    step_options+=("--initial" "$initial")
                fi
                # Add min/max for number
                if [ "$step_type" = "number" ]; then
                    local min
                    min=$(echo "$step_json" | jq -r '.min // ""' 2>/dev/null)
                    if [ -n "$min" ] && [ "$min" != "null" ]; then
                        step_options+=("--min" "$min")
                    fi
                    local max
                    max=$(echo "$step_json" | jq -r '.max // ""' 2>/dev/null)
                    if [ -n "$max" ] && [ "$max" != "null" ]; then
                        step_options+=("--max" "$max")
                    fi
                fi
                # Add separator for list
                if [ "$step_type" = "list" ]; then
                    local separator
                    separator=$(echo "$step_json" | jq -r '.separator // ","' 2>/dev/null)
                    step_options+=("--separator" "$separator")
                fi
                # Add format for date
                if [ "$step_type" = "date" ]; then
                    local format
                    format=$(echo "$step_json" | jq -r '.format // "YYYY-MM-DD HH:mm:ss"' 2>/dev/null)
                    step_options+=("--format" "$format")
                fi
                ;;
        esac
        
        # Build options string for storage (unit separator delimited)
        local IFS=$'\x1F'
        local step_options_str="${step_options[*]}"
        # Reset IFS to default (space, tab, newline) to avoid affecting subsequent operations
        IFS=$' \t\n'
        
        # Get completed count to determine if we need to clear
        local completed_count
        completed_count=$(_wizard_data_get_all)
        
        # Check debug flag once
        local debug_val="${IWIZARD_DEBUG:-false}"
        local debug_enabled=false
        case "$debug_val" in
            [Tt][Rr][Uu][Ee]|[Yy][Ee][Ss]|1|[Oo][Nn])
                debug_enabled=true
                ;;
        esac
        
        # Helper function for debug pause
        # ESC cancels wizard, Ctrl+C cancels wizard, any other key continues
        _wizard_debug_pause() {
            if [ "$debug_enabled" = "true" ]; then
                # Silent pause - ensure cursor is visible
                _imenu_show_cursor
                local saved_stty
                saved_stty=$(stty -g 2>/dev/null || echo "")
                if [ -t 0 ]; then
                    # Don't disable signals (-isig) so Ctrl+C can interrupt
                    stty -echo -icanon min 1 time 0 2>/dev/null || stty -echo -icanon 2>/dev/null || true
                    local key=""
                    if [ -r /dev/tty ] 2>/dev/null; then
                        read -rsn1 key < /dev/tty 2>/dev/null || read -rsn1 key
                    else
                        read -rsn1 key 2>/dev/null || read -n 1 -s key
                    fi
                    [ -n "$saved_stty" ] && stty "$saved_stty" 2>/dev/null || true
                    
                    # Check if ESC was pressed
                    if [ "$key" = $'\x1b' ]; then
                        # ESC pressed - cancel wizard (show message)
                        _wizard_cleanup true
                        trap - INT TERM EXIT
                        return 1
                    fi
                    # Any other key continues (key is ignored)
                    # Note: Ctrl+C will be caught by signal handler
                fi
            fi
        }
        
        # For step 0 (first step), just print header and draw prompt
        # For subsequent steps, clear screen, redraw header, sent section, and active prompt
        if [ $step_idx -eq 0 ]; then
            # First step: header already printed, just draw prompt
            # Debug pause BEFORE drawing first prompt
            _wizard_debug_pause
        else
            # Subsequent steps: clear entire alternate screen and redraw everything
            # Debug pause BEFORE clearing
            _wizard_debug_pause
            
            # Clear entire alternate screen (moves cursor to top-left)
            _wizard_display_clear_content
            
            # Debug pause BEFORE drawing header
            _wizard_debug_pause
            
            # Redraw header (static, lines 1-5)
            _wizard_display_print_header "$title"
            
            # Debug pause BEFORE drawing sent section
            _wizard_debug_pause
            
            # Draw sent section (all completed steps, dimmed)
            _wizard_display_draw_sent_section "$completed_count"
            
            # Debug pause BEFORE drawing active prompt
            _wizard_debug_pause
        fi
        
        # Cursor positioning: 
        # - After clear, cursor is at top-left (line 1, column 0)
        # - After header, cursor is at line 6 (virtual line 1)
        # - After sent section, cursor is positioned after it (sent section adds blank line)
        # So no manual positioning needed
        
        # Set environment for prompt
        local has_back="false"
        if [ $step_idx -gt 0 ]; then
            has_back="true"
        fi
        export IMENU_HAS_BACK="$has_back"
        
        # Call prompt via iPrompt
        # iprompt_run signature: name type message [options...]
        # Note: We use a temp file for result to avoid subshell signal handling issues
        local result_file
        result_file=$(mktemp /tmp/wizard_result_XXXXXX 2>/dev/null || echo "/tmp/wizard_result_$$")
        local exit_code
        
        # Run prompt and capture exit code directly (not in subshell)
        # This ensures signal handlers work properly
        iprompt_run "step$step_idx" "$step_type" "$step_message" "${step_options[@]}" > "$result_file"
        exit_code=$?
        local result
        result=$(cat "$result_file" 2>/dev/null || echo "")
        rm -f "$result_file" 2>/dev/null || true
        
        # Handle exit codes
        if [ $exit_code -eq 1 ]; then
            # Cancel (ESC) - show cancellation message
            # Remove trap handlers
            trap - INT TERM EXIT
            _imenu_show_cursor
            _imenu_exit_alternate_screen
            printf '\n%b⚠️  Wizard cancelled%b\n' "${YELLOW}" "${NC}" >&2
            rm -f "$temp_json_file"  # Only delete temp file, not original
            return 1
        elif [ $exit_code -eq 2 ]; then
            # Back navigation
            if [ $step_idx -gt 0 ]; then
                _wizard_data_remove_last
                step_idx=$((step_idx - 1))
                continue
            fi
        elif [ $exit_code -ne 0 ]; then
            # Other error
            # Remove trap handlers
            trap - INT TERM EXIT
            _imenu_show_cursor
            _imenu_exit_alternate_screen
            rm -f "$temp_json_file"  # Only delete temp file, not original
            return $exit_code
        fi
        
        # Store result in data manager
        _wizard_data_store "$step_idx" "$step_type" "$step_message" "$result" "$step_options_str"
        
        # Move to next step
        step_idx=$((step_idx + 1))
    done
    
    # After last step: clear, draw all sent steps, return JSON
    _wizard_display_clear_content
    local final_count
    final_count=$(_wizard_data_get_all)
    _wizard_display_draw_sent_section "$final_count"
    # Add blank line after sent section for final display
    printf '\n' >&2
    
    # Generate and return JSON
    local json_output
    json_output=$(_wizard_data_get_json)
    echo "$json_output"
    
    # Clean up temp cleaned JSON file (NOT the original file!)
    rm -f "$temp_json_file"
    
    # Explicitly call cleanup before removing traps (safety net)
    _wizard_cleanup
    
    # Remove trap handlers on successful completion
    trap - INT TERM EXIT
    
    return 0
}

