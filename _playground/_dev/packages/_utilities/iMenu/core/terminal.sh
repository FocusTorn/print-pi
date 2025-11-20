#!/usr/bin/env bash
# iMenu Core - Terminal Control Functions

# Terminal output logging (for debugging)
# Set IMENU_LOG_TERMINAL=true to enable logging of all terminal output
_IMENU_LOG_FILE="/home/pi/_playground/_dev/packages/_utilities/iMenu/log.txt"

# Log terminal output (if logging enabled)
_imenu_log_terminal() {
    if [ "${IMENU_LOG_TERMINAL:-false}" = "true" ]; then
        # Log with hex dump to see exact bytes
        local timestamp
        timestamp=$(date +%H:%M:%S.%3N 2>/dev/null || date +%H:%M:%S)
        echo "[$timestamp] TERMINAL: $(echo -n "$1" | od -An -tx1 -v | tr -d '\n' | sed 's/ / /g')" >> "$_IMENU_LOG_FILE" 2>/dev/null || true
        # Also log readable representation
        echo "[$timestamp] TERMINAL_READABLE: $(printf '%q' "$1")" >> "$_IMENU_LOG_FILE" 2>/dev/null || true
    fi
}

# Hide cursor (output to stderr so visible even when stdout captured)
_imenu_hide_cursor() {
    tput civis >&2 2>/dev/null || printf "\033[?25l" >&2 || true
}

# Show cursor (output to stderr so visible even when stdout captured)
_imenu_show_cursor() {
    tput cnorm >&2 2>/dev/null || printf "\033[?25h" >&2 || true
}

# Clear menu area - move cursor up and clear lines
# This clears N lines upward from current position, then returns cursor to start
_imenu_clear_menu() {
    local lines=$1
    # Move cursor up N lines (to stderr so visible even when stdout is captured)
    for ((i=0; i<lines; i++)); do
        printf "\033[A" >&2 2>/dev/null || tput cuu1 >&2 2>/dev/null || true
        # Clear the entire line
        printf "\r" >&2; tput el >&2 2>/dev/null || printf "\033[K" >&2 2>/dev/null || true
    done
    # Ensure cursor is at column 0 (we're already at the start position after moving up)
    printf "\r" >&2
}

# Clear current line
_imenu_clear_line() {
    printf "\r" >&2
    tput el >&2 2>/dev/null || printf "\033[K" >&2 2>/dev/null || true
}

# Save cursor position
_imenu_save_cursor() {
    printf '\033[s' >&2 2>/dev/null || true
}

# Restore cursor position
_imenu_restore_cursor() {
    printf '\033[u' >&2 2>/dev/null || true
}

# Read a single character (silent, non-blocking)
_imenu_read_char() {
    # Save current terminal settings
    local saved_settings
    saved_settings=$(stty -g 2>/dev/null || echo "")
    
    # Set raw mode: disable echo, canonical mode, and signals
    stty -echo -icanon -isig 2>/dev/null || true
    
    # Read character silently
    IFS= read -rsn1 char 2>/dev/null || char=""
    
    # Log input if logging enabled
    if [ "${IMENU_LOG_TERMINAL:-false}" = "true" ] && [ -n "$char" ]; then
        local timestamp
        timestamp=$(date +%H:%M:%S.%3N 2>/dev/null || date +%H:%M:%S)
        echo "[$timestamp] INPUT: $(echo -n "$char" | od -An -tx1 -v | tr -d '\n' | sed 's/ / /g') ($(printf '%q' "$char"))" >> "$_IMENU_LOG_FILE" 2>/dev/null || true
    fi
    
    # Restore terminal settings
    if [ -n "$saved_settings" ]; then
        stty "$saved_settings" 2>/dev/null || true
    fi
    
    echo -n "$char"
}

# Read escape sequence (for arrow keys)
_imenu_read_escape() {
    local esc_char
    if IFS= read -rsn1 -t 0.05 esc_char 2>/dev/null; then
        if [[ "$esc_char" == "[" ]]; then
            local next_char
            IFS= read -rsn1 -t 0.05 next_char 2>/dev/null || next_char=""
            
            # Log escape sequence if logging enabled
            if [ "${IMENU_LOG_TERMINAL:-false}" = "true" ]; then
                local timestamp
                timestamp=$(date +%H:%M:%S.%3N 2>/dev/null || date +%H:%M:%S)
                local full_seq="\033[$next_char"
                echo "[$timestamp] ESCAPE_SEQ: $(echo -n "$full_seq" | od -An -tx1 -v | tr -d '\n' | sed 's/ / /g') ($(printf '%q' "$full_seq"))" >> "$_IMENU_LOG_FILE" 2>/dev/null || true
            fi
            
            # Filter out mouse sequences (shouldn't happen if mouse is disabled, but safety check)
            if [[ "$next_char" == "M" ]] || [[ "$next_char" == "<" ]]; then
                # Mouse sequence detected - consume and ignore completely
                if [ "${IMENU_LOG_TERMINAL:-false}" = "true" ]; then
                    local timestamp
                    timestamp=$(date +%H:%M:%S.%3N 2>/dev/null || date +%H:%M:%S)
                    echo "[$timestamp] MOUSE_SEQ_DETECTED: filtering out" >> "$_IMENU_LOG_FILE" 2>/dev/null || true
                fi
                if [[ "$next_char" == "M" ]]; then
                    # X10 mouse: consume 3 more bytes
                    IFS= read -rsn3 -t 0.1 >/dev/null 2>&1 || true
                else
                    # SGR mouse: consume until m or M
                    local mouse_char
                    while IFS= read -rsn1 -t 0.1 mouse_char 2>/dev/null; do
                        [[ "$mouse_char" == "m" ]] || [[ "$mouse_char" == "M" ]] && break
                    done
                fi
                # Return empty - mouse events should be ignored
                echo ""
            else
                # Arrow key or other CSI sequence (normal input)
                echo -n "$next_char"
            fi
        else
            echo -n "$esc_char"
        fi
    else
        echo ""
    fi
}

# Enter alternate screen buffer (prevents affecting scrollback)
_imenu_enter_alternate_screen() {
    local seq=$'\033[?1049h'
    _imenu_log_terminal "$seq"
    printf '%b' "$seq" >&2 2>/dev/null || printf '\033[?1047h' >&2 2>/dev/null || true
}

# Exit alternate screen buffer (return to normal screen)
_imenu_exit_alternate_screen() {
    local seq=$'\033[?1049l'
    _imenu_log_terminal "$seq"
    printf '%b' "$seq" >&2 2>/dev/null || printf '\033[?1047l' >&2 2>/dev/null || true
}

# Clear entire screen and move cursor to top-left
_imenu_clear_screen() {
    local seq=$'\033[H\033[2J'
    _imenu_log_terminal "$seq"
    printf '%b' "$seq" >&2 2>/dev/null || tput clear >&2 2>/dev/null || true
}

# Get terminal height (number of lines)
_imenu_get_terminal_height() {
    local height
    height=$(tput lines 2>/dev/null || echo "${LINES:-24}")
    echo "$height"
}

# Get terminal width (number of columns)
_imenu_get_terminal_width() {
    local width
    width=$(tput cols 2>/dev/null || echo "${COLUMNS:-80}")
    echo "$width"
}

# Check if we're at terminal top boundary
# Returns 0 (true) if at top, 1 (false) otherwise
# This is a simple heuristic - assumes we're near top if cursor is in upper portion
_imenu_at_terminal_top() {
    # This is a simplified check - in practice, we'd need to track cursor position
    # For now, we'll use a different approach: prevent scrolling by not wrapping
    # when at boundaries if IMENU_DISABLE_SCROLLING is enabled
    return 1  # Default: not at top (allow navigation)
}

# Check if we're at terminal bottom boundary  
# Returns 0 (true) if at bottom, 1 (false) otherwise
_imenu_at_terminal_bottom() {
    # Simplified check - see _imenu_at_terminal_top for notes
    return 1  # Default: not at bottom (allow navigation)
}

# Prevent scrolling at boundaries by constraining navigation
# This allows terminal scrolling for content, but prevents scrolling when
# navigating menu items at boundaries
# Arguments: current_index, total_options, direction ("up" or "down")
# Returns: new_index (may be same as current if at boundary)
_imenu_prevent_boundary_scroll() {
    local current="$1"
    local total="$2"
    local direction="$3"
    
    # If scroll prevention is disabled, use normal wrapping behavior
    if [ "${IMENU_DISABLE_SCROLLING:-false}" != "true" ]; then
        if [ "$direction" = "up" ]; then
            echo $(((current - 1 + total) % total))
        else
            echo $(((current + 1) % total))
        fi
        return
    fi
    
    # With scroll prevention: prevent wrapping at boundaries
    # This prevents scrolling but still allows navigation within visible range
    if [ "$direction" = "up" ]; then
        if [ $current -eq 0 ]; then
            # At top: don't wrap, stay at top
            echo "$current"
        else
            echo $((current - 1))
        fi
    else
        if [ $current -eq $((total - 1)) ]; then
            # At bottom: don't wrap, stay at bottom
            echo "$current"
        else
            echo $((current + 1))
        fi
    fi
}

