#!/usr/bin/env bash
# BATS tests for list prompt

load 'test_helper'

@test "list prompt: basic input" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    result=$(imenu_list "test_name" "Enter items:" "item1,item2" 2>/dev/null)
    
    # List prompt splits by separator and returns space-separated
    # "item1,item2" becomes "item1 item2"
    assert_contains "$result" "item1"
    assert_contains "$result" "item2"
}

@test "list prompt: empty initial" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    result=$(imenu_list "test_name" "Enter items:" "" 2>/dev/null)
    
    [ "$result" = "" ]
}

@test "list prompt: custom separator" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    result=$(imenu_list "test_name" "Enter items:" "a;b;c" ";" 2>/dev/null)
    
    # List prompt splits by separator and returns space-separated
    assert_contains "$result" "a"
    assert_contains "$result" "b"
    assert_contains "$result" "c"
}

@test "list prompt: cancel with ESC" {
    load_iMenu
    
    export TEST_INPUT=$'\x1b'  # ESC key
    export TEST_ARROW=""  # No arrow, just ESC
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    
    run imenu_list "test_name" "Enter items:" "" 2>/dev/null
    
    [ "$status" -eq 1 ]  # Should return error code 1 for cancel
}

@test "list prompt: back button" {
    load_iMenu
    
    export TEST_INPUT="b"  # Back key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_INPUT_INLINE="false"
    export IMENU_HAS_BACK="true"
    
    run imenu_list "test_name" "Enter items:" "" 2>/dev/null
    
    [ "$status" -eq 2 ]  # Should return error code 2 for back
}

