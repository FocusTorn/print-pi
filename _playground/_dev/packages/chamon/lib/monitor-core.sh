#!/bin/bash

# System Monitor Core Functions
# Modular functions for file change detection

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Configuration
CHANGE_LOG="$MONITOR_DIR/change-log.txt"
SYSTEM_CHECKSUM="$MONITOR_DIR/system-checksums.txt"
CRITICAL_PATHS="${CRITICAL_PATHS:-/boot /etc /opt /usr/local /home/pi}"
EXCLUDE_PATHS="${EXCLUDE_PATHS:-/proc /sys /dev /tmp /var/log /var/cache /var/tmp /home/pi/Downloads /home/pi/.cache /home/pi/3dp-mods}"

# Get list of changed files
get_changes() {
    ensure_directories
    
    if [ ! -f "$SYSTEM_CHECKSUM" ]; then
        log_error "No baseline found. Run create_baseline first."
        [ "$OUTPUT_MODE" = "json" ] && echo "[]"
        return 1
    fi
    
    local changes=()
    local timestamp=$(get_timestamp)
    
    # Build find exclude arguments
    local exclude_args=""
    for path in $EXCLUDE_PATHS; do
        exclude_args="$exclude_args -path $path -prune -o"
    done
    
    # Check each critical path
    for path in $CRITICAL_PATHS; do
        [ ! -e "$path" ] && continue
        
        while IFS= read -r file; do
            [ -f "$file" ] || continue
            
            local current_sum=$(sha256sum "$file" 2>/dev/null | awk '{print $1}')
            local baseline_sum=$(grep "^$file:" "$SYSTEM_CHECKSUM" | cut -d':' -f2)
            
            if [ -z "$baseline_sum" ]; then
                changes+=("NEW|$file|$timestamp")
            elif [ "$current_sum" != "$baseline_sum" ]; then
                changes+=("MODIFIED|$file|$timestamp")
            fi
        done < <(eval "find $path $exclude_args -type f -print" 2>/dev/null)
    done
    
    # Output based on mode
    if [ "$OUTPUT_MODE" = "json" ]; then
        json_array_start
        local first=true
        for change in "${changes[@]}"; do
            IFS='|' read -r type path timestamp <<< "$change"
            [ "$first" = false ] && echo ","
            first=false
            json_object \
                "type" "$type" \
                "path" "$path" \
                "timestamp" "$timestamp" \
                "status" "untracked"
        done
        json_array_end
    else
        for change in "${changes[@]}"; do
            echo "$change"
        done
    fi
}

# Create baseline of system files
create_baseline() {
    ensure_directories
    
    log_info "Creating baseline of system files..."
    
    local checksum_file="$SYSTEM_CHECKSUM.tmp"
    > "$checksum_file"
    
    # Build find exclude arguments
    local exclude_args=""
    for path in $EXCLUDE_PATHS; do
        exclude_args="$exclude_args -path $path -prune -o"
    done
    
    local file_count=0
    for path in $CRITICAL_PATHS; do
        [ ! -e "$path" ] && continue
        
        log_info "Scanning $path..."
        
        while IFS= read -r file; do
            [ -f "$file" ] || continue
            
            local checksum=$(sha256sum "$file" 2>/dev/null | awk '{print $1}')
            [ -n "$checksum" ] && echo "$file:$checksum" >> "$checksum_file"
            ((file_count++))
            
            # Progress indicator
            if [ $((file_count % 100)) -eq 0 ]; then
                log_info "Processed $file_count files..."
            fi
        done < <(eval "find $path $exclude_args -type f -print" 2>/dev/null)
    done
    
    mv "$checksum_file" "$SYSTEM_CHECKSUM"
    log_success "Baseline created with $file_count files"
    
    [ "$OUTPUT_MODE" = "json" ] && json_object "status" "success" "file_count" "$file_count"
}

# Get status information
get_status() {
    local baseline_exists=false
    local file_count=0
    local change_count=0
    local last_check="unknown"
    
    if [ -f "$SYSTEM_CHECKSUM" ]; then
        baseline_exists=true
        file_count=$(wc -l < "$SYSTEM_CHECKSUM")
    fi
    
    if [ -f "$CHANGE_LOG" ]; then
        change_count=$(wc -l < "$CHANGE_LOG")
        last_check=$(tail -1 "$CHANGE_LOG" | grep -o '[0-9]\{8\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}' 2>/dev/null || echo "unknown")
    fi
    
    if [ "$OUTPUT_MODE" = "json" ]; then
        json_object \
            "baseline_exists" "$baseline_exists" \
            "file_count" "$file_count" \
            "change_count" "$change_count" \
            "last_check" "$last_check"
    else
        echo "Baseline: $baseline_exists"
        echo "Files: $file_count"
        echo "Changes: $change_count"
        echo "Last check: $last_check"
    fi
}

