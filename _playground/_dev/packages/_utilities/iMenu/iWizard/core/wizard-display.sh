#!/usr/bin/env bash
# iWizard Core - Display Functions
# Handles header printing, content clearing, and sent section drawing
# Uses alternate screen buffer with line tracking for efficient clearing

# Global variable to track content start line (after header)
# Header is 5 lines, so content starts at line 6
_WIZARD_CONTENT_START_LINE=6

# Global variable to track current content line count
# This tracks how many lines of content have been drawn (sent section + active prompt)
_WIZARD_CONTENT_LINES=0

# Print standard wizard header (lines 1-5)
# Line 1: blank
# Line 2: separator
# Line 3: title
# Line 4: separator
# Line 5: blank (after banner, part of static banner)
# Content starts at line 6 (virtual line 1)
# After printing, cursor is at line 6, column 0
# Arguments: title
_wizard_display_print_header() {
    local title="$1"
    
    # Reset content line tracking
    _WIZARD_CONTENT_LINES=0
    
    # Line 1: blank line (before banner)
    printf '\n' >&2
    # Line 2: top separator
    printf '%b════════════════════════════════════════%b\n' "${CYAN}" "${NC}" >&2
    # Line 3: title
    printf '%b  %s%b\n' "${CYAN}" "$title" "${NC}" >&2
    # Line 4: bottom separator
    printf '%b════════════════════════════════════════%b\n' "${CYAN}" "${NC}" >&2
    # Line 5: blank line (after banner, part of static banner)
    printf '\n' >&2
    
    # Cursor is now at line 6, column 0 (virtual line 1) - no positioning needed
}

# Clear only the content area (from content start line downward)
# This preserves the header and uses cursor movement to clear specific lines
# Much more efficient than clearing the entire screen
# Note: This does NOT redraw the header - header should remain static
_wizard_display_clear_content() {
    # Move cursor to content start line (line 6, column 1)
    # Use absolute positioning to ensure we're at the exact right place
    printf '\033[%d;1H' "$_WIZARD_CONTENT_START_LINE" >&2
    
    # Clear from cursor position to end of screen
    # \033[J clears from cursor to end of screen (preserves lines above cursor)
    printf '\033[J' >&2
    
    # Ensure cursor is positioned at content start for next draw
    # This ensures sent section draws from the correct position
    printf '\033[%d;1H' "$_WIZARD_CONTENT_START_LINE" >&2
    
    # Reset content line tracking
    _WIZARD_CONTENT_LINES=0
}

# Draw the sent section (all completed steps, dimmed)
# Arguments: step_count (number of completed steps)
# Uses global arrays from wizard-data: _WIZARD_MESSAGES, _WIZARD_RESULTS, _WIZARD_TYPES
# Note: This draws starting at line 6 (virtual line 1, after static banner lines 1-5)
# Tracks line count for efficient clearing
_wizard_display_draw_sent_section() {
    local step_count="$1"
    local lines_drawn=0
    
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

