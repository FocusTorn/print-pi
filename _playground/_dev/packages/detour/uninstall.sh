#!/bin/bash

# Detour Uninstallation Script
# Removes:
#   - TUI binary (from ~/.local/share/detour)
#   - Shell scripts (lib/)
#   - Optionally: runtime config (~/.detour.yaml)
# Never touches: TUI build config (config.yaml in package dir)

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
USER_CONFIG="$HOME/.detour.yaml"

print_info "Uninstalling detour..."

# Remove symlink from bin directory
if [[ -L "$BIN_DIR/detour" ]]; then
    print_info "Removing executable symlink from $BIN_DIR..."
    rm "$BIN_DIR/detour"
    print_success "Symlink removed"
elif [[ -f "$BIN_DIR/detour" ]]; then
    print_info "Removing executable from $BIN_DIR..."
    rm "$BIN_DIR/detour"
    print_success "Executable removed"
else
    print_warning "No detour executable found in $BIN_DIR"
fi

# Remove install directory (binary + lib)
if [[ -d "$INSTALL_DIR" ]]; then
    print_info "Removing install directory $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
    print_success "Install directory removed"
else
    print_warning "No install directory found at $INSTALL_DIR"
fi

# Handle user config (~/.detour.yaml) - prompt for removal
if [[ -f "$USER_CONFIG" ]]; then
    echo
    print_warning "Runtime config file found: $USER_CONFIG"
    read -p "$(echo -e ${CYAN}Remove it? [y/N]: ${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Backing up to ${USER_CONFIG}.removed"
        mv "$USER_CONFIG" "${USER_CONFIG}.removed"
        print_success "Config removed (backup saved as .removed)"
    else
        print_info "Keeping config file"
    fi
else
    print_info "No runtime config found at $USER_CONFIG"
fi

echo
print_success "Detour uninstalled successfully!"
print_info "✅ Binary and libraries removed"
if [[ -f "$USER_CONFIG" ]]; then
    print_info "⚙️  Config retained: $USER_CONFIG"
else
    print_info "⚙️  Config removed"
fi
print_info "🎨 TUI build config (config.yaml) is untouched in package directory"
