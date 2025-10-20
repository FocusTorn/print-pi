#!/usr/bin/env bash
# Bootstrap Chamon TUI application for system restore
# Wrapper around the main install script

set -e

CHAMON_DIR="/home/pi/_playground/_dev/packages/chamon"
INSTALL_SCRIPT="$CHAMON_DIR/install.sh"

echo "📊 Bootstrapping Chamon installation..."
echo ""

# Check if chamon directory exists
if [ ! -d "$CHAMON_DIR" ]; then
    echo "❌ Error: Chamon source not found at $CHAMON_DIR"
    echo "   Make sure you've cloned the restore repo properly!"
    exit 1
fi

# Check if install script exists
if [ ! -f "$INSTALL_SCRIPT" ]; then
    echo "❌ Error: Install script not found at $INSTALL_SCRIPT"
    exit 1
fi

# Run the main install script
echo "🚀 Running chamon install script..."
echo ""
bash "$INSTALL_SCRIPT"

