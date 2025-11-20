#!/usr/bin/env bash
# iWizard Core - Display Functions
# Handles header printing, content clearing, and sent section drawing
# Uses scrollable mode with line tracking for efficient clearing

# Global variable to track content start line (after blank line)
# No header banner, so content starts at line 2 (after blank line)
_WIZARD_CONTENT_START_LINE=2

# Global variable to track current content line count
# This tracks how many lines of content have been drawn (sent section + active prompt)
_WIZARD_CONTENT_LINES=0

# Print blank line to start wizard (no header banner)
# Content starts at line 2 (after blank line)
# After printing, cursor is at line 2, column 0
# Arguments: title (unused, kept for compatibility)
_wizard_display_print_header() {
    local title="$1"
    
    # Reset content line tracking
    _WIZARD_CONTENT_LINES=0
    
    # Just print a blank line to start
    printf '\n' >&2
    
    # Cursor is now at line 2, column 0 - no positioning needed
}

# Clear only the content area (from content start line downward)
# In scrollable mode, don't clear anything - let terminal scroll naturally
_wizard_display_clear_content() {
    # In scrollable mode, we don't clear anything - terminal scrolling handles it
    # The sent section and new prompt will appear below the previous content
    # Just reset content line tracking for next iteration
    _WIZARD_CONTENT_LINES=0
}

# Draw the sent section (all completed steps, dimmed)
# Arguments: step_count (number of completed steps)
# Uses global arrays from wizard-data: _WIZARD_MESSAGES, _WIZARD_RESULTS, _WIZARD_TYPES
# Note: This draws starting at line 2 (after blank line)
# Tracks line count for efficient clearing
_wizard_display_draw_sent_section() {
    local step_count="$1"
    local lines_drawn=0
    
    # Note: A newline is already added after prompt completion in wizard-orchestrator.sh
    # So we start on a fresh line here
    
    # Draw all completed steps as dimmed
    local i
    for ((i=0; i<step_count; i++)); do
        if [ -n "${_WIZARD_MESSAGES[$i]:-}" ]; then
            local step_msg="${_WIZARD_MESSAGES[$i]}"
            local formatted_result="${_WIZARD_RESULTS[$i]:-}"
            local step_type="${_WIZARD_TYPES[$i]:-text}"
            
            if [ "$step_type" = "confirm" ] || [ "$step_type" = "text" ] || [ "$step_type" = "number" ] || [ "$step_type" = "list" ]; then
                # For confirm/text/number/list, show message and answer inline, both dimmed
                # Format: "ℹ️  Proceed? Yes"
                printf '%b%s%s%b\n' "${DIM}" "$step_msg" "$formatted_result" "${NC}" >&2
                lines_drawn=$((lines_drawn + 1))
            elif [ "$step_type" = "multiselect" ] || [ "$step_type" = "select" ]; then
                # For multiselect/select, show message dimmed, then result on separate lines (no blank line between)
                # Format: "ℹ️  Which services?"
                #         "    ● Sensor readings"
                #         "    ● Data logging"
                # Note: formatted_result starts with a newline, so we print message WITHOUT newline
                printf '%b%s%b' "${DIM}" "$step_msg" "${NC}" >&2
                lines_drawn=$((lines_drawn + 1))
                if [ -n "$formatted_result" ]; then
                    # Count lines in formatted_result (it contains newlines and indentation)
                    # formatted_result is already formatted with newlines, so count them
                    local result_lines
                    result_lines=$(printf '%s' "$formatted_result" | wc -l 2>/dev/null || echo "0")
                    # If wc -l returns 0 for single line, ensure at least 1
                    if [ "$result_lines" -eq 0 ] && [ -n "$formatted_result" ]; then
                        result_lines=1
                    fi
                    lines_drawn=$((lines_drawn + result_lines))
                    # formatted_result contains leading newline and indentation, but may not end with newline
                    # So we print it and ensure it ends with a newline
                    printf '%b%s%b\n' "${DIM}" "$formatted_result" "${NC}" >&2
                else
                    # If no result, add newline to end the message line
                    printf '\n' >&2
                fi
            else
                # For other types, show message dimmed, result on next line
                printf '%b%s%b\n' "${DIM}" "$step_msg" "${NC}" >&2
                lines_drawn=$((lines_drawn + 1))
                if [ -n "$formatted_result" ]; then
                    printf '%b%s%b\n' "${DIM}" "$formatted_result" "${NC}" >&2
                    lines_drawn=$((lines_drawn + 1))
                fi
            fi
            # No blank line between steps - they should be butted up
        fi
    done
    # Add a single blank line after all submitted steps (before active prompt)
    if [ "$step_count" -gt 0 ]; then
        printf '\n' >&2
        lines_drawn=$((lines_drawn + 1))
    fi
    
    # Update global content line tracker
    _WIZARD_CONTENT_LINES=$lines_drawn
}

