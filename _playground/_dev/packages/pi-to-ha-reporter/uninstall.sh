#!/bin/bash
# Pi to Home Assistant Reporter Uninstallation Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR"

# Import logger utility
source "${SCRIPT_DIR}/../_utilities/logger/import.sh"

# Initialize logger
logger_init "pi-to-ha-reporter"

# Capture original user's home (before sudo)
ORIGINAL_USER="${SUDO_USER:-$USER}"
ORIGINAL_HOME=$(getent passwd "$ORIGINAL_USER" 2>/dev/null | cut -d: -f6)
if [ -z "$ORIGINAL_HOME" ]; then
    ORIGINAL_HOME="/home/$ORIGINAL_USER"
fi

INSTALL_ROOT="$ORIGINAL_HOME/.local/share/pi-to-ha-reporter"
SERVICE_NAME="pi-to-ha-reporter"

# Auto-elevate to root if needed
if [ "$EUID" -ne 0 ]; then
    logger_info "This script requires sudo privileges"
    logger_info "Attempting to elevate privileges..."
    exec sudo "$0" "$@"
fi

uninstall_service() {
    if ! systemctl list-units --all --type=service | grep -q "${SERVICE_NAME}.service"; then
        logger_info "Service ${SERVICE_NAME} not installed, skipping"
        return 0
    fi
    
    logger_info "Stopping ${SERVICE_NAME} service..."
    systemctl stop "${SERVICE_NAME}.service" 2>/dev/null || true
    
    logger_info "Disabling ${SERVICE_NAME} service..."
    systemctl disable "${SERVICE_NAME}.service" 2>/dev/null || true
    
    logger_info "Removing service file..."
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    
    logger_info "Reloading systemd daemon..."
    systemctl daemon-reload
    
    logger_success "Service uninstalled"
}

logger_info "Pi to HA Reporter Uninstallation"
echo

# Uninstall service
uninstall_service

# Ask about removing package files
echo
if [ -d "$INSTALL_ROOT" ]; then
    logger_warn "Package files found at: $INSTALL_ROOT"
    read -p "Remove installed package files? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        logger_info "Removing package files..."
        rm -rf "$INSTALL_ROOT"
        logger_success "Package files removed"
    else
        logger_info "Keeping package files"
    fi
else
    logger_info "No package files found at $INSTALL_ROOT"
fi

echo
logger_success "Uninstallation complete!"
