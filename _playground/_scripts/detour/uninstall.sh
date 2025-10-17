#!/bin/bash

# Detour Uninstallation Script
# Removes detour from ~/.local/share/detour and removes symlinks

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
INSTALL_DIR="$HOME/.local/share/detour"
BIN_DIR="$HOME/.local/bin"
CONFIG_TARGET="$HOME/.detour.conf"

print_info "Uninstalling detour..."

# Remove symlink from bin directory
if [[ -L "$BIN_DIR/detour" ]]; then
    print_info "Removing symlink from $BIN_DIR..."
    rm "$BIN_DIR/detour"
    print_success "Symlink removed"
else
    print_warning "No symlink found in $BIN_DIR"
fi

# Remove config symlink
if [[ -L "$CONFIG_TARGET" ]]; then
    print_info "Removing config symlink..."
    rm "$CONFIG_TARGET"
    print_success "Config symlink removed"
else
    print_warning "No config symlink found at $CONFIG_TARGET"
fi

# Remove install directory
if [[ -d "$INSTALL_DIR" ]]; then
    print_info "Removing install directory..."
    rm -rf "$INSTALL_DIR"
    print_success "Install directory removed"
else
    print_warning "No install directory found at $INSTALL_DIR"
fi

print_success "Detour uninstalled successfully!"
print_info "All files and symlinks have been removed."
