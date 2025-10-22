#!/bin/bash

# System File Tracker - Ensures critical system files are never forgotten
# Usage: system-track [command] [options]

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
SYSTEM_TRACK_DIR="$MOD_ZONE/system-files"
TRACKING_LIST="$MOD_ZONE/.system-track-list"
DRY_RUN=false

# Parse command line arguments for --dry-run
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Logging function for dry-run
log_dry_run() {
    echo -e "${PURPLE}[DRY-RUN]${NC} $1"
}

# Function to show help
show_help() {
    echo -e "${CYAN}System File Tracker - Never Lose Track of System Changes${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo
    echo "Usage: system-track [command] [options]"
    echo
    echo "Commands:"
    echo "  add <file>     - Start tracking a system file"
    echo "  remove <file>  - Stop tracking a system file"
    echo "  list           - Show all tracked system files"
    echo "  status         - Check status of all tracked files"
    echo "  sync           - Sync all tracked files with git"
    echo "  restore <file> - Restore a tracked file from git"
    echo "  help           - Show this help message"
    echo
    echo "Options:"
    echo "  --dry-run      - Show what would be executed without making changes"
    echo
    echo "Examples:"
    echo "  system-track add /boot/firmware/config.txt"
    echo "  system-track add /etc/hosts"
    echo "  system-track status --dry-run"
    echo "  system-track sync"
    echo
    echo "Purpose:"
    echo "  Ensures critical system files are never forgotten and always tracked"
    echo "  Creates symlinks in mod-zone so system files can be git-tracked"
}

# Function to ensure tracking directory exists
ensure_tracking_dir() {
    if [ ! -d "$SYSTEM_TRACK_DIR" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_dry_run "Would create directory: $SYSTEM_TRACK_DIR"
        else
            mkdir -p "$SYSTEM_TRACK_DIR"
            echo -e "${GREEN}[SUCCESS]${NC} Created tracking directory: $SYSTEM_TRACK_DIR"
        fi
    fi
}

# Function to add a system file to tracking
add_system_file() {
    local system_file="$1"
    
    if [ -z "$system_file" ]; then
        echo -e "${RED}[ERROR]${NC} Please provide a system file path"
        echo "Usage: system-track add /path/to/system/file"
        exit 1
    fi
    
    # Check if file exists
    if [ ! -e "$system_file" ]; then
        echo -e "${RED}[ERROR]${NC} System file does not exist: $system_file"
        exit 1
    fi
    
    # Get filename for symlink
    local filename=$(basename "$system_file")
    local symlink_path="$SYSTEM_TRACK_DIR/$filename"
    
    ensure_tracking_dir
    
    # Check if already tracked
    if [ -L "$symlink_path" ]; then
        echo -e "${YELLOW}[WARNING]${NC} File already tracked: $system_file"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_dry_run "Would create symlink: $symlink_path -> $system_file"
        log_dry_run "Would add to tracking list: $system_file"
        log_dry_run "Would add to git: $symlink_path"
    else
        # Create symlink
        ln -s "$system_file" "$symlink_path"
        echo -e "${GREEN}[SUCCESS]${NC} Created symlink: $symlink_path -> $system_file"
        
        # Add to tracking list
        echo "$system_file" >> "$TRACKING_LIST"
        echo -e "${GREEN}[SUCCESS]${NC} Added to tracking list: $system_file"
        
        # Add to git if in git repo
        if [ -d "$MOD_ZONE/.git" ]; then
            cd "$MOD_ZONE"
            git add "$symlink_path"
            git add "$TRACKING_LIST"
            echo -e "${GREEN}[SUCCESS]${NC} Added to git: $symlink_path"
        fi
        
        echo -e "${CYAN}[INFO]${NC} System file is now tracked and will be committed to git"
    fi
}

# Function to remove a system file from tracking
remove_system_file() {
    local system_file="$1"
    
    if [ -z "$system_file" ]; then
        echo -e "${RED}[ERROR]${NC} Please provide a system file path"
        echo "Usage: system-track remove /path/to/system/file"
        exit 1
    fi
    
    local filename=$(basename "$system_file")
    local symlink_path="$SYSTEM_TRACK_DIR/$filename"
    
    if [ "$DRY_RUN" = true ]; then
        if [ -L "$symlink_path" ]; then
            log_dry_run "Would remove symlink: $symlink_path"
            log_dry_run "Would remove from tracking list: $system_file"
            log_dry_run "Would remove from git: $symlink_path"
        else
            log_dry_run "File not tracked: $system_file"
        fi
    else
        if [ -L "$symlink_path" ]; then
            # Remove symlink
            rm "$symlink_path"
            echo -e "${GREEN}[SUCCESS]${NC} Removed symlink: $symlink_path"
            
            # Remove from tracking list
            grep -v "^$system_file$" "$TRACKING_LIST" > "$TRACKING_LIST.tmp" && mv "$TRACKING_LIST.tmp" "$TRACKING_LIST"
            echo -e "${GREEN}[SUCCESS]${NC} Removed from tracking list: $system_file"
            
            # Remove from git if in git repo
            if [ -d "$MOD_ZONE/.git" ]; then
                cd "$MOD_ZONE"
                git rm --cached "$symlink_path" 2>/dev/null
                git add "$TRACKING_LIST"
                echo -e "${GREEN}[SUCCESS]${NC} Removed from git: $symlink_path"
            fi
        else
            echo -e "${YELLOW}[WARNING]${NC} File not tracked: $system_file"
        fi
    fi
}

# Function to list all tracked files
list_tracked_files() {
    if [ ! -f "$TRACKING_LIST" ]; then
        echo -e "${YELLOW}[INFO]${NC} No system files are being tracked"
        return 0
    fi
    
    echo -e "${BLUE}Tracked System Files:${NC}"
    echo -e "${BLUE}====================${NC}"
    
    while IFS= read -r system_file; do
        if [ -n "$system_file" ]; then
            local filename=$(basename "$system_file")
            local symlink_path="$SYSTEM_TRACK_DIR/$filename"
            
            if [ -L "$symlink_path" ]; then
                echo -e "${GREEN}✓${NC} $system_file -> $symlink_path"
            else
                echo -e "${RED}✗${NC} $system_file (symlink missing)"
            fi
        fi
    done < "$TRACKING_LIST"
}

# Function to check status of all tracked files
check_status() {
    if [ ! -f "$TRACKING_LIST" ]; then
        echo -e "${YELLOW}[INFO]${NC} No system files are being tracked"
        return 0
    fi
    
    echo -e "${BLUE}System File Tracking Status:${NC}"
    echo -e "${BLUE}=============================${NC}"
    
    local tracked_count=0
    local missing_count=0
    local changed_count=0
    
    while IFS= read -r system_file; do
        if [ -n "$system_file" ]; then
            local filename=$(basename "$system_file")
            local symlink_path="$SYSTEM_TRACK_DIR/$filename"
            
            if [ -e "$system_file" ]; then
                if [ -L "$symlink_path" ]; then
                    tracked_count=$((tracked_count + 1))
                    echo -e "${GREEN}✓${NC} $system_file (tracked)"
                    
                    # Check if file has been modified since last commit
                    if [ -d "$MOD_ZONE/.git" ]; then
                        cd "$MOD_ZONE"
                        if ! git diff --quiet "$symlink_path" 2>/dev/null; then
                            echo -e "    ${YELLOW}→ File has been modified${NC}"
                            changed_count=$((changed_count + 1))
                        fi
                    fi
                else
                    echo -e "${RED}✗${NC} $system_file (not tracked - symlink missing)"
                    missing_count=$((missing_count + 1))
                fi
            else
                echo -e "${RED}✗${NC} $system_file (file does not exist)"
                missing_count=$((missing_count + 1))
            fi
        fi
    done < "$TRACKING_LIST"
    
    echo
    echo -e "${CYAN}Summary:${NC}"
    echo "  Tracked: $tracked_count"
    echo "  Missing: $missing_count"
    echo "  Modified: $changed_count"
    
    if [ $changed_count -gt 0 ]; then
        echo -e "${YELLOW}[WARNING]${NC} You have $changed_count modified system files that need to be committed!"
        echo -e "${CYAN}[INFO]${NC} Run 'system-track sync' to commit changes"
    fi
}

# Function to sync all tracked files with git
sync_tracked_files() {
    if [ ! -d "$MOD_ZONE/.git" ]; then
        echo -e "${RED}[ERROR]${NC} Not in a git repository. Run 'doGit init' first."
        exit 1
    fi
    
    cd "$MOD_ZONE"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[INFO]${NC} DRY-RUN: Would sync tracked system files..."
        
        # Show what would be added
        local staged_files=$(git diff --cached --name-only)
        local unstaged_files=$(git diff --name-only)
        
        if [ -n "$staged_files" ]; then
            log_dry_run "Files already staged:"
            echo "$staged_files" | while read -r file; do
                log_dry_run "  - $file"
            done
        fi
        
        if [ -n "$unstaged_files" ]; then
            log_dry_run "Files that would be staged:"
            echo "$unstaged_files" | while read -r file; do
                log_dry_run "  - $file"
            done
        fi
        
        log_dry_run "Would execute: git add -A"
        log_dry_run "Would execute: git commit -m 'Auto-commit: Update tracked system files'"
    else
        echo -e "${YELLOW}[INFO]${NC} Syncing tracked system files..."
        
        # Add all changes
        git add -A
        
        # Check if there are changes to commit
        if [ -n "$(git diff --cached --name-only)" ]; then
            git commit -m "Auto-commit: Update tracked system files"
            echo -e "${GREEN}[SUCCESS]${NC} Committed tracked system file changes"
        else
            echo -e "${YELLOW}[INFO]${NC} No changes to commit"
        fi
    fi
}

# Function to restore a tracked file from git
restore_file() {
    local system_file="$1"
    
    if [ -z "$system_file" ]; then
        echo -e "${RED}[ERROR]${NC} Please provide a system file path"
        echo "Usage: system-track restore /path/to/system/file"
        exit 1
    fi
    
    local filename=$(basename "$system_file")
    local symlink_path="$SYSTEM_TRACK_DIR/$filename"
    
    if [ ! -d "$MOD_ZONE/.git" ]; then
        echo -e "${RED}[ERROR]${NC} Not in a git repository. Run 'doGit init' first."
        exit 1
    fi
    
    if [ ! -L "$symlink_path" ]; then
        echo -e "${RED}[ERROR]${NC} File is not being tracked: $system_file"
        exit 1
    fi
    
    cd "$MOD_ZONE"
    
    if [ "$DRY_RUN" = true ]; then
        log_dry_run "Would restore file from git: $system_file"
        log_dry_run "Would execute: git checkout HEAD -- '$symlink_path'"
    else
        echo -e "${YELLOW}[INFO]${NC} Restoring file from git: $system_file"
        
        # Restore the symlink from git (which will update the target file)
        git checkout HEAD -- "$symlink_path"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[SUCCESS]${NC} Restored file from git: $system_file"
        else
            echo -e "${RED}[ERROR]${NC} Failed to restore file from git"
            exit 1
        fi
    fi
}

# Main script logic
case "$1" in
    "add")
        add_system_file "$2"
        ;;
    "remove")
        remove_system_file "$2"
        ;;
    "list")
        list_tracked_files
        ;;
    "status")
        check_status
        ;;
    "sync")
        sync_tracked_files
        ;;
    "restore")
        restore_file "$2"
        ;;
    "help"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        echo -e "${RED}[ERROR]${NC} Unknown command: $1"
        echo "Run 'system-track help' for usage information"
        exit 1
        ;;
esac
