#!/bin/bash
# Bootstrap BME680 Monitoring Service
# Installs systemd services for BME680 sensor monitoring

set -e

PACKAGE_DIR="/home/pi/_playground/_dev/packages/bme680-service"
INSTALL_SCRIPT="$PACKAGE_DIR/install.sh"

echo "🌡️  Bootstrapping BME680 Monitoring Service..."
echo

# Check if package exists
if [ ! -f "$INSTALL_SCRIPT" ]; then
    echo "❌ BME680 service package not found at: $PACKAGE_DIR"
    echo "   Ensure _playground repository is properly cloned"
    exit 1
fi

# Note: Package is self-contained, no external dependencies needed

# Run installer (auto-elevates if needed)
echo "🔧 Running BME680 service installer..."
echo "   (You may be prompted for sudo password)"
echo

"$INSTALL_SCRIPT"

echo
echo "✅ BME680 service bootstrap complete!"

