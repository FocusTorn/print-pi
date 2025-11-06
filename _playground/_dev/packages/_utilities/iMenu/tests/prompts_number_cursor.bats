#!/usr/bin/env bash
# BATS tests for cursor positioning in number prompt

load 'test_helper'

@test "number prompt: cursor positioned at end of initial value" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    local stderr_output
    stderr_output=$(imenu_number "test_name" "Enter:" "42" 2>&1 >/dev/null)
    
    # Cursor should be positioned at end of "42" + "? " (2 chars) = 4 chars
    assert_cursor_at_end "$stderr_output" "4"
}

@test "number prompt: cursor shown after positioning" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    imenu_number "test_name" "Enter:" "25" 2>/dev/null >/dev/null
    
    assert_cursor_shown
}

@test "number prompt: cursor hidden during redraw" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    imenu_number "test_name" "Enter:" "100" 2>/dev/null >/dev/null
    
    assert_cursor_hidden
}

