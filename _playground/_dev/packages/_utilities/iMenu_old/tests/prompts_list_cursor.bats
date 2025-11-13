#!/usr/bin/env bash
# BATS tests for cursor positioning in list prompt

load 'test_helper'

@test "list prompt: cursor positioned at end of initial value" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    local stderr_output
    stderr_output=$(imenu_list "test_name" "Enter:" "item1,item2" 2>&1 >/dev/null)
    
    # Cursor should be positioned at end of input + "? " (2 chars)
    # "item1,item2" (11) + "? " (2) = 13
    assert_cursor_at_end "$stderr_output" "13"
    
    # Also verify cursor is on the correct line (vertical positioning)
    assert_cursor_on_correct_line "$stderr_output" "newline"
}

@test "list prompt: cursor shown after positioning" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    imenu_list "test_name" "Enter:" "test" 2>/dev/null >/dev/null
    
    assert_cursor_shown
}

@test "list prompt: cursor hidden during redraw" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    imenu_list "test_name" "Enter:" "a,b,c" 2>/dev/null >/dev/null
    
    assert_cursor_hidden
}

@test "list prompt: cursor positioned correctly for empty input" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    local stderr_output
    stderr_output=$(imenu_list "test_name" "Enter:" "" 2>&1 >/dev/null)
    
    # In newline mode with empty input, display is: "? "
    # Visible text length: "? " (2 chars)
    # Cursor should be positioned at column 2 (end of prompt, ready for input)
    assert_cursor_at_end "$stderr_output" "2"
    
    # Also verify cursor is on the correct line (vertical positioning)
    assert_cursor_on_correct_line "$stderr_output" "newline"
}

