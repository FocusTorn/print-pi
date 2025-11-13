#!/usr/bin/env bash
# BATS tests for number prompt

load 'test_helper'

@test "number prompt: basic input" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    result=$(imenu_number "test_name" "Enter age:" "25" 2>/dev/null)
    
    [ "$result" = "25" ]
}

@test "number prompt: initial value" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    result=$(imenu_number "test_name" "Enter:" "42" 2>/dev/null)
    
    [ "$result" = "42" ]
}

@test "number prompt: empty initial defaults to empty" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    # Empty initial should return empty string when Enter is pressed immediately
    result=$(imenu_number "test_name" "Enter:" "" 2>/dev/null)
    
    # Should return empty string for empty input with no initial
    [ "$result" = "" ]
}

@test "number prompt: cancel with ESC" {
    load_iMenu
    
    export TEST_INPUT=$'\x1b'  # ESC key
    export TEST_ARROW=""  # No arrow, just ESC
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    run imenu_number "test_name" "Enter:" "" 2>/dev/null
    
    [ "$status" -eq 1 ]  # Should return error code 1 for cancel
}

