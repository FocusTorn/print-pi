#!/bin/bash

# Common Functions Library for ChaMon
# Shared utilities for system-monitor and system-tracker

# Configuration
export PLAYGROUND_DIR="${PLAYGROUND_DIR:-/home/pi/_playground}"
export MONITOR_DIR="$PLAYGROUND_DIR/system-monitor"
export SYSTEM_TRACK_DIR="$PLAYGROUND_DIR/system-files"
export TRACKING_LIST="$PLAYGROUND_DIR/.system-track-list"

# Output modes
export OUTPUT_MODE="${OUTPUT_MODE:-human}"  # human, json, quiet

# Colors for output (only used in human mode)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions for human output
log_info() {
    [ "$OUTPUT_MODE" = "human" ] && echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_warning() {
    [ "$OUTPUT_MODE" = "human" ] && echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    [ "$OUTPUT_MODE" = "human" ] && echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
    [ "$OUTPUT_MODE" = "human" ] && echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

# JSON output functions
json_escape() {
    local string="$1"
    # Escape backslashes, quotes, and newlines
    printf '%s' "$string" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g'
}

json_array_start() {
    [ "$OUTPUT_MODE" = "json" ] && echo "["
}

json_array_end() {
    [ "$OUTPUT_MODE" = "json" ] && echo "]"
}

json_object() {
    [ "$OUTPUT_MODE" != "json" ] && return
    
    local output="{"
    local first=true
    
    while [[ $# -gt 0 ]]; do
        local key="$1"
        local value="$2"
        shift 2
        
        if [ "$first" = true ]; then
            first=false
        else
            output+=","
        fi
        
        output+="\"$key\":\"$(json_escape "$value")\""
    done
    
    output+="}"
    echo "$output"
}

# Ensure required directories exist
ensure_directories() {
    mkdir -p "$MONITOR_DIR" "$SYSTEM_TRACK_DIR"
}

# Get timestamp in standard format
get_timestamp() {
    date '+%Y%m%d %H:%M:%S'
}

# Check if running in dry-run mode
is_dry_run() {
    [ "$DRY_RUN" = "true" ]
}

