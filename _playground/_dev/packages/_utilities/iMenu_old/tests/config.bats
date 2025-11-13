#!/usr/bin/env bash
# Example BATS test file for iMenu
# Install bats: https://github.com/bats-core/bats-core

load 'test_helper'

@test "config system: get default values" {
    load_iMenu
    
    run imenu_config_get "NO_MESSAGE_BLANK"
    [ "$status" -eq 0 ]
    [ "$output" = "false" ]
}

@test "config system: set and get value" {
    load_iMenu
    
    imenu_config_set "NO_MESSAGE_BLANK" "true"
    run imenu_config_get "NO_MESSAGE_BLANK"
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "config system: preset input" {
    load_iMenu
    
    imenu_config_preset "input"
    run imenu_config_get "NO_MESSAGE_BLANK"
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
    
    run imenu_config_get "INPUT_INLINE"
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "config system: preset selection" {
    load_iMenu
    
    imenu_config_preset "selection"
    run imenu_config_get "MESSAGE_OPTIONS_GAP"
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "config system: reset to defaults" {
    load_iMenu
    
    imenu_config_set "NO_MESSAGE_BLANK" "true"
    imenu_config_reset
    run imenu_config_get "NO_MESSAGE_BLANK"
    [ "$status" -eq 0 ]
    [ "$output" = "false" ]
}

