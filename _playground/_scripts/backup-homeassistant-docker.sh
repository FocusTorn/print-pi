#!/bin/bash
# Home Assistant Docker Container Backup Script
# Backs up the entire /home/pi/homeassistant directory

set -e

# Configuration (define first so we can check paths)
BACKUP_DIR="/home/pi/backups/homeassistant"
SOURCE_DIR="/home/pi/homeassistant"

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="homeassistant-full-backup-${DATE}"
BACKUP_FILE="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
KEEP_BACKUPS=3  # Keep last 3 backups

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Auto-elevate to sudo if not already root
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  Elevating to sudo for full backup access..."
    exec sudo "$0" "$@"
fi

print_header() {
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Home Assistant Docker Backup${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    if [ "$EUID" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  Running with elevated permissions${NC}"
        echo
    fi
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    print_error "Source directory not found: $SOURCE_DIR"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"
print_info "Backup directory: $BACKUP_DIR"

# Get container status
CONTAINER_STATUS=$(docker inspect -f '{{.State.Status}}' homeassistant 2>/dev/null || echo "not_running")
if [ "$CONTAINER_STATUS" = "running" ]; then
    print_info "Home Assistant container is running"
    print_warning "Backup will include current state (container can keep running)"
else
    print_warning "Home Assistant container is not running"
fi

# Calculate size before backup
SOURCE_SIZE=$(du -sh "$SOURCE_DIR" | cut -f1)
print_info "Source directory size: $SOURCE_SIZE"

# Check disk space before backup
AVAILABLE_SPACE=$(df -h "$BACKUP_DIR" | awk 'NR==2 {print $4}')
print_info "Available disk space: $AVAILABLE_SPACE"

# Check if backup directory is writable
if [ ! -w "$BACKUP_DIR" ]; then
    print_error "Backup directory is not writable: $BACKUP_DIR"
    print_info "Attempting to create backup directory..."
    mkdir -p "$BACKUP_DIR" || {
        print_error "Failed to create backup directory. Check permissions."
        exit 1
    }
fi

# Create backup
print_info "Creating backup..."
print_info "Backup file: $BACKUP_FILE"

# Create a temporary file to capture tar errors
TEMP_ERROR_FILE=$(mktemp)
trap "rm -f $TEMP_ERROR_FILE" EXIT

# Check if pv (pipe viewer) is available for progress bar
USE_PV=false
if command -v pv >/dev/null 2>&1; then
    USE_PV=true
    print_info "Using pv for progress bar (shows speed, bytes transferred, elapsed time)..."
fi

# Build tar command with excludes BEFORE the directory to archive (correct syntax)
if [ "$USE_PV" = true ]; then
    # Use pv without size specification - it will track compressed output
    # This gives accurate progress based on actual data being written
    # Percentage won't be shown (since we don't know compressed size ahead of time)
    # but speed, bytes, and elapsed time will be accurate
    print_info "Creating backup..."
    # pv outputs progress to stderr by default (terminal)
    # Redirect pv's stderr to /dev/tty so it always shows
    if tar -czf - \
        --exclude='*.log' \
        --exclude='*.db-shm' \
        --exclude='*.db-wal' \
        --warning=no-file-ignored \
        -C "$(dirname "$SOURCE_DIR")" \
        "$(basename "$SOURCE_DIR")" 2>"$TEMP_ERROR_FILE" | \
        pv -p -t -e -r -b -N "Backup" > "$BACKUP_FILE" 2>/dev/tty; then
        TAR_SUCCESS=true
    else
        TAR_SUCCESS=false
    fi
    # Clear the line after pv (pv uses \r to overwrite)
    echo
else
    # Use tar with checkpoint for basic progress (every 1000 files)
    print_info "Creating backup (progress every 1000 files)..."
    print_info "Tip: Install 'pv' for a better progress bar: sudo apt install pv"
    if tar -czf "$BACKUP_FILE" \
        --exclude='*.log' \
        --exclude='*.db-shm' \
        --exclude='*.db-wal' \
        --warning=no-file-ignored \
        --checkpoint=1000 \
        --checkpoint-action=echo="  Processed %u files" \
        -C "$(dirname "$SOURCE_DIR")" \
        "$(basename "$SOURCE_DIR")" \
        2>"$TEMP_ERROR_FILE"; then
        TAR_SUCCESS=true
    else
        TAR_SUCCESS=false
    fi
fi

if [ "$TAR_SUCCESS" = true ]; then
    
    echo  # Add blank line after progress output
    # Check if backup file was actually created and has content
    if [ ! -f "$BACKUP_FILE" ] || [ ! -s "$BACKUP_FILE" ]; then
        print_error "Backup file is empty or was not created!"
        print_info "This may indicate permission issues. Try running with sudo."
        rm -f "$BACKUP_FILE"
        exit 1
    fi
    
    # Get backup size
    BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    print_success "Backup created successfully!"
    print_info "Backup size: $BACKUP_SIZE"
    print_info "Backup location: $BACKUP_FILE"
    
    # Check for any files that were skipped (should be minimal with sudo)
    if [ -s "$TEMP_ERROR_FILE" ]; then
        SKIPPED_COUNT=$(grep -c "Permission denied\|Cannot open" "$TEMP_ERROR_FILE" 2>/dev/null || echo "0")
        if [ "$SKIPPED_COUNT" -gt 0 ]; then
            print_warning "Some files were skipped: $SKIPPED_COUNT files"
            print_info "This may indicate files locked by the running container"
        fi
    fi
    
    # Clean up old backups (keep last N)
    print_info "Cleaning up old backups (keeping last $KEEP_BACKUPS)..."
    cd "$BACKUP_DIR"
    ls -t *.tar.gz 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | while read backup; do
        rm -f "$backup"
        print_info "Removed old backup: $backup"
    done
    
    echo
    print_success "Backup completed successfully!"
    print_info "To restore: tar -xzf $BACKUP_FILE -C /home/pi/"
    
else
    print_error "Backup failed!"
    echo
    print_error "Error details:"
    if [ -s "$TEMP_ERROR_FILE" ]; then
        cat "$TEMP_ERROR_FILE" | while read line; do
            echo "  $line"
        done
    else
        print_error "No error output captured. Possible issues:"
        echo "  - Insufficient disk space"
        echo "  - Permission denied (files locked by running container)"
        echo "  - Source directory changed during backup"
        echo "  - Filesystem error"
    fi
    
    # Check for permission errors specifically
    if grep -q "Permission denied" "$TEMP_ERROR_FILE" 2>/dev/null; then
        echo
        print_warning "Permission denied errors detected. This is common when:"
        echo "  - Container is running and has files locked"
        echo "  - Files are owned by root (created by container)"
        echo
        print_info "Note: Script should auto-elevate to sudo if needed"
        print_info "If you see this error, the script may need manual sudo execution"
    fi
    echo
    print_info "Troubleshooting:"
    echo "  1. Check disk space: df -h $BACKUP_DIR"
    echo "  2. Check permissions: ls -ld $BACKUP_DIR"
    echo "  3. Check source directory: ls -ld $SOURCE_DIR"
    echo "  4. Try manual backup: tar -czf test-backup.tar.gz -C $(dirname $SOURCE_DIR) $(basename $SOURCE_DIR)"
    rm -f "$TEMP_ERROR_FILE"
    exit 1
fi

# Clean up temp error file on success
rm -f "$TEMP_ERROR_FILE"

echo
print_info "Backup summary:"
echo "  Source: $SOURCE_DIR"
echo "  Destination: $BACKUP_FILE"
echo "  Size: $BACKUP_SIZE"
echo "  Date: $(date)"

echo
print_info "Contents backed up (top-level directories):"
echo -e "${CYAN}────────────────────────────────────────────────${NC}"
printf "%-35s %12s\n" "DIRECTORY" "SIZE"
echo -e "${CYAN}────────────────────────────────────────────────${NC}"

# List all top-level directories and their sizes (including hidden ones)
if [ -d "$SOURCE_DIR" ]; then
    # Get all directories (including hidden) and their sizes, sort by size (largest first)
    # Use du with bytes for accurate sorting, then convert to human-readable for display
    {
        find "$SOURCE_DIR" -maxdepth 1 -type d ! -path "$SOURCE_DIR" | while read dir; do
            if [ -d "$dir" ]; then
                # Get size in bytes for sorting
                size_bytes=$(du -sb "$dir" 2>/dev/null | cut -f1)
                # Get human-readable size for display
                size_human=$(du -sh "$dir" 2>/dev/null | cut -f1)
                dirname=$(basename "$dir")
                # Output: bytes size_human dirname (tab-separated for sorting)
                echo -e "${size_bytes}\t${size_human}\t${dirname}"
            fi
        done
    } | sort -rn | while IFS=$'\t' read -r size_bytes size_human dirname; do
        printf "%-35s %12s\n" "$dirname" "$size_human"
    done
    
    # Also show any top-level files (not directories)
    top_level_files=$(find "$SOURCE_DIR" -maxdepth 1 -type f \( -name "*.yaml" -o -name "*.yml" \) 2>/dev/null)
    if [ -n "$top_level_files" ]; then
        echo
        echo "Top-level files:"
        echo "$top_level_files" | while read file; do
            if [ -f "$file" ]; then
                filename=$(basename "$file")
                size=$(ls -lh "$file" 2>/dev/null | awk '{print $5}')
                printf "  %-33s %12s\n" "$filename" "$size"
            fi
        done
    fi
else
    print_warning "Could not read source directory"
fi

echo -e "${CYAN}────────────────────────────────────────────────${NC}"
echo
print_info "Total backup size: $BACKUP_SIZE"
print_warning "Review the sizes above to identify large directories (e.g., media, .storage, backups)"

