#!/bin/bash
# BME680 Service Uninstallation Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR"
MENU_SCRIPT="$PACKAGE_DIR/scripts/interactive-menu.sh"

# Capture original user's home (before sudo)
ORIGINAL_USER="${SUDO_USER:-$USER}"
ORIGINAL_HOME=$(getent passwd "$ORIGINAL_USER" 2>/dev/null | cut -d: -f6)
if [ -z "$ORIGINAL_HOME" ]; then
    ORIGINAL_HOME="/home/$ORIGINAL_USER"
fi

INSTALL_ROOT="$ORIGINAL_HOME/.local/share/bme680-service"
INSTALL_BIN="$ORIGINAL_HOME/.local/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

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

# Auto-elevate to root if needed
if [ "$EUID" -ne 0 ]; then
    print_info "This script requires sudo privileges"
    print_info "Attempting to elevate privileges..."
    exec sudo "$0" "$@"
fi

uninstall_service() {
    local service_name=$1
    
    if ! systemctl list-units --all --type=service | grep -q "$service_name.service"; then
        print_info "Service $service_name not installed, skipping"
        return 0
    fi
    
    print_info "Stopping $service_name service..."
    systemctl stop "$service_name.service" 2>/dev/null || true
    
    print_info "Disabling $service_name service..."
    systemctl disable "$service_name.service" 2>/dev/null || true
    
    print_info "Removing service file..."
    rm -f "/etc/systemd/system/$service_name.service"
    
    print_success "Uninstalled $service_name"
}

print_info "BME680 Service Uninstallation"
echo

# Source menu functions if available
if [ -f "$MENU_SCRIPT" ]; then
    source "$MENU_SCRIPT"
    
    # Build menu options based on installed services
    local menu_options=()
    
    if systemctl list-units --all --type=service | grep -q "bme680-readings.service"; then
        menu_options+=("Sensor readings service (bme680-readings)")
    fi
    
    if systemctl list-units --all --type=service | grep -q "bme680-heat-soak.service"; then
        menu_options+=("Heat soak detection service (bme680-heat-soak)")
    fi
    
    if [ ${#menu_options[@]} -eq 0 ]; then
        print_info "No BME680 services found installed"
    else
        print_info "Select services to uninstall:"
        echo
        
        local selected
        selected=$(interactive_menu "${menu_options[@]}")
        local menu_exit=$?
        
        if [ $menu_exit -ne 0 ] || [ -z "$selected" ]; then
            print_info "Uninstallation cancelled"
            exit 0
        fi
        
        # Process selections
        for idx in $selected; do
            case "${menu_options[$idx]}" in
                *"readings"*)
                    uninstall_service "bme680-readings"
                    ;;
                *"heat-soak"*)
                    uninstall_service "bme680-heat-soak"
                    ;;
            esac
        done
    fi
else
    # Fallback to simple prompts
    print_warning "Interactive menu not available, using simple prompts..."
    
    if systemctl list-units --all --type=service | grep -q "bme680-readings.service"; then
        read -p "Uninstall sensor readings service? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            uninstall_service "bme680-readings"
        fi
    fi
    
    if systemctl list-units --all --type=service | grep -q "bme680-heat-soak.service"; then
        read -p "Uninstall heat soak detection service? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            uninstall_service "bme680-heat-soak"
        fi
    fi
fi

print_info "Reloading systemd daemon..."
systemctl daemon-reload

# Build removal options
local removal_options=()

if [ -d "$INSTALL_ROOT" ]; then
    removal_options+=("Package files ($INSTALL_ROOT)")
fi

if [ -f "$INSTALL_BIN/bme680-cli" ]; then
    removal_options+=("CLI tool ($INSTALL_BIN/bme680-cli)")
fi

if [ ${#removal_options[@]} -gt 0 ]; then
    echo
    print_info "Select additional items to remove:"
    
    if [ -f "$MENU_SCRIPT" ]; then
        source "$MENU_SCRIPT"
        local selected
        selected=$(interactive_menu "${removal_options[@]}")
        local menu_exit=$?
        
        if [ $menu_exit -ne 0 ] || [ -z "$selected" ]; then
            print_info "Keeping all files"
        else
            for idx in $selected; do
                case "${removal_options[$idx]}" in
                    *"Package files"*)
                        print_info "Removing package files..."
                        rm -rf "$INSTALL_ROOT"
                        print_success "Package files removed"
                        ;;
                    *"CLI tool"*)
                        rm -f "$INSTALL_BIN/bme680-cli"
                        print_success "CLI tool removed"
                        ;;
                esac
            done
        fi
    else
        # Fallback to simple prompts
        if [ -d "$INSTALL_ROOT" ]; then
            read -p "Remove installed package files from $INSTALL_ROOT? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_info "Removing package files..."
                rm -rf "$INSTALL_ROOT"
                print_success "Package files removed"
            fi
        fi
        
        if [ -f "$INSTALL_BIN/bme680-cli" ]; then
            read -p "Remove CLI tool (bme680-cli) from $INSTALL_BIN? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -f "$INSTALL_BIN/bme680-cli"
                print_success "CLI tool removed"
            fi
        fi
    fi
fi

print_success "Uninstallation complete!"
