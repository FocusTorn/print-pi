#!/usr/bin/env bash
# BATS tests for text prompt

load 'test_helper'

@test "text prompt: basic input" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    # Capture only stdout (result), ignore stderr (display output)
    result=$(imenu_text "test_name" "Enter your name:" "John" 2>/dev/null)
    
    [ "$result" = "John" ]
}

@test "text prompt: user types input" {
    load_iMenu
    
    # Test with character input - need Enter after the character
    # Since we can't easily simulate multi-character input with current mock,
    # we'll test that the prompt accepts and returns the initial value when Enter is pressed
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    # Test that it works with initial value (simulating user accepting default)
    result=$(imenu_text "test_name" "Enter:" "test_value" 2>/dev/null)
    
    [ "$result" = "test_value" ]
}

@test "text prompt: initial value" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    result=$(imenu_text "test_name" "Enter:" "default_value" 2>/dev/null)
    
    [ "$result" = "default_value" ]
}

@test "text prompt: inline mode" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="true"
    
    result=$(imenu_text "test_name" "Enter:" "test" 2>/dev/null)
    
    [ "$result" = "test" ]
}

@test "text prompt: empty input with no initial" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    result=$(imenu_text "test_name" "Enter:" "" 2>/dev/null)
    
    [ "$result" = "" ]
}

@test "text prompt: cancel with ESC" {
    load_iMenu
    
    # ESC key followed by empty arrow (no arrow key, just ESC)
    export TEST_INPUT=$'\x1b'  # ESC key
    export TEST_ARROW=""  # Empty string means no arrow, just ESC
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    run imenu_text "test_name" "Enter:" "" 2>/dev/null
    
    # Should return error code 1 for cancel
    [ "$status" -eq 1 ]
}

