#!/usr/bin/env bash
# iWizard Core - Display Functions
# Handles header printing, content clearing, and sent section drawing
# Uses alternate screen buffer - no need to track line positions

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

# Clear entire alternate screen and redraw from top
# Since we're in alternate screen buffer, we can just clear everything and redraw
# This is much simpler than tracking line positions
_wizard_display_clear_content() {
    # Clear entire screen and move cursor to top-left
    _imenu_clear_screen
}

# Draw the sent section (all completed steps, dimmed)
# Arguments: step_count (number of completed steps)
# Uses global arrays from wizard-data: _WIZARD_MESSAGES, _WIZARD_RESULTS, _WIZARD_TYPES
# Note: This draws starting at line 6 (virtual line 1, after static banner lines 1-5)
_wizard_display_draw_sent_section() {
    local step_count="$1"
    
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
            elif [ "$step_type" = "multiselect" ] || [ "$step_type" = "select" ]; then
                # For multiselect/select, show message dimmed, then result on separate lines (no blank line between)
                # Format: "ℹ️  Which services?"
                #         "    ● Sensor readings"
                #         "    ● Data logging"
                printf '%b%s%b' "${DIM}" "$step_msg" "${NC}" >&2
                if [ -n "$formatted_result" ]; then
                    # formatted_result already contains newlines and indentation
                    printf '%b%s%b' "${DIM}" "$formatted_result" "${NC}" >&2
                fi
                printf '\n' >&2  # Final newline to end this step
            else
                # For other types, show message dimmed, result on next line
                printf '%b%s%b\n' "${DIM}" "$step_msg" "${NC}" >&2
                if [ -n "$formatted_result" ]; then
                    printf '%b%s%b\n' "${DIM}" "$formatted_result" "${NC}" >&2
                fi
            fi
            # No blank line between steps - they should be butted up
        fi
    done
    # Add a single blank line after all submitted steps (before active prompt)
    if [ "$step_count" -gt 0 ]; then
        printf '\n' >&2
    fi
}

