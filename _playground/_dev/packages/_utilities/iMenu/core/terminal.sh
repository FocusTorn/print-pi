#!/usr/bin/env bash
# iMenu Core - Terminal Control Functions

# Hide cursor (output to stderr so visible even when stdout captured)
_imenu_hide_cursor() {
    tput civis >&2 2>/dev/null || printf "\033[?25l" >&2 || true
}

# Show cursor (output to stderr so visible even when stdout captured)
_imenu_show_cursor() {
    tput cnorm >&2 2>/dev/null || printf "\033[?25h" >&2 || true
}

# Clear menu area - move cursor up and clear lines
_imenu_clear_menu() {
    local lines=$1
    # Move cursor up N lines (to stderr so visible even when stdout is captured)
    for ((i=0; i<lines; i++)); do
        printf "\033[A" >&2 2>/dev/null || tput cuu1 >&2 2>/dev/null || true
        # Clear the entire line
        printf "\r" >&2; tput el >&2 2>/dev/null || printf "\033[K" >&2 2>/dev/null || true
    done
    # Ensure cursor is at column 0
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
            local arrow
            IFS= read -rsn1 -t 0.05 arrow 2>/dev/null || arrow=""
            echo -n "$arrow"
        else
            echo -n "$esc_char"
        fi
    else
        echo ""
    fi
}

