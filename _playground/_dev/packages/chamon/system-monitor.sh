#!/bin/bash

# System File Monitor - Detects ANY system file changes to prevent forgotten modifications
# Usage: system-monitor [command] [options]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
MOD_ZONE="/home/pi/3dp-mods"
MONITOR_DIR="$MOD_ZONE/system-monitor"
CHANGE_LOG="$MONITOR_DIR/change-log.txt"
SYSTEM_CHECKSUM="$MONITOR_DIR/system-checksums.txt"
CRITICAL_PATHS="/boot /etc /opt /usr/local /home/pi"
EXCLUDE_PATHS="/proc /sys /dev /tmp /var/log /var/cache /var/tmp /home/pi/Downloads /home/pi/.cache /home/pi/3dp-mods"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Logging functions
log_info() { #>
    echo -e "${BLUE}[INFO]${NC} $1"
} #<
log_warning() { #>
    echo -e "${YELLOW}[WARNING]${NC} $1"
} #<
log_error() { #>
    echo -e "${RED}[ERROR]${NC} $1"
} #<
log_success() { #>
    echo -e "${GREEN}[SUCCESS]${NC} $1"
} #<
log_dry_run() { #>
    echo -e "${PURPLE}[DRY-RUN]${NC} $1"
} #<

show_help() { #>
    echo -e "${CYAN}System File Monitor - Never Miss a System Change${NC}"
    echo -e "${CYAN}==============================================${NC}"
    echo
    echo "Usage: system-monitor [command] [options]"
    echo
    echo "Commands:"
    echo "  baseline     - Create baseline checksums of system files"
    echo "  check        - Check for any system file changes since baseline"
    echo "  track-new    - Automatically track newly detected changed files"
    echo "  report       - Generate detailed change report"
    echo "  reset        - Reset monitoring (clear baseline and logs)"
    echo "  status       - Show monitoring status and recent changes"
    echo "  help         - Show this help message"
    echo
    echo "Options:"
    echo "  --dry-run    - Show what would be executed without making changes"
    echo "  --force      - Force operation even if warnings occur"
    echo
    echo "Examples:"
    echo "  system-monitor baseline"
    echo "  system-monitor check --dry-run"
    echo "  system-monitor track-new"
    echo "  system-monitor report"
    echo
    echo "Purpose:"
    echo "  Detects ANY system file changes to prevent forgotten modifications"
    echo "  Automatically suggests tracking files you didn't plan to modify"
} #<

ensure_monitor_dir() { #>
    if [ ! -d "$MONITOR_DIR" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_dry_run "Would create directory: $MONITOR_DIR"
        else
            mkdir -p "$MONITOR_DIR"
            log_success "Created monitoring directory: $MONITOR_DIR"
        fi
    fi
} #<

create_baseline() { #>
    ensure_monitor_dir
    
    log_info "Creating baseline checksums of system files..."
    
    if [ "$DRY_RUN" = true ]; then
        log_dry_run "Would scan critical system paths: $CRITICAL_PATHS"
        log_dry_run "Would exclude paths: $EXCLUDE_PATHS"
        log_dry_run "Would create checksums file: $SYSTEM_CHECKSUM"
        return 0
    fi
    
    # Create checksums of all critical system files
    find $CRITICAL_PATHS -type f 2>/dev/null | while read -r file; do
        # Skip excluded paths
        local skip=false
        for exclude in $EXCLUDE_PATHS; do
            if [[ "$file" == "$exclude"* ]]; then
                skip=true
                break
            fi
        done
        
        if [ "$skip" = false ]; then
            # Only include files that are readable
            if [ -r "$file" ]; then
                local checksum=$(md5sum "$file" 2>/dev/null)
                if [ $? -eq 0 ]; then
                    echo "$checksum $file"
                fi
            fi
        fi
    done > "$SYSTEM_CHECKSUM"
    
    local file_count=$(wc -l < "$SYSTEM_CHECKSUM")
    log_success "Created baseline with $file_count system files"
    
    # Add to git if in repo
    if [ -d "$MOD_ZONE/.git" ]; then
        cd "$MOD_ZONE"
        git add "$SYSTEM_CHECKSUM"
        log_success "Added baseline to git"
    fi
} #<

check_changes() { #>
    if [ ! -f "$SYSTEM_CHECKSUM" ]; then
        log_error "No baseline found. Run 'system-monitor baseline' first."
        exit 1
    fi
    
    log_info "Checking for system file changes..."
    
    local changed_files=()
    local new_files=()
    local deleted_files=()
    
    # Check each file in baseline
    while IFS= read -r line; do
        local baseline_checksum=$(echo "$line" | cut -d' ' -f1)
        local file_path=$(echo "$line" | cut -d' ' -f3-)
        
        if [ -f "$file_path" ]; then
            local current_checksum=$(md5sum "$file_path" 2>/dev/null | cut -d' ' -f1)
            if [ "$baseline_checksum" != "$current_checksum" ]; then
                changed_files+=("$file_path")
            fi
        else
            deleted_files+=("$file_path")
        fi
    done < "$SYSTEM_CHECKSUM"
    
    # Find new files (not in baseline)
    find $CRITICAL_PATHS -type f 2>/dev/null | while read -r file; do
        local skip=false
        for exclude in $EXCLUDE_PATHS; do
            if [[ "$file" == "$exclude"* ]]; then
                skip=true
                break
            fi
        done
        
        if [ "$skip" = false ] && [ -r "$file" ]; then
            if ! grep -q " $file$" "$SYSTEM_CHECKSUM"; then
                echo "$file"
            fi
        fi
    done > "$MONITOR_DIR/new-files.tmp"
    
    if [ -f "$MONITOR_DIR/new-files.tmp" ]; then
        while IFS= read -r file; do
            new_files+=("$file")
        done < "$MONITOR_DIR/new-files.tmp"
        rm -f "$MONITOR_DIR/new-files.tmp"
    fi
    
    # Log changes
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "=== System Change Check: $timestamp ===" >> "$CHANGE_LOG"
    
    if [ ${#changed_files[@]} -gt 0 ]; then
        log_warning "Found ${#changed_files[@]} changed files:"
        for file in "${changed_files[@]}"; do
            echo "  CHANGED: $file"
            echo "CHANGED: $file ($timestamp)" >> "$CHANGE_LOG"
        done
    fi
    
    if [ ${#new_files[@]} -gt 0 ]; then
        log_warning "Found ${#new_files[@]} new files:"
        for file in "${new_files[@]}"; do
            echo "  NEW: $file"
            echo "NEW: $file ($timestamp)" >> "$CHANGE_LOG"
        done
    fi
    
    if [ ${#deleted_files[@]} -gt 0 ]; then
        log_warning "Found ${#deleted_files[@]} deleted files:"
        for file in "${deleted_files[@]}"; do
            echo "  DELETED: $file"
            echo "DELETED: $file ($timestamp)" >> "$CHANGE_LOG"
        done
    fi
    
    if [ ${#changed_files[@]} -eq 0 ] && [ ${#new_files[@]} -eq 0 ] && [ ${#deleted_files[@]} -eq 0 ]; then
        log_success "No system file changes detected"
    else
        local total_changes=$((${#changed_files[@]} + ${#new_files[@]} + ${#deleted_files[@]}))
        log_warning "Total changes detected: $total_changes"
        echo "Run 'system-monitor track-new' to automatically track changed files"
    fi
    
    echo "" >> "$CHANGE_LOG"
} #<

track_new_changes() { #>
    if [ ! -f "$CHANGE_LOG" ]; then
        log_error "No change log found. Run 'system-monitor check' first."
        exit 1
    fi
    
    log_info "Automatically tracking newly detected changed files..."
    
    local files_to_track=()
    
    # Get recently changed files from log
    tail -50 "$CHANGE_LOG" | grep -E "^(CHANGED|NEW):" | while read -r line; do
        local file_path=$(echo "$line" | cut -d' ' -f2)
        if [ -f "$file_path" ]; then
            files_to_track+=("$file_path")
        fi
    done
    
    if [ ${#files_to_track[@]} -eq 0 ]; then
        log_info "No files to track"
        return 0
    fi
    
    log_warning "Files that should be tracked:"
    for file in "${files_to_track[@]}"; do
        echo "  - $file"
    done
    
    if [ "$DRY_RUN" = true ]; then
        log_dry_run "Would run 'system-track add' for each file above"
        return 0
    fi
    
    echo -e "${YELLOW}[WARNING]${NC} This will add these files to system tracking."
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for file in "${files_to_track[@]}"; do
            log_info "Tracking: $file"
            system-track add "$file"
        done
        log_success "Automatically tracked ${#files_to_track[@]} files"
    else
        log_info "Tracking cancelled"
    fi
} #<

generate_report() { #>
    if [ ! -f "$CHANGE_LOG" ]; then
        log_error "No change log found. Run 'system-monitor check' first."
        exit 1
    fi
    
    echo -e "${BLUE}System File Change Report${NC}"
    echo -e "${BLUE}========================${NC}"
    echo
    
    # Show recent changes
    echo -e "${CYAN}Recent Changes (Last 20):${NC}"
    tail -20 "$CHANGE_LOG" | grep -E "^(CHANGED|NEW|DELETED):" | while read -r line; do
        local type=$(echo "$line" | cut -d':' -f1)
        local file=$(echo "$line" | cut -d':' -f2 | cut -d' ' -f1)
        local timestamp=$(echo "$line" | sed 's/.*(\(.*\)).*/\1/')
        
        case "$type" in
            "CHANGED") echo -e "${YELLOW}MODIFIED${NC} $file ($timestamp)" ;;
            "NEW") echo -e "${GREEN}CREATED${NC} $file ($timestamp)" ;;
            "DELETED") echo -e "${RED}DELETED${NC} $file ($timestamp)" ;;
        esac
    done
    
    echo
    
    # Show summary statistics
    local total_changes=$(grep -c "CHANGED:" "$CHANGE_LOG")
    local total_new=$(grep -c "NEW:" "$CHANGE_LOG")
    local total_deleted=$(grep -c "DELETED:" "$CHANGE_LOG")
    
    echo -e "${CYAN}Summary Statistics:${NC}"
    echo "  Total modified files: $total_changes"
    echo "  Total new files: $total_new"
    echo "  Total deleted files: $total_deleted"
    echo "  Total changes: $((total_changes + total_new + total_deleted))"
} #<

reset_monitoring() { #>
    if [ "$DRY_RUN" = true ]; then
        log_dry_run "Would remove: $SYSTEM_CHECKSUM"
        log_dry_run "Would remove: $CHANGE_LOG"
        return 0
    fi
    
    if [ "$FORCE" != true ]; then
        echo -e "${YELLOW}[WARNING]${NC} This will delete all monitoring data!"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Reset cancelled"
            return 0
        fi
    fi
    
    rm -f "$SYSTEM_CHECKSUM" "$CHANGE_LOG"
    log_success "Reset monitoring data"
} #<

show_status() { #>
    echo -e "${BLUE}System Monitor Status${NC}"
    echo -e "${BLUE}====================${NC}"
    echo
    
    if [ -f "$SYSTEM_CHECKSUM" ]; then
        local baseline_count=$(wc -l < "$SYSTEM_CHECKSUM")
        local baseline_date=$(stat -c %y "$SYSTEM_CHECKSUM" 2>/dev/null | cut -d' ' -f1)
        echo -e "${GREEN}✓${NC} Baseline exists: $baseline_count files (created: $baseline_date)"
    else
        echo -e "${RED}✗${NC} No baseline found - run 'system-monitor baseline'"
    fi
    
    if [ -f "$CHANGE_LOG" ]; then
        local change_count=$(wc -l < "$CHANGE_LOG")
        local last_check=$(tail -1 "$CHANGE_LOG" | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}' 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓${NC} Change log exists: $change_count entries (last check: $last_check)"
        
        # Show recent changes
        echo
        echo -e "${CYAN}Recent Changes:${NC}"
        tail -5 "$CHANGE_LOG" | grep -E "^(CHANGED|NEW|DELETED):" | while read -r line; do
            local type=$(echo "$line" | cut -d':' -f1)
            local file=$(echo "$line" | cut -d':' -f2 | cut -d' ' -f1)
            
            case "$type" in
                "CHANGED") echo -e "  ${YELLOW}MODIFIED${NC} $file" ;;
                "NEW") echo -e "  ${GREEN}CREATED${NC} $file" ;;
                "DELETED") echo -e "  ${RED}DELETED${NC} $file" ;;
            esac
        done
    else
        echo -e "${RED}✗${NC} No change log found"
    fi
} #<

# Main script logic
case "$1" in
    "baseline")
        create_baseline
        ;;
    "check")
        check_changes
        ;;
    "track-new")
        track_new_changes
        ;;
    "report")
        generate_report
        ;;
    "reset")
        reset_monitoring
        ;;
    "status")
        show_status
        ;;
    "help"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        echo -e "${RED}[ERROR]${NC} Unknown command: $1"
        echo "Run 'system-monitor help' for usage information"
        exit 1
        ;;
esac
