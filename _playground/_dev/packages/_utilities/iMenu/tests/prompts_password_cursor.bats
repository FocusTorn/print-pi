#!/usr/bin/env bash
# BATS tests for cursor positioning in password prompt (newline mode)

load 'test_helper'

@test "password prompt: cursor positioned at end of initial value" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    local stderr_output
    stderr_output=$(imenu_password "test_name" "Enter password:" "secret123" 2>&1 >/dev/null)
    
    # Cursor should be positioned at end of masked input + "? " (2 chars)
    # "secret123" (9 chars) + "? " (2) = 11
    assert_cursor_at_end "$stderr_output" "11"
    
    # Also verify cursor is on the correct line (vertical positioning)
    assert_cursor_on_correct_line "$stderr_output" "newline"
}

@test "password prompt: cursor shown after positioning" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    imenu_password "test_name" "Enter password:" "test" 2>/dev/null >/dev/null
    
    assert_cursor_shown
}

@test "password prompt: cursor hidden during redraw" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    imenu_password "test_name" "Enter password:" "password" 2>/dev/null >/dev/null
    
    assert_cursor_hidden
}

