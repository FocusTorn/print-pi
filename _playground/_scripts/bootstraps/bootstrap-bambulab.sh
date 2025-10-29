#!/usr/bin/env bash
# Bootstrap Bambu Lab integration for Home Assistant
# Installs the Bambu Lab HACS integration

set -e

HA_CONFIG_DIR="/home/pi/homeassistant"
CUSTOM_COMPONENTS_DIR="${HA_CONFIG_DIR}/custom_components"
BAMBU_DIR="${CUSTOM_COMPONENTS_DIR}/bambu_lab"
DOWNLOAD_DIR="/home/pi/Downloads/curls"

echo "🖨️  Bootstrapping Bambu Lab integration..."
echo ""

# Check if HA config directory exists
if [ ! -d "$HA_CONFIG_DIR" ]; then
    echo "❌ Error: Home Assistant config directory not found at $HA_CONFIG_DIR"
    echo "   Run bootstrap-home-assistant.sh first!"
    exit 1
fi

# Check if Bambu Lab is already installed
if [ -d "$BAMBU_DIR" ]; then
    echo "⚠️  Bambu Lab integration is already installed at $BAMBU_DIR"
    read -p "Reinstall/Update? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Installation cancelled"
        exit 0
    fi
    echo "🗑️  Removing existing installation..."
    rm -rf "$BAMBU_DIR"
fi

# Create directories
echo "📁 Creating custom_components directory..."
mkdir -p "$CUSTOM_COMPONENTS_DIR"
mkdir -p "$DOWNLOAD_DIR"

# Get latest Bambu Lab release
echo "📥 Fetching latest Bambu Lab integration release..."
BAMBU_VERSION=$(curl -s https://api.github.com/repos/greghesp/ha-bambulab/releases/latest | grep '"tag_name"' | cut -d'"' -f4)

if [ -z "$BAMBU_VERSION" ]; then
    echo "❌ Error: Could not fetch latest Bambu Lab version"
    echo "   The repository might be at: https://github.com/greghesp/ha-bambulab"
    echo "   Or search HACS for 'Bambu Lab' integration"
    exit 1
fi

echo "📦 Latest version: $BAMBU_VERSION"

# Download Bambu Lab integration
DOWNLOAD_URL="https://github.com/greghesp/ha-bambulab/releases/download/${BAMBU_VERSION}/bambu_lab.zip"
echo "📥 Downloading Bambu Lab integration..."
if ! curl -L -o "${DOWNLOAD_DIR}/bambu_lab.zip" "$DOWNLOAD_URL" 2>/dev/null; then
    echo "❌ Error: Download failed"
    echo "   Try installing via HACS instead:"
    echo "   Settings → HACS → Integrations → Search 'Bambu Lab'"
    exit 1
fi

# Extract Bambu Lab
echo "📦 Extracting Bambu Lab integration..."
mkdir -p "$BAMBU_DIR"
unzip -q "${DOWNLOAD_DIR}/bambu_lab.zip" -d "$BAMBU_DIR"

# Verify installation
if [ -f "$BAMBU_DIR/manifest.json" ]; then
    echo "✅ Bambu Lab extracted successfully"
else
    echo "❌ Error: manifest.json not found after extraction"
    echo "   Try installing via HACS instead"
    exit 1
fi

# Fix permissions
echo "🔧 Setting permissions..."
sudo chown -R pi:pi "$CUSTOM_COMPONENTS_DIR"

# Clean up download
rm -f "${DOWNLOAD_DIR}/bambu_lab.zip"

echo ""
echo "✅ Bambu Lab integration installation complete!"
echo ""
echo "📋 Next Steps:"
echo "   1. Restart Home Assistant:"
echo "      ha restart"
echo ""
echo "   2. Clear browser cache (Ctrl+Shift+R)"
echo ""
echo "   3. Add Bambu Lab integration:"
echo "      • Go to Settings → Devices & Services"
echo "      • Click '+ Add Integration'"
echo "      • Search for 'Bambu Lab'"
echo "      • Enter your printer's IP address or cloud credentials"
echo ""
echo "   4. Configure printer:"
echo "      • Device serial number (on printer)"
echo "      • Access code (in printer settings)"
echo "      • Connection type: LAN or Cloud"
echo ""
echo "📖 Documentation:"
echo "   • GitHub: https://github.com/greghesp/ha-bambulab"
echo "   • Bambu Wiki: https://wiki.bambulab.com/"
echo ""
echo "💡 Tip: For LAN mode, enable LAN-only mode in Bambu Studio:"
echo "   Device → Network → LAN Only Mode → Enable"
echo ""

# Ask if user wants to restart now
read -p "Restart Home Assistant now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔄 Restarting Home Assistant..."
    ha restart
else
    echo "⚠️  Remember to restart Home Assistant to load Bambu Lab:"
    echo "   ha restart"
fi

