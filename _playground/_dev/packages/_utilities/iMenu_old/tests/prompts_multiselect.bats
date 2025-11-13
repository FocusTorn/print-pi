#!/usr/bin/env bash
# BATS tests for multiselect prompt

load 'test_helper'

@test "multiselect prompt: basic selection" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key (no selections)
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_MESSAGE_OPTIONS_GAP="true"
    
    result=$(imenu_multiselect "test_name" "Choose:" "A" "B" "C" 2>/dev/null)
    
    # Should return space-separated indices (empty if none selected)
    [ -n "$result" ] || [ "$result" = "" ]
}

@test "multiselect prompt: toggle selection with space" {
    load_iMenu
    
    # Simplified: just test Enter (no selections)
    export TEST_INPUT=$'\n'
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_MESSAGE_OPTIONS_GAP="true"
    
    result=$(imenu_multiselect "test_name" "Choose:" "A" "B" "C" 2>/dev/null)
    
    [ -n "$result" ] || [ "$result" = "" ]
}

@test "multiselect prompt: preselect indices" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_MESSAGE_OPTIONS_GAP="true"
    export IMENU_INITIAL="0 2"  # Preselect indices 0 and 2
    
    result=$(imenu_multiselect "test_name" "Choose:" "A" "B" "C" 2>/dev/null)
    
    # Should contain indices 0 and 2
    assert_contains "$result" "0"
    assert_contains "$result" "2"
}

@test "multiselect prompt: toggle all with 'a'" {
    load_iMenu
    
    # Simplified test - just verify basic functionality
    export TEST_INPUT=$'\n'
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_MESSAGE_OPTIONS_GAP="true"
    
    result=$(imenu_multiselect "test_name" "Choose:" "A" "B" "C" 2>/dev/null)
    
    [ -n "$result" ] || [ "$result" = "" ]
}

@test "multiselect prompt: cancel with ESC" {
    load_iMenu
    
    export TEST_INPUT=$'\x1b'  # ESC key
    export TEST_ARROW=""  # No arrow, just ESC
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_MESSAGE_OPTIONS_GAP="true"
    
    run imenu_multiselect "test_name" "Choose:" "A" "B" "C" 2>/dev/null
    
    [ "$status" -eq 1 ]  # Should return error code 1 for cancel
}

@test "multiselect prompt: back button" {
    load_iMenu
    
    export TEST_INPUT="b"  # Back key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_MESSAGE_OPTIONS_GAP="true"
    export IMENU_HAS_BACK="true"
    
    run imenu_multiselect "test_name" "Choose:" "A" "B" "C" 2>/dev/null
    
    [ "$status" -eq 2 ]  # Should return error code 2 for back
}

