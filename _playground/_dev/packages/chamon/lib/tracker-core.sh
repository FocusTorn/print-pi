#!/bin/bash

# System Tracker Core Functions
# Modular functions for git tracking of system files

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Add a system file to git tracking
track_file() {
    local system_file="$1"
    
    if [ -z "$system_file" ]; then
        log_error "No file specified"
        return 1
    fi
    
    # Convert to absolute path
    system_file=$(realpath "$system_file" 2>/dev/null)
    
    if [ ! -f "$system_file" ]; then
        log_error "File does not exist: $system_file"
        return 1
    fi
    
    # Check if already tracked by git
    if git ls-files --error-unmatch "$system_file" >/dev/null 2>&1; then
        log_warning "File already tracked by git: $system_file"
        [ "$OUTPUT_MODE" = "json" ] && json_object "status" "already_tracked" "path" "$system_file"
        return 0
    fi
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would add to git tracking: $system_file"
        log_info "[DRY-RUN] Would execute: git add '$system_file'"
        return 0
    fi
    
    # Add to git tracking
    git add "$system_file"
    
    if [ $? -eq 0 ]; then
        log_success "Now tracking in git: $system_file"
        [ "$OUTPUT_MODE" = "json" ] && json_object "status" "success" "path" "$system_file" "action" "git_tracked"
    else
        log_error "Failed to add to git tracking: $system_file"
        [ "$OUTPUT_MODE" = "json" ] && json_object "status" "error" "path" "$system_file"
        return 1
    fi
}

# Remove a system file from git tracking
untrack_file() {
    local system_file="$1"
    
    if [ -z "$system_file" ]; then
        log_error "No file specified"
        return 1
    fi
    
    # Convert to absolute path
    system_file=$(realpath "$system_file" 2>/dev/null)
    
    if [ ! -f "$system_file" ]; then
        log_error "File does not exist: $system_file"
        return 1
    fi
    
    # Check if file is tracked by git
    if ! git ls-files --error-unmatch "$system_file" >/dev/null 2>&1; then
        log_warning "File not tracked by git: $system_file"
        [ "$OUTPUT_MODE" = "json" ] && json_object "status" "not_tracked" "path" "$system_file"
        return 0
    fi
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would remove from git tracking: $system_file"
        log_info "[DRY-RUN] Would execute: git rm --cached '$system_file'"
        return 0
    fi
    
    # Remove from git tracking (but keep local file)
    git rm --cached "$system_file"
    
    if [ $? -eq 0 ]; then
        log_success "Removed from git tracking: $system_file"
        log_info "File remains in working directory. Commit and push to remove from remote."
        [ "$OUTPUT_MODE" = "json" ] && json_object "status" "success" "path" "$system_file" "action" "git_untracked"
    else
        log_error "Failed to remove from git tracking: $system_file"
        [ "$OUTPUT_MODE" = "json" ] && json_object "status" "error" "path" "$system_file"
        return 1
    fi
}

# List all git-tracked files
list_tracked() {
    if [ "$OUTPUT_MODE" = "json" ]; then
        json_array_start
        local first=true
        git ls-files | while IFS= read -r file; do
            [ -z "$file" ] && continue
            [ "$first" = false ] && echo ","
            first=false
            
            local status="tracked"
            [ ! -f "$file" ] && status="missing"
            
            json_object "path" "$file" "status" "$status"
        done
        json_array_end
    else
        git ls-files
    fi
}

# Check status of git-tracked files
check_tracked_status() {
    if [ "$OUTPUT_MODE" = "json" ]; then
        json_array_start
        local first=true
        git ls-files | while IFS= read -r file; do
            [ -z "$file" ] && continue
            [ "$first" = false ] && echo ","
            first=false
            
            local status="ok"
            if [ ! -f "$file" ]; then
                status="missing"
            elif git status --porcelain "$file" | grep -q "^.M"; then
                status="modified"
            elif git status --porcelain "$file" | grep -q "^M"; then
                status="staged"
            fi
            
            json_object "path" "$file" "status" "$status"
        done
        json_array_end
    else
        git ls-files | while IFS= read -r file; do
            [ -z "$file" ] && continue
            echo -n "$file: "
            
            if [ ! -f "$file" ]; then
                echo "MISSING"
            elif git status --porcelain "$file" | grep -q "^.M"; then
                echo "MODIFIED"
            elif git status --porcelain "$file" | grep -q "^M"; then
                echo "STAGED"
            else
                echo "OK"
            fi
        done
    fi
}

