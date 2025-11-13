#!/usr/bin/env bash
# BATS tests for invisible prompt

load 'test_helper'

@test "invisible prompt: basic input" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    result=$(imenu_invisible "test_name" "Enter secret:" "hidden" 2>/dev/null)
    
    [ "$result" = "hidden" ]
}

@test "invisible prompt: empty initial" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    result=$(imenu_invisible "test_name" "Enter secret:" "" 2>/dev/null)
    
    [ "$result" = "" ]
}

@test "invisible prompt: cancel with ESC" {
    load_iMenu
    
    export TEST_INPUT=$'\x1b'  # ESC key
    export TEST_ARROW=""  # No arrow, just ESC
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    run imenu_invisible "test_name" "Enter secret:" "" 2>/dev/null
    
    [ "$status" -eq 1 ]  # Should return error code 1 for cancel
}

@test "invisible prompt: back button" {
    load_iMenu
    
    export TEST_INPUT="b"  # Back key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    export IMENU_HAS_BACK="true"
    
    run imenu_invisible "test_name" "Enter secret:" "" 2>/dev/null
    
    [ "$status" -eq 2 ]  # Should return error code 2 for back
}

