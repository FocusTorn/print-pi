#!/bin/bash

# Detour Installation Script
# Installs detour to ~/.local/share/detour and creates symlink in ~/.local/bin

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

#> Parse command line arguments 
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
            print_error "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

#<

print_info() { #>
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${PURPLE}[DRY-RUN]${NC} ${BLUE}[INFO]${NC} $1"
    else
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
} #<
print_success() { #>
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${PURPLE}[DRY-RUN]${NC} ${GREEN}[SUCCESS]${NC} $1"
    else
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
} #<
print_warning() { #>
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${PURPLE}[DRY-RUN]${NC} ${YELLOW}[WARNING]${NC} $1"
    else
        echo -e "${YELLOW}[WARNING]${NC} $1"
    fi
} #<
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
INSTALL_DIR="$HOME/.local/share/detour"
BIN_DIR="$HOME/.local/bin"
CONFIG_SOURCE="$HOME/_playground/_scripts/detour/detour.conf"
CONFIG_TARGET="$HOME/.detour.conf"

# Check if we're in the right directory
if [[ ! -f "detour.conf" || ! -f "file-detour.sh" ]]; then
    print_error "Please run this script from the detour directory"
    exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
    print_info "DRY RUN MODE - No changes will be made"
    echo
fi

print_info "Installing detour..."

# Create directories
print_info "Creating directories..."
if [[ "$DRY_RUN" != true ]]; then
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$BIN_DIR"
fi

# Copy files to install directory
print_info "Copying files to $INSTALL_DIR..."
if [[ "$DRY_RUN" != true ]]; then
    cp file-detour.sh "$INSTALL_DIR/detour"
    cp detour.conf "$INSTALL_DIR/"
    
    # Make detour executable
    chmod +x "$INSTALL_DIR/detour"
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
    ln -s "$INSTALL_DIR/detour" "$BIN_DIR/detour"
fi

# Create config symlink in home directory
print_info "Creating config symlink..."
if [[ -L "$CONFIG_TARGET" ]]; then
    print_warning "Config symlink already exists, removing..."
    if [[ "$DRY_RUN" != true ]]; then
        rm "$CONFIG_TARGET"
    fi
fi
if [[ "$DRY_RUN" != true ]]; then
    ln -s "$INSTALL_DIR/detour.conf" "$CONFIG_TARGET"
fi

print_success "Detour installed successfully!"
print_info "Files installed to: $INSTALL_DIR"
print_info "Executable available as: detour"
print_info "Config available at: $CONFIG_TARGET"

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    print_warning "~/.local/bin is not in your PATH"
    print_info "Add this line to your ~/.bashrc or ~/.zshrc:"
    print_info "export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

if [[ "$DRY_RUN" == true ]]; then
    print_info "Run without --dry-run to perform the actual installation."
else
    print_success "Installation complete! You can now use 'detour' command."
fi






asdasd

asdasd

asdasd