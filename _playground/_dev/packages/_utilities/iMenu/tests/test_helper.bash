#!/usr/bin/env bash
# iMenu Test Suite Setup
# Provides utilities for testing iMenu components

# Test helper functions
setup() {
    # Setup test environment before each test
    export IMENU_TEST_MODE=true
    # Reset config
    unset IMENU_NO_MESSAGE_BLANK
    unset IMENU_MESSAGE_OPTIONS_GAP
    unset IMENU_INPUT_INLINE
    unset IMENU_TITLE
    unset IMENU_HAS_BACK
    unset IMENU_CLEAR_PREVIOUS
    unset IMENU_INITIAL
    unset IMENU_MIN
    unset IMENU_MAX
    unset IMENU_LIMIT
    unset IMENU_MESSAGE_PREFIX
    unset TEST_INPUT
    unset TEST_INPUT_SEQUENCE
    unset TEST_INPUT_INDEX
    unset TEST_ARROW
    # Reset cursor tracking
    unset CAPTURED_CURSOR_MOVES
    unset CAPTURED_CURSOR_SHOW
    unset CAPTURED_CURSOR_HIDE
    export CAPTURED_CURSOR_MOVES=""
    export CAPTURED_CURSOR_SHOW=0
    export CAPTURED_CURSOR_HIDE=0
}

teardown() {
    # Cleanup after each test
    unset IMENU_TEST_MODE
    unset TEST_INPUT
    unset TEST_INPUT_SEQUENCE
    unset TEST_INPUT_INDEX
    unset TEST_ARROW
    unset CAPTURED_CURSOR_MOVES
    unset CAPTURED_CURSOR_SHOW
    unset CAPTURED_CURSOR_HIDE
}

# Mock terminal input - reads from TEST_INPUT or TEST_INPUT_SEQUENCE
# Must be defined BEFORE load_iMenu uses it
mock_read_char() {
    if [ -n "${TEST_INPUT_SEQUENCE:-}" ]; then
        # Use sequence of inputs
        local idx="${TEST_INPUT_INDEX:-0}"
        local inputs=($TEST_INPUT_SEQUENCE)
        if [ $idx -lt ${#inputs[@]} ]; then
            echo -n "${inputs[$idx]}"
            TEST_INPUT_INDEX=$((idx + 1))
            export TEST_INPUT_INDEX
        else
            echo -n ""
        fi
    elif [ -n "${TEST_INPUT:-}" ]; then
        # Single input
        echo -n "$TEST_INPUT"
    else
        # Default: Enter key
        echo -n $'\n'
    fi
}

# Mock terminal escape sequence reader
# Must be defined BEFORE load_iMenu uses it
mock_read_escape() {
    if [ -n "${TEST_ARROW:-}" ]; then
        echo -n "$TEST_ARROW"
    else
        echo -n ""
    fi
}

# Load iMenu for testing
load_iMenu() {
    local test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    
    # Override terminal functions BEFORE loading iMenu
    # This ensures our mocks are in place when iMenu sources terminal.sh
    _imenu_read_char() {
        mock_read_char
    }
    
    _imenu_read_escape() {
        mock_read_escape
    }
    
    _imenu_clear_line() {
        : # No-op for testing
    }
    
    _imenu_clear_menu() {
        : # No-op for testing
    }
    
    _imenu_hide_cursor() {
        CAPTURED_CURSOR_HIDE=$((CAPTURED_CURSOR_HIDE + 1))
        export CAPTURED_CURSOR_HIDE
    }
    
    _imenu_show_cursor() {
        CAPTURED_CURSOR_SHOW=$((CAPTURED_CURSOR_SHOW + 1))
        export CAPTURED_CURSOR_SHOW
    }
    
    # Capture cursor positioning codes
    # We'll intercept printf calls that contain cursor movement codes
    _imenu_print_cursor_move() {
        local code="$1"
        CAPTURED_CURSOR_MOVES="${CAPTURED_CURSOR_MOVES}${code};"
        export CAPTURED_CURSOR_MOVES
    }
    
    _imenu_print_header() {
        : # No-op for testing
    }
    
    # Now load iMenu (it will use our mocked functions)
    source "${test_dir}/iMenu.sh"
    
    # Re-override after loading (in case iMenu.sh redefines them)
    _imenu_read_char() {
        mock_read_char
    }
    
    _imenu_read_escape() {
        mock_read_escape
    }
    
    _imenu_hide_cursor() {
        CAPTURED_CURSOR_HIDE=$((CAPTURED_CURSOR_HIDE + 1))
        export CAPTURED_CURSOR_HIDE
    }
    
    _imenu_show_cursor() {
        CAPTURED_CURSOR_SHOW=$((CAPTURED_CURSOR_SHOW + 1))
        export CAPTURED_CURSOR_SHOW
    }
}

# Capture stderr and extract cursor positioning codes
capture_cursor_codes() {
    local cmd="$1"
    local stderr_file=$(mktemp)
    eval "$cmd" 2>"$stderr_file"
    # Extract cursor movement codes (\033[NC where N is number of columns)
    grep -oP '\033\[\d+C' "$stderr_file" || echo ""
    rm -f "$stderr_file"
}

# Assert cursor was positioned correctly (at end of input)
# expected_length should be the visible text length (excluding ANSI color codes)
assert_cursor_at_end() {
    local stderr_output="$1"
    local expected_length="$2"
    # Look for cursor move right code: \033[NC where N should match expected_length
    # The cursor position code moves the cursor N columns, which should match visible text length
    local found_positions
    found_positions=$(echo "$stderr_output" | grep -oP '\033\[\d+C' | grep -oP '\d+' || echo "")
    
    if [ -z "$found_positions" ]; then
        echo "Expected cursor position code \\033[${expected_length}C, but no cursor positioning codes found" >&2
        return 1
    fi
    
    # Check if any of the cursor positions match the expected length
    local match_found=false
    for pos in $found_positions; do
        if [ "$pos" -eq "$expected_length" ]; then
            match_found=true
            break
        fi
    done
    
    if [ "$match_found" = true ]; then
        return 0
    else
        echo "Expected cursor position code \\033[${expected_length}C, but found positions: $found_positions" >&2
        return 1
    fi
}

# Extract cursor position codes from stderr output
extract_cursor_positions() {
    local stderr_output="$1"
    echo "$stderr_output" | grep -oP '\033\[\d+C' | grep -oP '\d+' | tr '\n' ' ' | sed 's/ $//'
}

# Assert cursor show was called
assert_cursor_shown() {
    local count="${CAPTURED_CURSOR_SHOW:-0}"
    if [ "$count" -gt 0 ]; then
        return 0
    else
        echo "Expected cursor to be shown, but _imenu_show_cursor was not called" >&2
        return 1
    fi
}

# Assert cursor hide was called
assert_cursor_hidden() {
    local count="${CAPTURED_CURSOR_HIDE:-0}"
    if [ "$count" -gt 0 ]; then
        return 0
    else
        echo "Expected cursor to be hidden, but _imenu_hide_cursor was not called" >&2
        return 1
    fi
}

# Setup mocks for terminal functions (called after load_iMenu)
setup_terminal_mocks() {
    # Functions are already mocked in load_iMenu, this is just for compatibility
    :
}

# Capture stderr output from a command
capture_stderr() {
    local cmd="$1"
    local stderr_file=$(mktemp)
    eval "$cmd" 2>"$stderr_file"
    cat "$stderr_file"
    rm -f "$stderr_file"
}

# Assert that output contains a string
assert_contains() {
    local output="$1"
    local expected="$2"
    if [[ "$output" == *"$expected"* ]]; then
        return 0
    else
        echo "Expected output to contain '$expected', but got: $output" >&2
        return 1
    fi
}

# Assert that output does not contain a string
assert_not_contains() {
    local output="$1"
    local unexpected="$2"
    if [[ "$output" != *"$unexpected"* ]]; then
        return 0
    else
        echo "Expected output to NOT contain '$unexpected', but got: $output" >&2
        return 1
    fi
}
