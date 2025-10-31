#!/bin/bash

# Detour Installation Script
# Installs:
#   - TUI binary (compiled from Rust)
#   - Runtime config (~/.detour.yaml)
#   - Shell scripts (lib/detour-core.sh)

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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
EXAMPLE_CONFIG="$SCRIPT_DIR/examples/detour.yaml.example"
USER_CONFIG="$HOME/.detour.yaml"
TUI_CONFIG="$SCRIPT_DIR/config.yaml"  # TUI build config - NEVER copy/modify
WRAPPER_SCRIPT="$SCRIPT_DIR/bin/detour-wrapper"

# Verify we're in the correct package structure
if [[ ! -d "$SCRIPT_DIR/lib" ]]; then
    print_error "Invalid package structure. Expected lib/ directory."
    exit 1
fi

# Check if wrapper script exists
if [[ ! -f "$WRAPPER_SCRIPT" ]]; then
    print_error "Wrapper script not found: $WRAPPER_SCRIPT"
    exit 1
fi

# Check if at least one binary exists
if [[ ! -f "$SCRIPT_DIR/target/release/detour" && ! -f "$SCRIPT_DIR/target/debug/detour" ]]; then
    print_error "No detour binary found. Build it first with: cargo build --release"
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
print_info "Installing smart wrapper to $INSTALL_DIR..."
if [[ "$DRY_RUN" != true ]]; then
    # Create bin directory
    mkdir -p "$INSTALL_DIR/bin"
    
    # Copy lib/ (shell scripts)
    cp -r "$SCRIPT_DIR/lib" "$INSTALL_DIR/"
    
    # Copy examples/
    if [[ -d "$SCRIPT_DIR/examples" ]]; then
        cp -r "$SCRIPT_DIR/examples" "$INSTALL_DIR/"
    fi
fi

# Create symlink to wrapper script
print_info "Creating smart symlink in $BIN_DIR..."
if [[ -L "$BIN_DIR/detour" || -f "$BIN_DIR/detour" ]]; then
    print_warning "Existing detour command found, removing..."
    if [[ "$DRY_RUN" != true ]]; then
        rm "$BIN_DIR/detour"
    fi
fi
if [[ "$DRY_RUN" != true ]]; then
    ln -s "$WRAPPER_SCRIPT" "$BIN_DIR/detour"
fi

# Handle user config (~/.detour.yaml)
if [[ -f "$USER_CONFIG" ]]; then
    print_warning "Config file already exists: $USER_CONFIG"
    if [[ "$DRY_RUN" != true ]]; then
        read -p "$(echo -e ${CYAN}Overwrite it? [y/N]: ${NC})" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Backing up existing config to ${USER_CONFIG}.backup"
            cp "$USER_CONFIG" "${USER_CONFIG}.backup"
            if [[ -f "$EXAMPLE_CONFIG" ]]; then
                cp "$EXAMPLE_CONFIG" "$USER_CONFIG"
                print_success "Config overwritten (backup saved)"
            else
                print_warning "No example config found to copy"
            fi
        else
            print_info "Keeping existing config"
        fi
    else
        print_info "Would prompt to overwrite existing config"
    fi
else
    print_info "Creating config at $USER_CONFIG..."
    if [[ "$DRY_RUN" != true ]]; then
        if [[ -f "$EXAMPLE_CONFIG" ]]; then
            cp "$EXAMPLE_CONFIG" "$USER_CONFIG"
            print_success "Config created from example"
        else
            # Create minimal config if no example exists
            cat > "$USER_CONFIG" << 'EOF'
detours: []
includes: []
services: []
EOF
            print_success "Created minimal config"
        fi
    fi
fi

print_success "Detour installed successfully!"
echo
print_info "📁 Package installed to: $INSTALL_DIR"
print_info "🔗 Smart wrapper: $BIN_DIR/detour → $WRAPPER_SCRIPT"
print_info "🎯 Automatically uses most recently built binary (debug or release)"
print_info "⚡ Just run 'detour b' or 'detour br' to rebuild"
print_info "⚙️  Runtime config: $USER_CONFIG"
print_info "🎨 TUI config: $TUI_CONFIG (for development only)"
if [[ -d "$INSTALL_DIR/examples" ]]; then
    print_info "📚 Examples: $INSTALL_DIR/examples/"
fi
print_info "📖 Docs: $SCRIPT_DIR/README.md"
echo
print_info "${CYAN}Usage:${NC}"
print_info "  detour           - Launch TUI"
print_info "  detour b         - Build (dev mode)"
print_info "  detour br        - Build (release mode)"
print_info "  detour rb        - Build (dev) + launch TUI"
print_info "  detour rbr       - Build (release) + launch TUI"
print_info "  detour --help    - Show all options"

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
