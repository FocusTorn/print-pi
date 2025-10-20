#!/usr/bin/env bash
# Chamon Installation Script
# Checks dependencies, builds, and installs chamon wrapper to ~/.local/bin

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/bin"

echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          Chamon TUI - Installation Script              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# DEPENDENCY CHECKS
# ============================================================================

echo -e "${BLUE}[1/5]${NC} Checking dependencies..."
echo ""

MISSING_DEPS=()

# Check for Rust/Cargo
if command -v rustc &> /dev/null; then
    RUST_VERSION=$(rustc --version | awk '{print $2}')
    echo -e "  ${GREEN}✓${NC} rustc: $RUST_VERSION"
else
    echo -e "  ${RED}✗${NC} rustc: Not found"
    MISSING_DEPS+=("rustc")
fi

if command -v cargo &> /dev/null; then
    CARGO_VERSION=$(cargo --version | awk '{print $2}')
    echo -e "  ${GREEN}✓${NC} cargo: $CARGO_VERSION"
else
    echo -e "  ${RED}✗${NC} cargo: Not found"
    MISSING_DEPS+=("cargo")
fi

# Check for required system libraries (optional check)
if pkg-config --exists x11 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} X11 libraries"
else
    echo -e "  ${YELLOW}⚠${NC} X11 libraries: May be required for terminal rendering"
fi

echo ""

# Handle missing dependencies
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo -e "${RED}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║              MISSING DEPENDENCIES DETECTED               ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}The following dependencies are required but not installed:${NC}"
    for dep in "${MISSING_DEPS[@]}"; do
        echo -e "  ${RED}•${NC} $dep"
    done
    echo ""
    
    # Check if bootstrap exists
    if [ -f "/home/pi/_playground/_scripts/bootstraps/bootstrap-rust.sh" ]; then
        echo -e "${CYAN}You can install Rust/Cargo by running:${NC}"
        echo -e "  bash /home/pi/_playground/_scripts/bootstraps/bootstrap-rust.sh"
    else
        echo -e "${CYAN}Install Rust/Cargo manually:${NC}"
        echo -e "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    fi
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ All dependencies satisfied!${NC}"
echo ""

# ============================================================================
# BUILD TYPE SELECTION
# ============================================================================

echo -e "${BLUE}[2/5]${NC} Select build type..."
echo ""
echo -e "  ${CYAN}1)${NC} Development build (fast compile, includes debug info)"
echo -e "  ${CYAN}2)${NC} Production build  (slower compile, optimized for speed)"
echo ""

BUILD_TYPE=""
while true; do
    read -p "Choose build type (1/2): " -n 1 -r
    echo
    case $REPLY in
        1)
            BUILD_TYPE="dev"
            BUILD_CMD="cargo build"
            BUILD_DIR="$SCRIPT_DIR/target/debug"
            echo -e "${GREEN}✓${NC} Development build selected"
            break
            ;;
        2)
            BUILD_TYPE="prod"
            BUILD_CMD="cargo build --release"
            BUILD_DIR="$SCRIPT_DIR/target/release"
            echo -e "${GREEN}✓${NC} Production build selected"
            break
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter 1 or 2.${NC}"
            ;;
    esac
done

echo ""

# ============================================================================
# BUILD
# ============================================================================

echo -e "${BLUE}[3/5]${NC} Building chamon ($BUILD_TYPE)..."
echo ""

cd "$SCRIPT_DIR"

if $BUILD_CMD; then
    echo ""
    echo -e "${GREEN}✓ Build successful!${NC}"
else
    echo ""
    echo -e "${RED}✗ Build failed!${NC}"
    exit 1
fi

# Verify binary exists
if [ ! -f "$BUILD_DIR/chamon" ]; then
    echo -e "${RED}✗ Binary not found at expected location: $BUILD_DIR/chamon${NC}"
    exit 1
fi

echo ""

# ============================================================================
# CREATE WRAPPER SCRIPT
# ============================================================================

echo -e "${BLUE}[4/5]${NC} Creating wrapper script..."
echo ""

mkdir -p "$INSTALL_DIR"

# Create the smart wrapper script
cat > "$INSTALL_DIR/chamon" << 'WRAPPER_EOF'
#!/usr/bin/env bash
# Chamon TUI Wrapper Script
# Automatically selects dev or prod build (uses newer if both exist)

CHAMON_DIR="/home/pi/_playground/_dev/packages/chamon"
DEV_BUILD="$CHAMON_DIR/target/debug/chamon"
PROD_BUILD="$CHAMON_DIR/target/release/chamon"

# Check which builds exist
DEV_EXISTS=false
PROD_EXISTS=false

[ -f "$DEV_BUILD" ] && DEV_EXISTS=true
[ -f "$PROD_BUILD" ] && PROD_EXISTS=true

# Determine which to use
if $DEV_EXISTS && $PROD_EXISTS; then
    # Both exist - use the newer one
    if [ "$DEV_BUILD" -nt "$PROD_BUILD" ]; then
        BINARY="$DEV_BUILD"
        # echo "[chamon] Using dev build (newer)" >&2
    else
        BINARY="$PROD_BUILD"
        # echo "[chamon] Using prod build (newer)" >&2
    fi
elif $DEV_EXISTS; then
    BINARY="$DEV_BUILD"
    # echo "[chamon] Using dev build" >&2
elif $PROD_EXISTS; then
    BINARY="$PROD_BUILD"
    # echo "[chamon] Using prod build" >&2
else
    echo "Error: No chamon binary found!" >&2
    echo "Please run: cd $CHAMON_DIR && cargo build" >&2
    exit 1
fi

# Execute with all arguments passed through
exec "$BINARY" "$@"
WRAPPER_EOF

chmod +x "$INSTALL_DIR/chamon"

echo -e "${GREEN}✓${NC} Wrapper script created at: ${CYAN}$INSTALL_DIR/chamon${NC}"
echo ""

# ============================================================================
# VERIFY INSTALLATION
# ============================================================================

echo -e "${BLUE}[5/5]${NC} Verifying installation..."
echo ""

# Check if ~/.local/bin is in PATH
if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    echo -e "${GREEN}✓${NC} ~/.local/bin is in PATH"
else
    echo -e "${YELLOW}⚠${NC} ~/.local/bin is NOT in PATH"
    echo ""
    echo -e "${YELLOW}Add this to your ~/.zshrc or ~/.bashrc:${NC}"
    echo -e "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

# Test the wrapper
if "$INSTALL_DIR/chamon" --version &> /dev/null || [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Wrapper script executes successfully"
else
    echo -e "${YELLOW}⚠${NC} Wrapper script created but may need PATH configuration"
fi

echo ""

# ============================================================================
# SUMMARY
# ============================================================================

echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            INSTALLATION COMPLETE!                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Build Info:${NC}"
echo -e "  Type: ${YELLOW}$BUILD_TYPE${NC}"
echo -e "  Binary: ${CYAN}$BUILD_DIR/chamon${NC}"
echo -e "  Wrapper: ${CYAN}$INSTALL_DIR/chamon${NC}"
echo ""
echo -e "${CYAN}How the wrapper works:${NC}"
echo -e "  ${GREEN}•${NC} Checks for both dev and prod builds"
echo -e "  ${GREEN}•${NC} Uses the one with newer timestamp if both exist"
echo -e "  ${GREEN}•${NC} Falls back to whichever exists if only one is present"
echo ""
echo -e "${CYAN}Usage:${NC}"
echo -e "  ${YELLOW}chamon${NC}              # Run the TUI"
echo -e "  ${YELLOW}chamon --help${NC}       # Show help (if implemented)"
echo ""
echo -e "${CYAN}Rebuild:${NC}"
echo -e "  Dev:  ${YELLOW}cd $SCRIPT_DIR && cargo build${NC}"
echo -e "  Prod: ${YELLOW}cd $SCRIPT_DIR && cargo build --release${NC}"
echo -e "  (Wrapper will automatically use the newer build)"
echo ""

# Check if we need to remind about PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo -e "${YELLOW}⚠  Don't forget to add ~/.local/bin to your PATH!${NC}"
    echo ""
fi

