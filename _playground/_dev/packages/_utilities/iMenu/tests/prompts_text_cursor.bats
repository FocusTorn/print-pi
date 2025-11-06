#!/usr/bin/env bash
# BATS tests for cursor positioning in text prompt

load 'test_helper'

@test "text prompt: cursor positioned at end of initial value (newline mode)" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    # Capture stderr to check cursor positioning
    local stderr_output
    stderr_output=$(imenu_text "test_name" "Enter:" "Hello" 2>&1 >/dev/null)
    
    # In newline mode, display is: "? Hello"
    # Visible text length: "? " (2 chars) + "Hello" (5 chars) = 7 chars
    # Cursor should be positioned at column 7 (end of visible text)
    assert_cursor_at_end "$stderr_output" "7"
    
    # Also verify cursor is on the correct line (vertical positioning)
    assert_cursor_on_correct_line "$stderr_output" "newline"
}

@test "text prompt: cursor shown after positioning" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    imenu_text "test_name" "Enter:" "test" 2>/dev/null >/dev/null
    
    # Cursor should be shown
    assert_cursor_shown
}

@test "text prompt: cursor hidden during redraw" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    imenu_text "test_name" "Enter:" "test" 2>/dev/null >/dev/null
    
    # Cursor should be hidden (at least once during the process)
    assert_cursor_hidden
}

@test "text prompt: cursor positioned correctly for empty input (newline mode)" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    local stderr_output
    stderr_output=$(imenu_text "test_name" "Enter:" "" 2>&1 >/dev/null)
    
    # In newline mode with empty input, display is: "? "
    # Visible text length: "? " (2 chars)
    # Cursor should be positioned at column 2 (end of prompt, ready for input)
    assert_cursor_at_end "$stderr_output" "2"
    
    # Also verify cursor is on the correct line (vertical positioning)
    assert_cursor_on_correct_line "$stderr_output" "newline"
}

@test "text prompt: cursor positioned correctly in inline mode" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="true"
    
    local stderr_output
    stderr_output=$(imenu_text "test_name" "Enter name:" "John" 2>&1 >/dev/null)
    
    # In inline mode, display is: "Enter name: John"
    # Visible text length: "Enter name:" (11 chars) + space (1) + "John" (4 chars) = 16 chars
    # Cursor should be positioned at column 16 (end of visible text)
    # Note: ANSI color codes don't affect cursor positioning - only visible characters count
    assert_cursor_at_end "$stderr_output" "16"
    
    # Also verify cursor is on the correct line (vertical positioning)
    assert_cursor_on_correct_line "$stderr_output" "inline"
}

@test "text prompt: cursor positioned correctly for empty input in inline mode" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="true"
    
    local stderr_output
    stderr_output=$(imenu_text "test_name" "Enter name:" "" 2>&1 >/dev/null)
    
    # In inline mode with empty input, display is: "Enter name: "
    # Visible text length: "Enter name:" (11 chars) + space (1) = 12 chars
    # Cursor should be positioned at column 12 (end of message + space, ready for input)
    assert_cursor_at_end "$stderr_output" "12"
    
    # Also verify cursor is on the correct line (vertical positioning)
    assert_cursor_on_correct_line "$stderr_output" "inline"
}

