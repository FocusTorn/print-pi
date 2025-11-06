#!/usr/bin/env bash
# BATS tests for cursor positioning in date prompt (newline mode)

load 'test_helper'

@test "date prompt: cursor shown (date prompt uses show_cursor)" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    imenu_date "test_name" "Enter date:" "2024-01-01 12:00:00" 2>/dev/null >/dev/null
    
    # Date prompt shows cursor (it's an input prompt)
    assert_cursor_shown
}

@test "date prompt: cursor shown for empty initial" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    imenu_date "test_name" "Enter date:" "" 2>/dev/null >/dev/null
    
    # Date prompt shows cursor
    assert_cursor_shown
}

@test "date prompt: cursor shown at end" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    imenu_date "test_name" "Enter date:" "2024-12-31 23:59:59" 2>/dev/null >/dev/null
    
    # Date prompt shows cursor (it's an input prompt)
    assert_cursor_shown
}

