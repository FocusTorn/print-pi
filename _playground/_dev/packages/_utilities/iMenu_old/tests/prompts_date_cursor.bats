#!/usr/bin/env bash
# BATS tests for cursor positioning in date prompt (newline mode)

load 'test_helper'

@test "date prompt: cursor shown (date prompt uses show_cursor)" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    # First check cursor is shown (without capturing stderr in subshell)
    imenu_date "test_name" "Enter date:" "2024-01-01 12:00:00" 2>/dev/null >/dev/null
    
    # Date prompt shows cursor (it's an input prompt)
    assert_cursor_shown
    
    # Now check cursor positioning (capture stderr separately)
    local stderr_output
    stderr_output=$(imenu_date "test_name" "Enter date:" "2024-01-01 12:00:00" 2>&1 >/dev/null)
    
    # Date prompt should position cursor at beginning of default value
    # Display is: "? " (2 chars) + default value (greyed out)
    # Cursor should be at column 2 (after "? ", at start of default)
    assert_cursor_at_end "$stderr_output" "2"
    
    # Also verify cursor is on the correct line (vertical positioning)
    assert_cursor_on_correct_line "$stderr_output" "newline"
}

@test "date prompt: cursor shown for empty initial" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    # First check cursor is shown (without capturing stderr in subshell)
    imenu_date "test_name" "Enter date:" "" 2>/dev/null >/dev/null
    
    # Date prompt shows cursor
    assert_cursor_shown
    
    # Now check cursor positioning (capture stderr separately)
    local stderr_output
    stderr_output=$(imenu_date "test_name" "Enter date:" "" 2>&1 >/dev/null)
    
    # Date prompt should position cursor at end of input (or at prompt if empty)
    # For empty initial, date prompt uses current date, so we need to check for cursor positioning
    # The test will verify cursor is positioned correctly
    assert_cursor_on_correct_line "$stderr_output" "newline"
}

@test "date prompt: cursor shown at end" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    # First check cursor is shown (without capturing stderr in subshell)
    imenu_date "test_name" "Enter date:" "2024-12-31 23:59:59" 2>/dev/null >/dev/null
    
    # Date prompt shows cursor (it's an input prompt)
    assert_cursor_shown
    
    # Now check cursor positioning (capture stderr separately)
    local stderr_output
    stderr_output=$(imenu_date "test_name" "Enter date:" "2024-12-31 23:59:59" 2>&1 >/dev/null)
    
    # Date prompt should position cursor at beginning of default value
    # Display is: "? " (2 chars) + default value (greyed out)
    # Cursor should be at column 2 (after "? ", at start of default)
    assert_cursor_at_end "$stderr_output" "2"
    
    # Also verify cursor is on the correct line (vertical positioning)
    assert_cursor_on_correct_line "$stderr_output" "newline"
}

@test "date prompt: cursor hidden during redraw" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    imenu_date "test_name" "Enter date:" "2024-01-01 12:00:00" 2>/dev/null >/dev/null
    
    # Date prompt should hide cursor during redraw
    assert_cursor_hidden
}

