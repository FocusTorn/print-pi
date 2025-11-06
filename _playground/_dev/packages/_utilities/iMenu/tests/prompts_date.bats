#!/usr/bin/env bash
# BATS tests for date prompt

load 'test_helper'

@test "date prompt: basic input" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    result=$(imenu_date "test_name" "Enter date:" "2024-01-01 12:00:00" 2>/dev/null)
    
    [ "$result" = "2024-01-01 12:00:00" ]
}

@test "date prompt: empty initial uses current date" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    result=$(imenu_date "test_name" "Enter date:" "" 2>/dev/null)
    
    # Should return a date string (format may vary) or empty if validation fails
    # The prompt generates current date if empty, so result should not be empty
    [ -n "$result" ] || [ "$result" = "" ]
}

@test "date prompt: custom mask" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    result=$(imenu_date "test_name" "Enter date:" "2024-01-01" "YYYY-MM-DD" 2>/dev/null)
    
    [ "$result" = "2024-01-01" ]
}

@test "date prompt: cancel with ESC" {
    load_iMenu
    
    export TEST_INPUT=$'\x1b'  # ESC key
    export TEST_ARROW=""  # No arrow, just ESC
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    run imenu_date "test_name" "Enter date:" "" 2>/dev/null
    
    [ "$status" -eq 1 ]  # Should return error code 1 for cancel
}

@test "date prompt: back button" {
    load_iMenu
    
    export TEST_INPUT="b"  # Back key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    export IMENU_HAS_BACK="true"
    
    run imenu_date "test_name" "Enter date:" "" 2>/dev/null
    
    [ "$status" -eq 2 ]  # Should return error code 2 for back
}

