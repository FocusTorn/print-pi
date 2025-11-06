#!/usr/bin/env bash
# iMenu Core - Configuration System
# Centralized configuration for all iMenu flags and settings

# Default configuration values
# These can be overridden via environment variables or config functions

# Message and spacing configuration
_IMENU_CONFIG_NO_MESSAGE_BLANK="${IMENU_NO_MESSAGE_BLANK:-false}"
_IMENU_CONFIG_MESSAGE_OPTIONS_GAP="${IMENU_MESSAGE_OPTIONS_GAP:-false}"

# Display configuration
_IMENU_CONFIG_TITLE="${IMENU_TITLE:-}"
_IMENU_CONFIG_MESSAGE_PREFIX="${IMENU_MESSAGE_PREFIX:-}"

# Navigation configuration
_IMENU_CONFIG_HAS_BACK="${IMENU_HAS_BACK:-false}"
_IMENU_CONFIG_CLEAR_PREVIOUS="${IMENU_CLEAR_PREVIOUS:-0}"

# Input configuration
_IMENU_CONFIG_INITIAL="${IMENU_INITIAL:-}"
_IMENU_CONFIG_MIN="${IMENU_MIN:-}"
_IMENU_CONFIG_MAX="${IMENU_MAX:-}"
_IMENU_CONFIG_LIMIT="${IMENU_LIMIT:-}"
_IMENU_CONFIG_INPUT_INLINE="${IMENU_INPUT_INLINE:-false}"

# Get a config value
# Usage: imenu_config_get "NO_MESSAGE_BLANK"
imenu_config_get() {
    local key="$1"
    case "$key" in
        NO_MESSAGE_BLANK)
            echo "${_IMENU_CONFIG_NO_MESSAGE_BLANK}"
            ;;
        MESSAGE_OPTIONS_GAP)
            echo "${_IMENU_CONFIG_MESSAGE_OPTIONS_GAP}"
            ;;
        TITLE)
            echo "${_IMENU_CONFIG_TITLE}"
            ;;
        MESSAGE_PREFIX)
            echo "${_IMENU_CONFIG_MESSAGE_PREFIX}"
            ;;
        HAS_BACK)
            echo "${_IMENU_CONFIG_HAS_BACK}"
            ;;
        CLEAR_PREVIOUS)
            echo "${_IMENU_CONFIG_CLEAR_PREVIOUS}"
            ;;
        INITIAL)
            echo "${_IMENU_CONFIG_INITIAL}"
            ;;
        MIN)
            echo "${_IMENU_CONFIG_MIN}"
            ;;
        MAX)
            echo "${_IMENU_CONFIG_MAX}"
            ;;
        LIMIT)
            echo "${_IMENU_CONFIG_LIMIT}"
            ;;
        INPUT_INLINE)
            echo "${_IMENU_CONFIG_INPUT_INLINE}"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Set a config value
# Usage: imenu_config_set "NO_MESSAGE_BLANK" "true"
imenu_config_set() {
    local key="$1"
    local value="$2"
    case "$key" in
        NO_MESSAGE_BLANK)
            _IMENU_CONFIG_NO_MESSAGE_BLANK="$value"
            export IMENU_NO_MESSAGE_BLANK="$value"
            ;;
        MESSAGE_OPTIONS_GAP)
            _IMENU_CONFIG_MESSAGE_OPTIONS_GAP="$value"
            export IMENU_MESSAGE_OPTIONS_GAP="$value"
            ;;
        TITLE)
            _IMENU_CONFIG_TITLE="$value"
            export IMENU_TITLE="$value"
            ;;
        MESSAGE_PREFIX)
            _IMENU_CONFIG_MESSAGE_PREFIX="$value"
            export IMENU_MESSAGE_PREFIX="$value"
            ;;
        HAS_BACK)
            _IMENU_CONFIG_HAS_BACK="$value"
            export IMENU_HAS_BACK="$value"
            ;;
        CLEAR_PREVIOUS)
            _IMENU_CONFIG_CLEAR_PREVIOUS="$value"
            export IMENU_CLEAR_PREVIOUS="$value"
            ;;
        INITIAL)
            _IMENU_CONFIG_INITIAL="$value"
            export IMENU_INITIAL="$value"
            ;;
        MIN)
            _IMENU_CONFIG_MIN="$value"
            export IMENU_MIN="$value"
            ;;
        MAX)
            _IMENU_CONFIG_MAX="$value"
            export IMENU_MAX="$value"
            ;;
        LIMIT)
            _IMENU_CONFIG_LIMIT="$value"
            export IMENU_LIMIT="$value"
            ;;
        INPUT_INLINE)
            _IMENU_CONFIG_INPUT_INLINE="$value"
            export IMENU_INPUT_INLINE="$value"
            ;;
    esac
}

# Reset config to defaults
# Usage: imenu_config_reset
imenu_config_reset() {
    _IMENU_CONFIG_NO_MESSAGE_BLANK="false"
    _IMENU_CONFIG_MESSAGE_OPTIONS_GAP="false"
    _IMENU_CONFIG_TITLE=""
    _IMENU_CONFIG_MESSAGE_PREFIX=""
    _IMENU_CONFIG_HAS_BACK="false"
    _IMENU_CONFIG_CLEAR_PREVIOUS="0"
    _IMENU_CONFIG_INITIAL=""
    _IMENU_CONFIG_MIN=""
    _IMENU_CONFIG_MAX=""
    _IMENU_CONFIG_LIMIT=""
    _IMENU_CONFIG_INPUT_INLINE="false"
    
    # Also unset environment variables
    unset IMENU_NO_MESSAGE_BLANK
    unset IMENU_MESSAGE_OPTIONS_GAP
    unset IMENU_TITLE
    unset IMENU_MESSAGE_PREFIX
    unset IMENU_HAS_BACK
    unset IMENU_CLEAR_PREVIOUS
    unset IMENU_INITIAL
    unset IMENU_MIN
    unset IMENU_MAX
    unset IMENU_LIMIT
    unset IMENU_INPUT_INLINE
}

# Apply preset configurations
# Usage: imenu_config_preset "wizard" | "input" | "selection"
imenu_config_preset() {
    local preset="$1"
    case "$preset" in
        wizard)
            # Wizard mode: messages butted up, no gap by default
            imenu_config_set "NO_MESSAGE_BLANK" "true"
            imenu_config_set "MESSAGE_OPTIONS_GAP" "false"
            ;;
        input)
            # Input prompts: no blank after message, inline input
            imenu_config_set "NO_MESSAGE_BLANK" "true"
            imenu_config_set "MESSAGE_OPTIONS_GAP" "false"
            imenu_config_set "INPUT_INLINE" "true"
            ;;
        selection)
            # Selection prompts: gap before options (suppress blank after message, add before options)
            imenu_config_set "NO_MESSAGE_BLANK" "true"
            imenu_config_set "MESSAGE_OPTIONS_GAP" "true"
            ;;
        default|*)
            # Default: reset to defaults
            imenu_config_reset
            ;;
    esac
}

# Initialize config from environment variables (if set)
# This ensures environment variables override defaults
_imenu_config_init() {
    # Re-read from environment if set (allows runtime overrides)
    if [ -n "${IMENU_NO_MESSAGE_BLANK:-}" ]; then
        _IMENU_CONFIG_NO_MESSAGE_BLANK="${IMENU_NO_MESSAGE_BLANK}"
    fi
    if [ -n "${IMENU_MESSAGE_OPTIONS_GAP:-}" ]; then
        _IMENU_CONFIG_MESSAGE_OPTIONS_GAP="${IMENU_MESSAGE_OPTIONS_GAP}"
    fi
    if [ -n "${IMENU_TITLE:-}" ]; then
        _IMENU_CONFIG_TITLE="${IMENU_TITLE}"
    fi
    if [ -n "${IMENU_MESSAGE_PREFIX:-}" ]; then
        _IMENU_CONFIG_MESSAGE_PREFIX="${IMENU_MESSAGE_PREFIX}"
    fi
    if [ -n "${IMENU_HAS_BACK:-}" ]; then
        _IMENU_CONFIG_HAS_BACK="${IMENU_HAS_BACK}"
    fi
    if [ -n "${IMENU_CLEAR_PREVIOUS:-}" ]; then
        _IMENU_CONFIG_CLEAR_PREVIOUS="${IMENU_CLEAR_PREVIOUS}"
    fi
    if [ -n "${IMENU_INITIAL:-}" ]; then
        _IMENU_CONFIG_INITIAL="${IMENU_INITIAL}"
    fi
    if [ -n "${IMENU_MIN:-}" ]; then
        _IMENU_CONFIG_MIN="${IMENU_MIN}"
    fi
    if [ -n "${IMENU_MAX:-}" ]; then
        _IMENU_CONFIG_MAX="${IMENU_MAX}"
    fi
    if [ -n "${IMENU_LIMIT:-}" ]; then
        _IMENU_CONFIG_LIMIT="${IMENU_LIMIT}"
    fi
    if [ -n "${IMENU_INPUT_INLINE:-}" ]; then
        _IMENU_CONFIG_INPUT_INLINE="${IMENU_INPUT_INLINE}"
    fi
}

# Initialize on load
_imenu_config_init

