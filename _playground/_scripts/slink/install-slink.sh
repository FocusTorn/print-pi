#!/usr/bin/env bash
# Install slink command globally
# Creates symlink in ~/.local/bin

set -e

SLINK_SCRIPT="/home/pi/_playground/_scripts/slink/slink.sh"
LOCAL_BIN="/home/pi/.local/bin"
SYMLINK="${LOCAL_BIN}/slink"

echo "🔗 Installing slink command..."
echo ""

# Verify slink.sh exists
if [ ! -f "$SLINK_SCRIPT" ]; then
    echo "❌ Error: slink.sh not found at $SLINK_SCRIPT"
    exit 1
fi

# Create .local/bin if it doesn't exist
if [ ! -d "$LOCAL_BIN" ]; then
    echo "📁 Creating $LOCAL_BIN directory..."
    mkdir -p "$LOCAL_BIN"
fi

# Check if symlink already exists
if [ -L "$SYMLINK" ]; then
    echo "⚠️  Symlink already exists at $SYMLINK"
    echo "   Current target: $(readlink -f "$SYMLINK")"
    read -p "Recreate symlink? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Installation cancelled"
        exit 0
    fi
    rm "$SYMLINK"
fi

# Create symlink
echo "🔗 Creating symlink..."
ln -sf "$SLINK_SCRIPT" "$SYMLINK"

# Verify installation
if [ -L "$SYMLINK" ] && [ -x "$SYMLINK" ]; then
    echo ""
    echo "✅ slink installed successfully!"
    echo ""
    echo "📍 Symlink: $SYMLINK"
    echo "🎯 Target: $SLINK_SCRIPT"
    echo ""
    echo "🧪 Testing command..."
    if slink --help &> /dev/null || slink -h &> /dev/null || slink &> /dev/null; then
        echo "✅ Command 'slink' is working!"
    else
        echo "⚠️  Command installed but test failed (may be normal)"
    fi
    echo ""
    echo "📖 Usage: slink [options]"
    echo "   Run 'slink --help' for more information"
else
    echo "❌ Installation failed!"
    exit 1
fi

