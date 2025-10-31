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
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔧 Configure Printer"
echo ""
echo "You can configure the A1 printer now or later via web UI:"
echo ""
read -p "Configure printer now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "📝 Printer Configuration"
    echo ""
    
    # Get connection type
    echo "Connection Type:"
    echo "  1) LAN Mode (Direct IP, recommended for automation)"
    echo "  2) Cloud Mode (Bambu Cloud, requires account)"
    echo "  3) Skip (configure via web UI later)"
    read -p "Choose (1/2/3): " -n 1 -r
    CONNECTION_TYPE="$REPLY"
    echo ""
    echo ""
    
    if [[ "$CONNECTION_TYPE" == "1" ]]; then
        # LAN Mode configuration
        echo "LAN Mode Setup:"
        read -p "Printer Serial Number (e.g., 03919D532705945): " SERIAL
        read -p "Printer IP Address (e.g., 192.168.1.163): " HOST
        read -p "Access Code (8 digits from printer settings): " ACCESS_CODE
        read -p "Printer Name (optional, default: A1): " PRINTER_NAME
        PRINTER_NAME="${PRINTER_NAME:-A1}"
        
        echo ""
        echo "📋 Configuration Summary:"
        echo "   Serial: $SERIAL"
        echo "   IP: $HOST"
        echo "   Access Code: $ACCESS_CODE"
        echo "   Name: $PRINTER_NAME"
        echo ""
        read -p "Create configuration entry? (y/N): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "💾 Creating configuration entry..."
            
            # Generate entry_id (simplified - HA will regenerate if needed)
            ENTRY_ID=$(python3 -c "import secrets; print(secrets.token_urlsafe(16))" | head -c 25)
            TIMESTAMP=$(python3 -c "from datetime import datetime; print(datetime.utcnow().isoformat() + '+00:00')")
            
            # Create config entry JSON structure
            python3 << PYEOF
import json
import sys
from datetime import datetime

config_file = "${HA_CONFIG_DIR}/.storage/core.config_entries"

try:
    # Read existing config
    with open(config_file, 'r') as f:
        data = json.load(f)
    
    # Check if entry already exists
    existing = False
    for entry in data['data']['entries']:
        if entry.get('domain') == 'bambu_lab' and entry.get('data', {}).get('serial') == '${SERIAL}':
            print(f"⚠️  Configuration entry already exists for serial ${SERIAL}")
            existing = True
            break
    
    if not existing:
        # Create new entry
        new_entry = {
            "created_at": "${TIMESTAMP}",
            "data": {
                "device_type": "A1",
                "serial": "${SERIAL}"
            },
            "disabled_by": None,
            "discovery_keys": {},
            "domain": "bambu_lab",
            "entry_id": "${ENTRY_ID}",
            "minor_version": 1,
            "modified_at": "${TIMESTAMP}",
            "options": {
                "access_code": "${ACCESS_CODE}",
                "auth_token": "",
                "disable_ssl_verify": False,
                "email": "",
                "enable_firmware_update": False,
                "force_ip": False,
                "host": "${HOST}",
                "local_mqtt": True,
                "name": "${PRINTER_NAME}",
                "print_cache_count": 100,
                "region": "",
                "timelapse_cache_count": 1,
                "usage_hours": 0.0,
                "username": ""
            },
            "pref_disable_new_entities": False,
            "pref_disable_polling": False,
            "source": "user",
            "subentries": [],
            "title": "${SERIAL}",
            "unique_id": None,
            "version": 2
        }
        
        data['data']['entries'].append(new_entry)
        
        # Backup original
        import shutil
        shutil.copy(config_file, config_file + '.bak')
        
        # Write updated config
        with open(config_file, 'w') as f:
            json.dump(data, f)
        
        print("✅ Configuration entry created!")
        print("   Note: You may need to restart HA and verify connection in web UI")
    else:
        print("   Use web UI to update existing entry if needed")
        
except Exception as e:
    print(f"❌ Error creating config entry: {e}")
    print("   You can configure via web UI instead")
    sys.exit(1)
PYEOF
            
            if [ $? -eq 0 ]; then
                echo ""
                echo "✅ Configuration saved!"
                echo "   The entry will be validated when Home Assistant restarts"
            fi
        fi
        
    elif [[ "$CONNECTION_TYPE" == "2" ]]; then
        echo ""
        echo "⚠️  Cloud Mode requires interactive authentication"
        echo "   Please configure via web UI:"
        echo "   Settings → Devices & Services → Add Integration → Bambu Lab"
        echo ""
    fi
else
    echo ""
    echo "📋 Configuration can be done later via web UI"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Next Steps:"
echo "   1. Restart Home Assistant:"
echo "      ha restart"
echo ""
echo "   2. Clear browser cache (Ctrl+Shift+R)"
echo ""
if [[ "$CONNECTION_TYPE" != "1" ]] || [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "   3. Add Bambu Lab integration (if not configured above):"
    echo "      • Go to Settings → Devices & Services"
    echo "      • Click '+ Add Integration'"
    echo "      • Search for 'Bambu Lab'"
    echo "      • Enter your printer's IP address or cloud credentials"
    echo ""
fi
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

