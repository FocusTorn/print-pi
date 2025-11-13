#!/usr/bin/env bash
# BATS tests for confirm prompt

load 'test_helper'

@test "confirm prompt: default false" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key (confirms false)
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_MESSAGE_OPTIONS_GAP="true"
    
    result=$(imenu_confirm "test_name" "Do you agree?" "false" 2>/dev/null)
    
    # Enter confirms the current state (false)
    [ "$result" = "false" ] || [ "$result" = "" ]
}

@test "confirm prompt: default true" {
    load_iMenu
    
    export TEST_INPUT=$'\n'  # Enter key (confirms true)
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_MESSAGE_OPTIONS_GAP="true"
    
    result=$(imenu_confirm "test_name" "Do you agree?" "true" 2>/dev/null)
    
    # Enter confirms the current state (true)
    [ "$result" = "true" ] || [ "$result" = "" ]
}

@test "confirm prompt: y/Y selects yes" {
    load_iMenu
    
    export TEST_INPUT="y"  # 'y' key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_MESSAGE_OPTIONS_GAP="true"
    
    result=$(imenu_confirm "test_name" "Do you agree?" "false" 2>/dev/null)
    
    [ "$result" = "true" ]
}

@test "confirm prompt: n/N selects no" {
    load_iMenu
    
    export TEST_INPUT="n"  # 'n' key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_MESSAGE_OPTIONS_GAP="true"
    
    result=$(imenu_confirm "test_name" "Do you agree?" "true" 2>/dev/null)
    
    [ "$result" = "false" ]
}

@test "confirm prompt: select Yes option" {
    load_iMenu
    
    # Down arrow to select "Yes", then Enter
    export TEST_INPUT=$'\n'  # Enter key (selects first option)
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_MESSAGE_OPTIONS_GAP="true"
    
    result=$(imenu_confirm "test_name" "Do you agree?" "false" 2>/dev/null)
    
    # Should return false (first option is "No" when initial is false)
    [ "$result" = "false" ] || [ "$result" = "" ]
}

@test "confirm prompt: cancel with ESC" {
    load_iMenu
    
    export TEST_INPUT=$'\x1b'  # ESC key
    export TEST_ARROW=""  # No arrow, just ESC
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_MESSAGE_OPTIONS_GAP="true"
    
    run imenu_confirm "test_name" "Do you agree?" "false" 2>/dev/null
    
    [ "$status" -eq 1 ]  # Should return error code 1 for cancel
}

@test "confirm prompt: back button" {
    load_iMenu
    
    export TEST_INPUT="b"  # Back key
    export IMENU_NO_MESSAGE_BLANK="true"
    export IMENU_MESSAGE_OPTIONS_GAP="true"
    export IMENU_HAS_BACK="true"
    
    run imenu_confirm "test_name" "Do you agree?" "false" 2>/dev/null
    
    [ "$status" -eq 2 ]  # Should return error code 2 for back
}

