#!/bin/bash

# Detour Installation Script
# Installs detour package to ~/.local/share/detour and creates symlink in ~/.local/bin

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Parse command line arguments
DRY_RUN=false
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run]"
            echo "  --dry-run    Show what would be done without making changes"
            echo "  -h, --help   Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

print_info() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${PURPLE}[DRY-RUN]${NC} ${BLUE}[INFO]${NC} $1"
    else
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

print_success() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${PURPLE}[DRY-RUN]${NC} ${GREEN}[SUCCESS]${NC} $1"
    else
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

print_warning() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${PURPLE}[DRY-RUN]${NC} ${YELLOW}[WARNING]${NC} $1"
    else
        echo -e "${YELLOW}[WARNING]${NC} $1"
    fi
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get script directory (should be the package root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
INSTALL_DIR="$HOME/.local/share/detour"
BIN_DIR="$HOME/.local/bin"
EXAMPLE_CONFIG="$SCRIPT_DIR/examples/detour.conf.example"
USER_CONFIG="$HOME/.detour.conf"

# Verify we're in the correct package structure
if [[ ! -f "$SCRIPT_DIR/bin/detour" || ! -d "$SCRIPT_DIR/lib" ]]; then
    print_error "Invalid package structure. Expected bin/detour and lib/ directory."
    exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
    print_info "DRY RUN MODE - No changes will be made"
    echo
fi

print_info "Installing detour from: $SCRIPT_DIR"

# Create directories
print_info "Creating directories..."
if [[ "$DRY_RUN" != true ]]; then
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$BIN_DIR"
    mkdir -p "$HOME/.local/share/detour/logs"
fi

# Copy package structure to install directory
print_info "Copying package files to $INSTALL_DIR..."
if [[ "$DRY_RUN" != true ]]; then
    # Copy bin/
    cp -r "$SCRIPT_DIR/bin" "$INSTALL_DIR/"
    
    # Copy lib/
    cp -r "$SCRIPT_DIR/lib" "$INSTALL_DIR/"
    
    # Copy examples/
    cp -r "$SCRIPT_DIR/examples" "$INSTALL_DIR/"
    
    # Make detour executable
    chmod +x "$INSTALL_DIR/bin/detour"
fi

# Create symlink in bin directory
print_info "Creating symlink in $BIN_DIR..."
if [[ -L "$BIN_DIR/detour" ]]; then
    print_warning "Symlink already exists, removing..."
    if [[ "$DRY_RUN" != true ]]; then
        rm "$BIN_DIR/detour"
    fi
fi
if [[ "$DRY_RUN" != true ]]; then
    ln -s "$INSTALL_DIR/bin/detour" "$BIN_DIR/detour"
fi

# Create user config if it doesn't exist
if [[ ! -f "$USER_CONFIG" ]]; then
    print_info "Creating example config at $USER_CONFIG..."
    if [[ "$DRY_RUN" != true ]]; then
        cp "$EXAMPLE_CONFIG" "$USER_CONFIG"
    fi
    print_info "Edit $USER_CONFIG to add your detour rules"
else
    print_info "Config already exists at $USER_CONFIG (not overwriting)"
fi

print_success "Detour installed successfully!"
echo
print_info "📁 Package installed to: $INSTALL_DIR"
print_info "🔗 Executable: detour (via $BIN_DIR/detour)"
print_info "⚙️  Config: $USER_CONFIG"
print_info "📚 Examples: $INSTALL_DIR/examples/"
print_info "📖 Docs: $SCRIPT_DIR/README.md"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo
    print_warning "~/.local/bin is not in your PATH"
    print_info "Add this line to your ~/.bashrc or ~/.zshrc:"
    echo -e "  ${GREEN}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
fi

if [[ "$DRY_RUN" == true ]]; then
    echo
    print_info "Run without --dry-run to perform the actual installation."
else
    echo
    print_success "✅ Installation complete! You can now use 'detour' command."
    print_info "Try: detour --help"
fi
