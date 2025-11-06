#!/usr/bin/env bash
# Logger library for bash/zsh scripts
# Inspired by TypeScript logger pattern

# Logger state
_LOGGER_DEBUG_ENABLED=false
_LOGGER_SCOPE=""

# Colors (only use if output is a TTY)
if [ -t 1 ]; then
    _LOGGER_USE_COLORS=true
    _LOGGER_RESET='\033[0m'
    _LOGGER_BOLD='\033[1m'
    _LOGGER_WHITE='\033[0;37m'
    _LOGGER_GREEN='\033[0;32m'
    _LOGGER_RED='\033[0;31m'
    _LOGGER_YELLOW='\033[0;33m'
    _LOGGER_BLUE='\033[0;34m'
    _LOGGER_PURPLE='\033[0;35m'
else
    _LOGGER_USE_COLORS=false
    _LOGGER_RESET=''
    _LOGGER_BOLD=''
    _LOGGER_WHITE=''
    _LOGGER_GREEN=''
    _LOGGER_RED=''
    _LOGGER_YELLOW=''
    _LOGGER_BLUE=''
    _LOGGER_PURPLE=''
fi

# Symbols/Emojis
_LOGGER_SYMBOL_DEBUG="👾"
_LOGGER_SYMBOL_INFO="ℹ️ "
_LOGGER_SYMBOL_SUCCESS="✅"
_LOGGER_SYMBOL_WARN="⚠️ "
_LOGGER_SYMBOL_ERROR="❌"
_LOGGER_SYMBOL_LOADING="🔄"

# Initialize logger with scope
# Usage: logger_init "package-name"
logger_init() {
    _LOGGER_SCOPE="[$1]"
}

# Enable or disable debug mode
# Usage: logger_set_debug true
logger_set_debug() {
    if [ "$1" = "true" ] || [ "$1" = "1" ]; then
        _LOGGER_DEBUG_ENABLED=true
    else
        _LOGGER_DEBUG_ENABLED=false
    fi
}

# Get current timestamp (milliseconds)
_get_timestamp() {
    if command -v date >/dev/null 2>&1; then
        date +%s%3N 2>/dev/null || date +%s
    else
        echo "0"
    fi
}

# Format message with scope and color
_format_message() {
    local level=$1
    local symbol=$2
    local color=$3
    local message=$4
    if [ "$_LOGGER_USE_COLORS" = "true" ] && [ -n "$color" ]; then
        echo -e "${color}${symbol}${_LOGGER_RESET} ${_LOGGER_SCOPE}: ${message}"
    else
        echo "${symbol} ${_LOGGER_SCOPE}: ${message}"
    fi
}

# Debug message (only shown if debug enabled)
logger_debug() {
    if [ "$_LOGGER_DEBUG_ENABLED" = "true" ]; then
        _format_message "DEBUG" "$_LOGGER_SYMBOL_DEBUG" "$_LOGGER_PURPLE" "$*"
    fi
}

# Info message
logger_info() {
    _format_message "INFO" "$_LOGGER_SYMBOL_INFO" "$_LOGGER_BLUE" "$*"
}

# Success message
logger_success() {
    _format_message "SUCCESS" "$_LOGGER_SYMBOL_SUCCESS" "$_LOGGER_GREEN" "$*"
}

# Warning message
logger_warn() {
    _format_message "WARN" "$_LOGGER_SYMBOL_WARN" "$_LOGGER_YELLOW" "$*" >&2
}

# Error message
logger_error() {
    _format_message "ERROR" "$_LOGGER_SYMBOL_ERROR" "$_LOGGER_RED" "$*" >&2
}

# Loading indicator with command execution
# Usage: logger_loading "Installing packages..." command arg1 arg2
logger_loading() {
    local message="$1"
    shift  # Remove first argument, rest are the command
    local cmd="$*"
    
    # Check if output is a TTY for spinner
    if [ -t 1 ]; then
        local spinner_symbols=("      🐳" "    🐳  " "  🐳    " "🐳      ")
        local spinner_index=0
        local spinner_pid=""
        local start_time=$(date +%s)
        
        # Start spinner in background
        (
            while true; do
                printf "\r${_LOGGER_SYMBOL_LOADING} ${_LOGGER_SCOPE}: ${spinner_symbols[$spinner_index]}"
                spinner_index=$(((spinner_index + 1) % ${#spinner_symbols[@]}))
                sleep 0.25
            done
        ) &
        spinner_pid=$!
        
        # Execute command and capture result
        local cmd_output
        local cmd_exit=0
        cmd_output=$($cmd 2>&1) || cmd_exit=$?
        
        # Stop spinner
        kill $spinner_pid 2>/dev/null
        wait $spinner_pid 2>/dev/null
        
        # Calculate duration
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Show result
        if [ $cmd_exit -eq 0 ]; then
            if [ "$_LOGGER_USE_COLORS" = "true" ]; then
                printf "\r${_LOGGER_GREEN}${_LOGGER_SYMBOL_SUCCESS}${_LOGGER_RESET} ${_LOGGER_SCOPE}: ${message} (${duration}s)\n"
            else
                printf "\r${_LOGGER_SYMBOL_SUCCESS} ${_LOGGER_SCOPE}: ${message} (${duration}s)\n"
            fi
        else
            if [ "$_LOGGER_USE_COLORS" = "true" ]; then
                printf "\r${_LOGGER_RED}${_LOGGER_SYMBOL_ERROR}${_LOGGER_RESET} ${_LOGGER_SCOPE}: ${message} (${duration}s)\n"
            else
                printf "\r${_LOGGER_SYMBOL_ERROR} ${_LOGGER_SCOPE}: ${message} (${duration}s)\n"
            fi
            echo "$cmd_output" >&2
        fi
        
        return $cmd_exit
    else
        # Non-TTY: simple output
        printf "${_LOGGER_SYMBOL_LOADING} ${_LOGGER_SCOPE}: ${message}..."
        if $cmd >/dev/null 2>&1; then
            printf " ${_LOGGER_SYMBOL_SUCCESS} Success\n"
            return 0
        else
            printf " ${_LOGGER_SYMBOL_ERROR} Failure\n"
            return 1
        fi
    fi
}

# Alternative loading function that takes a function/code block
# Usage: logger_loading_block "Message" 'command; another_command;'
logger_loading_block() {
    local message="$1"
    local code_block="$2"
    
    if [ -t 1 ]; then
        local spinner_symbols=("      🐳" "    🐳  " "  🐳    " "🐳      ")
        local spinner_index=0
        local spinner_pid=""
        local start_time=$(date +%s)
        
        # Start spinner
        (
            while true; do
                printf "\r${_LOGGER_SYMBOL_LOADING} ${_LOGGER_SCOPE}: ${spinner_symbols[$spinner_index]}"
                spinner_index=$(((spinner_index + 1) % ${#spinner_symbols[@]}))
                sleep 0.25
            done
        ) &
        spinner_pid=$!
        
        # Execute code block
        local cmd_exit=0
        eval "$code_block" 2>&1 || cmd_exit=$?
        
        # Stop spinner
        kill $spinner_pid 2>/dev/null
        wait $spinner_pid 2>/dev/null
        
        # Calculate duration
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Show result
        if [ $cmd_exit -eq 0 ]; then
            if [ "$_LOGGER_USE_COLORS" = "true" ]; then
                printf "\r${_LOGGER_GREEN}${_LOGGER_SYMBOL_SUCCESS}${_LOGGER_RESET} ${_LOGGER_SCOPE}: ${message} (${duration}s)\n"
            else
                printf "\r${_LOGGER_SYMBOL_SUCCESS} ${_LOGGER_SCOPE}: ${message} (${duration}s)\n"
            fi
        else
            if [ "$_LOGGER_USE_COLORS" = "true" ]; then
                printf "\r${_LOGGER_RED}${_LOGGER_SYMBOL_ERROR}${_LOGGER_RESET} ${_LOGGER_SCOPE}: ${message} (${duration}s)\n"
            else
                printf "\r${_LOGGER_SYMBOL_ERROR} ${_LOGGER_SCOPE}: ${message} (${duration}s)\n"
            fi
        fi
        
        return $cmd_exit
    else
        # Non-TTY: simple output
        printf "${_LOGGER_SYMBOL_LOADING} ${_LOGGER_SCOPE}: ${message}..."
        if eval "$code_block" >/dev/null 2>&1; then
            printf " ${_LOGGER_SYMBOL_SUCCESS} Success\n"
            return 0
        else
            printf " ${_LOGGER_SYMBOL_ERROR} Failure\n"
            return 1
        fi
    fi
}
