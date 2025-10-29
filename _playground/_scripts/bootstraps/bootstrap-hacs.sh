#!/usr/bin/env bash
# Install HACS (Home Assistant Community Store)
# https://hacs.xyz/

set -e

HA_CONFIG_DIR="/home/pi/homeassistant"
CUSTOM_COMPONENTS_DIR="${HA_CONFIG_DIR}/custom_components"
HACS_DIR="${CUSTOM_COMPONENTS_DIR}/hacs"
DOWNLOAD_DIR="/home/pi/Downloads/curls"

echo "🏪 Installing HACS (Home Assistant Community Store)..."
echo ""

# Check if HA config directory exists
if [ ! -d "$HA_CONFIG_DIR" ]; then
    echo "❌ Error: Home Assistant config directory not found at $HA_CONFIG_DIR"
    echo "   Run bootstrap-home-assistant.sh first!"
    exit 1
fi

# Check if HACS is already installed
if [ -d "$HACS_DIR" ]; then
    echo "⚠️  HACS is already installed at $HACS_DIR"
    read -p "Reinstall/Update HACS? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Installation cancelled"
        exit 0
    fi
    echo "🗑️  Removing existing HACS installation..."
    rm -rf "$HACS_DIR"
fi

# Create directories
echo "📁 Creating custom_components directory..."
mkdir -p "$CUSTOM_COMPONENTS_DIR"
mkdir -p "$DOWNLOAD_DIR"

# Get latest HACS release
echo "📥 Fetching latest HACS release..."
HACS_VERSION=$(curl -s https://api.github.com/repos/hacs/integration/releases/latest | grep '"tag_name"' | cut -d'"' -f4)

if [ -z "$HACS_VERSION" ]; then
    echo "❌ Error: Could not fetch latest HACS version"
    exit 1
fi

echo "📦 Latest HACS version: $HACS_VERSION"

# Download HACS
DOWNLOAD_URL="https://github.com/hacs/integration/releases/download/${HACS_VERSION}/hacs.zip"
echo "📥 Downloading HACS..."
curl -L -o "${DOWNLOAD_DIR}/hacs.zip" "$DOWNLOAD_URL"

# Extract HACS
echo "📦 Extracting HACS..."
mkdir -p "$HACS_DIR"
unzip -q "${DOWNLOAD_DIR}/hacs.zip" -d "$HACS_DIR"

# Verify installation
if [ -f "$HACS_DIR/manifest.json" ]; then
    echo "✅ HACS extracted successfully"
else
    echo "❌ Error: HACS manifest.json not found after extraction"
    exit 1
fi

# Fix permissions
echo "🔧 Setting permissions..."
sudo chown -R pi:pi "$CUSTOM_COMPONENTS_DIR"

# Clean up download
rm -f "${DOWNLOAD_DIR}/hacs.zip"

echo ""
echo "✅ HACS installation complete!"
echo ""
echo "📋 Next Steps:"
echo "   1. Restart Home Assistant:"
echo "      ha restart"
echo ""
echo "   2. Clear browser cache (Ctrl+Shift+R)"
echo ""
echo "   3. Add HACS integration:"
echo "      • Go to Settings → Devices & Services"
echo "      • Click '+ Add Integration'"
echo "      • Search for 'HACS'"
echo "      • Follow the setup wizard"
echo ""
echo "   4. Authenticate with GitHub:"
echo "      • You'll need a GitHub account"
echo "      • Follow the device activation flow"
echo ""
echo "📖 Documentation: https://hacs.xyz/docs/configuration/basic"
echo ""
echo "🔄 To restart Home Assistant now, run:"
echo "   ha restart"
echo ""

# Ask if user wants to restart now
read -p "Restart Home Assistant now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔄 Restarting Home Assistant..."
    ha restart
else
    echo "⚠️  Remember to restart Home Assistant to load HACS:"
    echo "   ha restart"
fi

