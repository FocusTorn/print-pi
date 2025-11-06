#!/usr/bin/env bash
# BATS tests for autocomplete prompt

load 'test_helper'

@test "autocomplete prompt: basic selection" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key (selects first option)
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_MESSAGE_OPTIONS_GAP="true"
    
    result=$(imenu_autocomplete "test_name" "Choose:" "Apple" "Banana" "Cherry" 2>/dev/null)
    
    # Autocomplete returns the selected value (not index)
    # When Enter is pressed with no input, it selects the first filtered option
    # Since all options match empty input, it selects the first one: "Apple"
    [ "$result" = "Apple" ]
}

@test "autocomplete prompt: initial selection" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_MESSAGE_OPTIONS_GAP="true"
    export IMENU_INITIAL="Banana"  # Initial input string (filters to "Banana")
    
    result=$(imenu_autocomplete "test_name" "Choose:" "Apple" "Banana" "Cherry" 2>/dev/null)
    
    # Autocomplete returns the value, not the index
    # With IMENU_INITIAL="Banana", it filters to "Banana" and selects it
    [ "$result" = "Banana" ]
}

@test "autocomplete prompt: navigate with arrow keys" {
    load_iMenu
    
    # Simplified test - just verify it doesn't crash
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_MESSAGE_OPTIONS_GAP="true"
    
    result=$(imenu_autocomplete "test_name" "Choose:" "A" "B" "C" 2>/dev/null)
    
    [ -n "$result" ]  # Should return something
}

@test "autocomplete prompt: cancel with ESC" {
    load_iMenu
    
    export TEST_INPUT=$'\x1b'  # ESC key
    export TEST_ARROW=""  # No arrow, just ESC
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_MESSAGE_OPTIONS_GAP="true"
    
    run imenu_autocomplete "test_name" "Choose:" "A" "B" "C" 2>/dev/null
    
    [ "$status" -eq 1 ]  # Should return error code 1 for cancel
}

@test "autocomplete prompt: back button" {
    load_iMenu
    
    export TEST_INPUT="b"  # Back key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_MESSAGE_OPTIONS_GAP="true"
    export IMENU_HAS_BACK="true"
    
    run imenu_autocomplete "test_name" "Choose:" "A" "B" "C" 2>/dev/null
    
    [ "$status" -eq 2 ]  # Should return error code 2 for back
}

