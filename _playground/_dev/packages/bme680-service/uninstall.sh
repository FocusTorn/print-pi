#!/bin/bash
# BME680 Service Uninstallation Script

set -e

INSTALL_ROOT="$HOME/.local/share/bme680-service"
INSTALL_BIN="$HOME/.local/bin"

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

read -p "Uninstall IAQ monitor service? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    uninstall_service "bme680-iaq"
fi

read -p "Uninstall temperature monitor service? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    uninstall_service "bme680-temperature"
fi

print_info "Reloading systemd daemon..."
systemctl daemon-reload

# Remove installed files
if [ -d "$INSTALL_ROOT" ]; then
    read -p "Remove installed package files from $INSTALL_ROOT? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Removing package files..."
        rm -rf "$INSTALL_ROOT"
        print_success "Package files removed"
    else
        print_info "Keeping package files (virtual environment and scripts)"
    fi
else
    print_info "No package files found at $INSTALL_ROOT"
fi

# Remove CLI tool if it exists
if [ -f "$INSTALL_BIN/bme680-cli" ]; then
    read -p "Remove CLI tool (bme680-cli) from $INSTALL_BIN? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$INSTALL_BIN/bme680-cli"
        print_success "CLI tool removed"
    fi
fi

print_success "Uninstallation complete!"
