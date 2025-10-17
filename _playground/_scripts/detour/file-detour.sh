#!/bin/bash

# File Detour Manager - Unified system for managing file detours, includes, and services
# Usage: detour [command] [options]
# Examples: detour apply, detour status, detour init /path/to/file

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Configuration
CONFIG_FILE="$HOME/.detour.conf"
LOG_FILE="$HOME/.local/share/detour/file-detour.log"
SCRIPT_DIR="$HOME/.local/share/detour"
DRY_RUN=false

# Logging function
log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $1" >> "$LOG_FILE"
}

log_dry_run() {
    echo -e "${PURPLE}[DRY-RUN]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $1" >> "$LOG_FILE"
}

# Parse command line arguments
COMMAND="$1"
shift  # Remove command from arguments

# Parse remaining arguments for options
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            # Ignore unknown arguments
            shift
            ;;
    esac
done

# Check if we need to elevate
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[0;34m[INFO]\033[0m Auto-elevating to root privileges..."
    exec sudo "$0" "$COMMAND" "$@"
fi

# Parse configuration file
parse_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Skip comments and empty lines, extract directives
    grep -v '^#' "$CONFIG_FILE" | grep -v '^$' | grep -v '^>' | while IFS= read -r line; do
        # Skip documentation blocks
        if [[ "$line" =~ ^[[:space:]]*##.*[\<\>] ]]; then
            continue
        fi
        
        # Parse detour directive: detour /path/to/original = /path/to/custom
        if [[ "$line" =~ ^[[:space:]]*detour[[:space:]]+(.+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            local original="${BASH_REMATCH[1]}"
            local custom="${BASH_REMATCH[2]}"
            echo "detour|$original|$custom"
        
        # Parse include directive: include /path/to/file : /path/to/include
        elif [[ "$line" =~ ^[[:space:]]*include[[:space:]]+(.+)[[:space:]]*:[[:space:]]*(.+)$ ]]; then
            local target="${BASH_REMATCH[1]}"
            local include_file="${BASH_REMATCH[2]}"
            echo "include|$target|$include_file"
        
        # Parse service directive: service service_name : action
        elif [[ "$line" =~ ^[[:space:]]*service[[:space:]]+(.+)[[:space:]]*:[[:space:]]*(.+)$ ]]; then
            local service="${BASH_REMATCH[1]}"
            local action="${BASH_REMATCH[2]}"
            echo "service|$service|$action"
        fi
    done
}

# Apply file detour (bind mount)
apply_detour() {
    local original="$1"
    local custom="$2"
    
    # Check if original file exists
    if [ ! -f "$original" ]; then
        log_error "Original file does not exist: $original"
        return 1
    fi
    
    # Check if custom file exists
    if [ ! -f "$custom" ]; then
        log_error "Custom file does not exist: $custom"
        return 1
    fi
    
    # Check if already mounted
    if mountpoint -q "$original" 2>/dev/null; then
        if [ "$DRY_RUN" = true ]; then
            log_dry_run "Detour already applied: $original"
        else
            log_info "Detour already applied: $original"
        fi
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_dry_run "Would execute: mount --bind '$custom' '$original'"
        log_dry_run "Applied detour: $original -> $custom"
    else
        # Create bind mount
        mount --bind "$custom" "$original" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            log_success "Applied detour: $original -> $custom"
        else
            log_error "Failed to apply detour: $original"
            return 1
        fi
    fi
}

# Remove file detour (unmount)
remove_detour() {
    local original="$1"
    
    # Check if mounted
    if mountpoint -q "$original" 2>/dev/null; then
        if [ "$DRY_RUN" = true ]; then
            log_dry_run "Would execute: umount '$original'"
            log_dry_run "Removed detour: $original"
        else
            umount "$original" 2>/dev/null
            
            if [ $? -eq 0 ]; then
                log_success "Removed detour: $original"
            else
                log_error "Failed to remove detour: $original"
                return 1
            fi
        fi
    else
        if [ "$DRY_RUN" = true ]; then
            log_dry_run "No detour to remove: $original"
        else
            log_info "No detour to remove: $original"
        fi
    fi
}

# Add include directive
add_include() {
    local target="$1"
    local include_file="$2"
    
    # Check if target file exists
    if [ ! -f "$target" ]; then
        log_error "Target file does not exist: $target"
        return 1
    fi
    
    # Check if include file exists
    if [ ! -f "$include_file" ]; then
        log_error "Include file does not exist: $include_file"
        return 1
    fi
    
    # Check if include already exists
    if grep -q "include $include_file" "$target" 2>/dev/null; then
        if [ "$DRY_RUN" = true ]; then
            log_dry_run "Include already exists: $target -> $include_file"
        else
            log_info "Include already exists: $target -> $include_file"
        fi
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_dry_run "Would execute: echo 'include $include_file' >> '$target'"
        log_dry_run "Added include: $target -> $include_file"
    else
        # Add include directive
        echo "include $include_file" >> "$target"
        
        if [ $? -eq 0 ]; then
            log_success "Added include: $target -> $include_file"
        else
            log_error "Failed to add include: $target"
            return 1
        fi
    fi
}

# Remove include directive
remove_include() {
    local target="$1"
    local include_file="$2"
    
    # Check if target file exists
    if [ ! -f "$target" ]; then
        log_error "Target file does not exist: $target"
        return 1
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_dry_run "Would execute: sed -i '/include $include_file/d' '$target'"
        log_dry_run "Removed include: $target -> $include_file"
    else
        # Remove include directive
        sed -i "/include $include_file/d" "$target"
        
        if [ $? -eq 0 ]; then
            log_success "Removed include: $target -> $include_file"
        else
            log_error "Failed to remove include: $target"
            return 1
        fi
    fi
}

# Manage service
manage_service() {
    local service="$1"
    local action="$2"
    
    case "$action" in
        "start")
            if [ "$DRY_RUN" = true ]; then
                log_dry_run "Would execute: systemctl start '$service'"
                log_dry_run "Started service: $service"
            else
                systemctl start "$service" 2>/dev/null
                if [ $? -eq 0 ]; then
                    log_success "Started service: $service"
                else
                    log_error "Failed to start service: $service"
                fi
            fi
            ;;
        "stop")
            if [ "$DRY_RUN" = true ]; then
                log_dry_run "Would execute: systemctl stop '$service'"
                log_dry_run "Stopped service: $service"
            else
                systemctl stop "$service" 2>/dev/null
                if [ $? -eq 0 ]; then
                    log_success "Stopped service: $service"
                else
                    log_error "Failed to stop service: $service"
                fi
            fi
            ;;
        "restart")
            if [ "$DRY_RUN" = true ]; then
                log_dry_run "Would execute: systemctl restart '$service'"
                log_dry_run "Restarted service: $service"
            else
                systemctl restart "$service" 2>/dev/null
                if [ $? -eq 0 ]; then
                    log_success "Restarted service: $service"
                else
                    log_error "Failed to restart service: $service"
                fi
            fi
            ;;
        "reload")
            if [ "$DRY_RUN" = true ]; then
                log_dry_run "Would execute: systemctl reload '$service'"
                log_dry_run "Reloaded service: $service"
            else
                systemctl reload "$service" 2>/dev/null
                if [ $? -eq 0 ]; then
                    log_success "Reloaded service: $service"
                else
                    log_error "Failed to reload service: $service"
                fi
            fi
            ;;
        *)
            log_error "Unknown service action: $action"
            ;;
    esac
}

# Apply all configurations
apply_all() {
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Would apply all configurations..."
    else
        log_info "Applying all configurations..."
    fi
    
    local detour_count=0
    local include_count=0
    local service_count=0
    
    while IFS='|' read -r type target value; do
        case "$type" in
            "detour")
                apply_detour "$target" "$value"
                if [ $? -eq 0 ]; then
                    ((detour_count++))
                fi
                ;;
            "include")
                add_include "$target" "$value"
                if [ $? -eq 0 ]; then
                    ((include_count++))
                fi
                ;;
            "service")
                manage_service "$target" "$value"
                if [ $? -eq 0 ]; then
                    ((service_count++))
                fi
                ;;
        esac
    done < <(parse_config)
    
    if [ "$DRY_RUN" = true ]; then
        log_dry_run "Would apply $detour_count detours, $include_count includes, manage $service_count services"
    else
        log_success "Applied $detour_count detours, $include_count includes, managed $service_count services"
    fi
}

# Remove all configurations
remove_all() {
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Would remove all configurations..."
    else
        log_info "Removing all configurations..."
    fi
    
    local detour_count=0
    local include_count=0
    local service_count=0
    
    while IFS='|' read -r type target value; do
        case "$type" in
            "detour")
                remove_detour "$target"
                if [ $? -eq 0 ]; then
                    ((detour_count++))
                fi
                ;;
            "include")
                remove_include "$target" "$value"
                if [ $? -eq 0 ]; then
                    ((include_count++))
                fi
                ;;
            "service")
                manage_service "$target" "stop"
                if [ $? -eq 0 ]; then
                    ((service_count++))
                fi
                ;;
        esac
    done < <(parse_config)
    
    if [ "$DRY_RUN" = true ]; then
        log_dry_run "Would remove $detour_count detours, $include_count includes, stop $service_count services"
    else
        log_success "Removed $detour_count detours, $include_count includes, stopped $service_count services"
    fi
}

# Show status
show_status() {
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│                           System Manager Status                            │${NC}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────────────────────┘${NC}"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    echo -e "${GRAY}Config: $CONFIG_FILE${NC}"
    echo
    
    # Initialize arrays for different types
    local detour_applied=()
    local detour_not_applied=()
    local include_applied=()
    local include_not_applied=()
    local services=()
    
    # Parse configurations and categorize them
    while IFS='|' read -r type target value; do
        case "$type" in
            "detour")
                if [ -f "$target" ] && mountpoint -q "$target" 2>/dev/null; then
                    detour_applied+=("$target = $value")
                else
                    detour_not_applied+=("$target")
                fi
                ;;
            "include")
                if [ -f "$target" ] && grep -q "include $value" "$target" 2>/dev/null; then
                    include_applied+=("$target : $value")
                else
                    include_not_applied+=("$target : $value")
                fi
                ;;
            "service")
                services+=("$target ($value)")
                ;;
        esac
    done < <(parse_config)
    
    # Display DETOUR section
    if [ ${#detour_applied[@]} -gt 0 ] || [ ${#detour_not_applied[@]} -gt 0 ]; then
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━  DETOUR  ━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Show applied detours
        for detour in "${detour_applied[@]}"; do
            echo "$detour"
        done
        
        # Show not applied detours
        if [ ${#detour_not_applied[@]} -gt 0 ]; then
            echo
            echo "Not Applied:"
            for detour in "${detour_not_applied[@]}"; do
                echo "  $detour"
            done
        fi
        echo
    fi
    
    # Display INCLUDE section
    if [ ${#include_applied[@]} -gt 0 ] || [ ${#include_not_applied[@]} -gt 0 ]; then
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━  INCLUDE  ━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        # Show applied includes
        for include in "${include_applied[@]}"; do
            echo "$include"
        done
        
        # Show not applied includes
        for include in "${include_not_applied[@]}"; do
            echo "$include"
        done
        echo
    fi
    
    # Display SERVICES section if any
    if [ ${#services[@]} -gt 0 ]; then
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━  SERVICES  ━━━━━━━━━━━━━━━━━━━━━━${NC}"
        for service in "${services[@]}"; do
            echo "$service"
        done
        echo
    fi
}

# Initialize detour (copy original to custom location)
init_detour() {
    local original="$1"
    local custom="$2"
    
    if [ -z "$original" ] || [ -z "$custom" ]; then
        echo -e "${RED}[ERROR]${NC} Usage: detour init <original_file> <custom_file>"
        echo "Example: detour init /home/pi/printer_data/config/printer.cfg /home/pi/3dp-mods/PrinterData_Config/printer.cfg"
        exit 1
    fi
    
    # Check if original file exists
    if [ ! -f "$original" ]; then
        log_error "Original file does not exist: $original"
        exit 1
    fi
    
    # Create custom directory if it doesn't exist
    local custom_dir=$(dirname "$custom")
    mkdir -p "$custom_dir"
    
    # Copy original to custom location
    cp "$original" "$custom"
    
    if [ $? -eq 0 ]; then
        log_success "Initialized detour: $original -> $custom"
        echo -e "${YELLOW}[INFO]${NC} You can now edit: $custom"
        echo -e "${YELLOW}[INFO]${NC} Then run: detour apply"
    else
        log_error "Failed to initialize detour: $original"
        exit 1
    fi
}

# Install system (create symlinks and systemd service)
install_system() {
    log_info "Installing file detour manager system..."
    
    # Create global symlink for detour command
    if [ ! -L "/home/pi/.local/bin/detour" ]; then
        ln -sf "$0" "/home/pi/.local/bin/detour"
        if [ $? -eq 0 ]; then
            log_success "Created global command: detour"
        else
            log_error "Failed to create global command symlink"
            return 1
        fi
    else
        log_info "Global command already exists: detour"
    fi
    
    # Create systemd service file
    local service_file="/etc/systemd/system/file-detour-manager.service"
    if [ ! -f "$service_file" ]; then
        cat > "$service_file" << EOF
[Unit]
Description=File Detour Manager - Auto-apply detours on boot
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/home/pi/_playground/_scripts/detour/file-detour.sh apply
RemainAfterExit=yes
User=root

[Install]
WantedBy=multi-user.target
EOF
        
        if [ $? -eq 0 ]; then
            log_success "Created systemd service: file-detour-manager.service"
        else
            log_error "Failed to create systemd service file"
            return 1
        fi
    else
        log_info "Systemd service already exists: file-detour-manager.service"
    fi
    
    # Reload systemd and enable service
    systemctl daemon-reload
    if [ $? -eq 0 ]; then
        log_success "Reloaded systemd daemon"
    else
        log_error "Failed to reload systemd daemon"
        return 1
    fi
    
    systemctl enable file-detour-manager.service
    if [ $? -eq 0 ]; then
        log_success "Enabled file-detour-manager service for auto-start"
    else
        log_error "Failed to enable file-detour-manager service"
        return 1
    fi
    
    log_success "Installation completed successfully!"
    echo -e "${CYAN}[INFO]${NC} You can now use 'detour' command from anywhere"
    echo -e "${CYAN}[INFO]${NC} Service will auto-apply detours on boot"
    echo -e "${YELLOW}[INFO]${NC} Run 'detour apply' to apply configurations now"
}

# Uninstall system (remove symlinks and systemd service)
uninstall_system() {
    if [ "$DRY_RUN" = true ]; then
        log_info "DRY-RUN: Would uninstall file detour manager system..."
    else
        log_info "Uninstalling file detour manager system..."
    fi
    
    # Step 1: Remove all active overlays and includes first
    if [ "$DRY_RUN" = true ]; then
        log_dry_run "Would remove all active overlays and includes..."
        # Call remove_all with dry-run flag
        DRY_RUN=true remove_all
    else
        log_info "Removing all active overlays and includes..."
        remove_all
    fi
    
    # Step 2: Stop and disable the service
    if [ "$DRY_RUN" = true ]; then
        log_dry_run "Would stop file-detour-manager service"
        log_dry_run "Would disable file-detour-manager service"
    else
        log_info "Stopping and disabling file-detour-manager service..."
        systemctl stop file-detour-manager.service 2>/dev/null
        if [ $? -eq 0 ]; then
            log_success "Stopped file-detour-manager service"
        else
            log_warning "Service was not running: file-detour-manager.service"
        fi
        
        systemctl disable file-detour-manager.service 2>/dev/null
        if [ $? -eq 0 ]; then
            log_success "Disabled file-detour-manager service"
        else
            log_warning "Service was not enabled: file-detour-manager.service"
        fi
    fi
    
    # Step 3: Remove systemd service file
    local service_file="/etc/systemd/system/file-detour-manager.service"
    if [ -f "$service_file" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_dry_run "Would remove systemd service file: $service_file"
        else
            rm "$service_file"
            if [ $? -eq 0 ]; then
                log_success "Removed systemd service file"
            else
                log_error "Failed to remove systemd service file"
                return 1
            fi
        fi
    else
        if [ "$DRY_RUN" = true ]; then
            log_dry_run "Systemd service file not found: $service_file"
        else
            log_warning "Systemd service file not found: $service_file"
        fi
    fi
    
    # Step 4: Remove global symlink
    if [ -L "/home/pi/.local/bin/detour" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_dry_run "Would remove global command symlink: /home/pi/.local/bin/detour"
        else
            rm "/home/pi/.local/bin/detour"
            if [ $? -eq 0 ]; then
                log_success "Removed global command: detour"
            else
                log_error "Failed to remove global command symlink"
                return 1
            fi
        fi
    else
        if [ "$DRY_RUN" = true ]; then
            log_dry_run "Global command symlink not found: /home/pi/.local/bin/detour"
        else
            log_warning "Global command symlink not found: /home/pi/.local/bin/detour"
        fi
    fi
    
    # Step 5: Reload systemd daemon
    if [ "$DRY_RUN" = true ]; then
        log_dry_run "Would reload systemd daemon"
    else
        systemctl daemon-reload 2>/dev/null
        if [ $? -eq 0 ]; then
            log_success "Reloaded systemd daemon"
        else
            log_error "Failed to reload systemd daemon"
            return 1
        fi
    fi
    
    # Step 6: Optional cleanup
    if [ -f "$LOG_FILE" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_dry_run "Would prompt to remove log file: $LOG_FILE"
        else
            echo -e "${YELLOW}[INFO]${NC} Log file found: $LOG_FILE"
            read -p "Remove log file? [y/N]: " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm "$LOG_FILE"
                log_success "Removed log file"
            else
                log_info "Keeping log file: $LOG_FILE"
                # Log the uninstall completion to the file being kept
                echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] Uninstallation completed successfully!" >> "$LOG_FILE"
                echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] The File Detour Manager system has been completely removed" >> "$LOG_FILE"
                echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] Original framework files are now restored to their default state" >> "$LOG_FILE"
                echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] Custom files in /home/pi/3dp-mods/ are preserved" >> "$LOG_FILE"
            fi
        fi
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_dry_run "DRY-RUN: Would complete uninstallation successfully!"
        echo -e "${PURPLE}[DRY-RUN]${NC} The File Detour Manager system would be completely removed"
        echo -e "${PURPLE}[DRY-RUN]${NC} Original framework files would be restored to their default state"
        echo -e "${PURPLE}[DRY-RUN]${NC} Custom files in /home/pi/3dp-mods/ would be preserved"
    else
        log_success "Uninstallation completed successfully!"
        echo -e "${CYAN}[INFO]${NC} The File Detour Manager system has been completely removed"
        echo -e "${CYAN}[INFO]${NC} Your original framework files are now restored to their default state"
        echo -e "${YELLOW}[WARNING]${NC} Your custom files in /home/pi/3dp-mods/ are preserved"
        echo -e "${YELLOW}[WARNING]${NC} You can manually remove them if no longer needed"
    fi
}

# Show help
show_help() {
    echo -e "${CYAN}File Detour Manager - Unified System Configuration${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo
    echo "Usage: detour [command] [options]"
    echo
    echo "Commands:"
    echo "  install    - Install global symlinks and systemd service"
    echo "  uninstall  - Completely remove the detour system"
    echo "  apply      - Apply all file detours, includes, and manage services"
    echo "  remove     - Remove all file detours, includes, and stop services"
    echo "  status     - Show current system state"
    echo "  init       - Copy original file to custom location for editing"
    echo "  tui        - Interactive configuration manager"
    echo "  help       - Show this help message"
    echo
    echo "Options:"
    echo "  --dry-run  - Show what would be executed without making changes"
    echo
    echo "Examples:"
    echo "  detour install"
    echo "  detour uninstall"
    echo "  detour apply --dry-run"
    echo "  detour apply"
    echo "  detour remove --dry-run"
    echo "  detour status"
    echo "  detour init /home/pi/printer_data/config/printer.cfg /home/pi/3dp-mods/PrinterData_Config/printer.cfg"
    echo "  detour tui"
    echo
    echo "Configuration: $CONFIG_FILE"
    echo "Log file: $LOG_FILE"
}

# TUI function (placeholder for now)
show_tui() {
    echo -e "${YELLOW}[INFO]${NC} TUI interface coming soon..."
    echo -e "${CYAN}[INFO]${NC} For now, use 'detour status' to see current state"
    echo -e "${CYAN}[INFO]${NC} Use 'detour apply' to apply configurations"
    echo -e "${CYAN}[INFO]${NC} Use 'detour remove' to remove configurations"
}

# Main script logic
case "$COMMAND" in
    "install")
        install_system
        ;;
    "uninstall")
        uninstall_system
        ;;
    "apply")
        apply_all
        ;;
    "remove")
        remove_all
        ;;
    "status")
        show_status
        ;;
    "init")
        # Pass remaining arguments to init function
        init_detour "$2" "$3"
        ;;
    "tui")
        show_tui
        ;;
    "help"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        echo -e "${RED}[ERROR]${NC} Unknown command: $COMMAND"
        echo "Run 'detour help' for usage information"
        exit 1
        ;;
esac
