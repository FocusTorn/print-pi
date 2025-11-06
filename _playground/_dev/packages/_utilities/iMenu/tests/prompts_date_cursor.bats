#!/usr/bin/env bash
# BATS tests for cursor positioning in date prompt (newline mode)

load 'test_helper'

@test "date prompt: cursor shown (date prompt uses show_cursor)" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    local stderr_output
    stderr_output=$(imenu_date "test_name" "Enter date:" "2024-01-01 12:00:00" 2>&1 >/dev/null)
    
    # Date prompt shows cursor (it's an input prompt)
    assert_cursor_shown
    
    # Date prompt should position cursor at end of input
    # Display is: "? 2024-01-01 12:00:00"
    # Visible text length: "? " (2 chars) + "2024-01-01 12:00:00" (19 chars) = 21 chars
    assert_cursor_at_end "$stderr_output" "21"
    
    # Also verify cursor is on the correct line (vertical positioning)
    assert_cursor_on_correct_line "$stderr_output" "newline"
}

@test "date prompt: cursor shown for empty initial" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    local stderr_output
    stderr_output=$(imenu_date "test_name" "Enter date:" "" 2>&1 >/dev/null)
    
    # Date prompt shows cursor
    assert_cursor_shown
    
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
    
    local stderr_output
    stderr_output=$(imenu_date "test_name" "Enter date:" "2024-12-31 23:59:59" 2>&1 >/dev/null)
    
    # Date prompt shows cursor (it's an input prompt)
    assert_cursor_shown
    
    # Date prompt should position cursor at end of input
    # Display is: "? 2024-12-31 23:59:59"
    # Visible text length: "? " (2 chars) + "2024-12-31 23:59:59" (19 chars) = 21 chars
    assert_cursor_at_end "$stderr_output" "21"
    
    # Also verify cursor is on the correct line (vertical positioning)
    assert_cursor_on_correct_line "$stderr_output" "newline"
}

