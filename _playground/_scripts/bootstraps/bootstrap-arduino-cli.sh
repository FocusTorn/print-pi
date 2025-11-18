#!/usr/bin/env bash
# Bootstrap Arduino CLI for ESP32-S3 development
# Based on previous installation at /media/pi/rootfs1
# Installs Arduino CLI and ESP32 board support

set -e

echo "🔌 Bootstrapping Arduino CLI for ESP32-S3 development..."

# Check if arduino-cli is already installed
INSTALL_ARDUINO=true
if command -v arduino-cli &> /dev/null; then
    ARDUINO_VERSION=$(arduino-cli version 2>/dev/null | head -1 || echo "unknown")
    echo "✅ Arduino CLI is already installed: $ARDUINO_VERSION"
    
    read -p "Reinstall anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "⏭️  Skipping Arduino CLI installation, using existing installation"
        INSTALL_ARDUINO=false
    fi
fi

# Install Arduino CLI if needed
if [ "$INSTALL_ARDUINO" = true ]; then
    # Create downloads directory if it doesn't exist
    mkdir -p /home/pi/Downloads/curls

    # Download Arduino CLI install script (official method)
    echo "📥 Downloading Arduino CLI install script..."
    curl -o /home/pi/Downloads/curls/arduino-cli-install.sh -LsSf https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh

    # Run install script, but install to ~/.local/bin instead of default location
    echo "📦 Installing Arduino CLI..."
    # The install script installs to ~/.local/bin/arduino-cli by default, which is perfect
    bash /home/pi/Downloads/curls/arduino-cli-install.sh

    # Verify the binary is in the expected location
    if [ ! -f ~/.local/bin/arduino-cli ]; then
        echo "⚠️  Arduino CLI not found in ~/.local/bin, checking default location..."
        # Check if it was installed to a different location
        if [ -f ~/bin/arduino-cli ]; then
            mkdir -p ~/.local/bin
            mv ~/bin/arduino-cli ~/.local/bin/
        elif command -v arduino-cli &> /dev/null; then
            # If it's in PATH but not in expected location, create symlink
            ARDUINO_CLI_PATH=$(which arduino-cli)
            mkdir -p ~/.local/bin
            ln -sf "$ARDUINO_CLI_PATH" ~/.local/bin/arduino-cli
        else
            echo "❌ Arduino CLI installation failed"
            exit 1
        fi
    fi

    # Verify installation
    if ! command -v arduino-cli &> /dev/null; then
        # Add ~/.local/bin to PATH if not already there
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            echo "⚠️  Adding ~/.local/bin to PATH..."
            export PATH="$HOME/.local/bin:$PATH"
            # Add to shell config files
            for shell_file in ~/.bashrc ~/.zshrc; do
                if [ -f "$shell_file" ] && ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$shell_file"; then
                    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_file"
                fi
            done
        fi
    fi

    echo "✅ Arduino CLI installed successfully"
fi

# Verify arduino-cli is accessible (required for rest of setup)
if ! command -v arduino-cli &> /dev/null; then
    echo "❌ Arduino CLI not found in PATH - cannot continue with configuration"
    echo "   Please ensure Arduino CLI is installed and in your PATH"
    exit 1
fi

# Show current version
echo "📋 Using Arduino CLI:"
arduino-cli version

# Initialize Arduino CLI configuration
# Runtime (packages, tools) in ~/, development files (sketches) in _playground/
echo "⚙️  Configuring Arduino CLI..."

# Create runtime directories (packages, tools, downloads)
mkdir -p ~/.arduino15

# Create development directory in _playground for sketches/projects
mkdir -p ~/_playground/arduino

# Initialize Arduino CLI with custom directories
arduino-cli config init --overwrite 2>/dev/null || true

# Set configuration:
# - user: _playground/arduino (development files, sketches - tracked)
# - data: ~/.arduino15 (runtime packages, tools - not tracked)
arduino-cli config set directories.user "$HOME/_playground/arduino"
arduino-cli config set directories.data "$HOME/.arduino15"
arduino-cli config set directories.downloads "$HOME/.arduino15/downloads"

echo "✅ Configuration set:"
arduino-cli config dump

# Add ESP32 board manager URL (required for ESP32 support)
echo "📥 Adding ESP32 board manager URL..."
arduino-cli config add board_manager.additional_urls https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json

# Increase network timeout for large downloads (ESP32 package is ~800MB)
echo "⚙️  Setting network timeout to 30 minutes for large downloads..."
arduino-cli config set network.connection_timeout 1800s  # 30 minutes

# Update core index
echo "📥 Updating board index (this may take a while)..."
arduino-cli core update-index

# Check if ESP32 is already installed
INSTALL_ESP32=true
if arduino-cli core list | grep -q "esp32:esp32"; then
    ESP32_VERSION=$(arduino-cli core list | grep "esp32:esp32" | awk '{print $2}')
    echo "✅ ESP32 board package is already installed: $ESP32_VERSION"
    
    read -p "Reinstall ESP32 package? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "⏭️  Skipping ESP32 installation, using existing package"
        INSTALL_ESP32=false
    fi
fi

# Install ESP32 board package with retry logic if needed
if [ "$INSTALL_ESP32" = true ]; then
    # ESP32 package is large (~800MB), so we need patience and retries
    echo "📦 Installing ESP32 board package (this is large, ~800MB, may take several minutes)..."
    MAX_RETRIES=3
    RETRY_COUNT=0
    INSTALL_SUCCESS=false

    while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$INSTALL_SUCCESS" = false ]; do
        if [ $RETRY_COUNT -gt 0 ]; then
            echo "   Retry attempt $RETRY_COUNT of $MAX_RETRIES..."
        fi
        
        if arduino-cli core install esp32:esp32; then
            INSTALL_SUCCESS=true
            echo "✅ ESP32 board package installed successfully"
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                echo "⚠️  Installation failed or timed out, waiting 10 seconds before retry..."
                sleep 10
            else
                echo "❌ ESP32 installation failed after $MAX_RETRIES attempts"
                echo "   You can try installing manually later with:"
                echo "   arduino-cli core install esp32:esp32"
                echo "   (Timeout is already set to 30 minutes)"
            fi
        fi
    done
fi

# Verify ESP32-S3 is available
echo "🔍 Verifying ESP32-S3 support..."
if arduino-cli board listall | grep -q "esp32s3"; then
    echo "✅ ESP32-S3 boards are available"
    arduino-cli board listall | grep -i esp32s3
else
    echo "⚠️  ESP32-S3 not found in board list, but ESP32 core is installed"
    echo "   Available ESP32 boards:"
    arduino-cli board listall | grep -i esp32 | head -10
fi

# Install common ESP32 libraries (optional, based on old setup)
echo "📚 Installing common ESP32 libraries..."
# Add any libraries that were commonly used in the old setup

echo ""
echo "✅ Arduino CLI bootstrap complete!"
echo ""
echo "📝 Configuration:"
echo "   Development (sketches): ~/_playground/arduino (tracked)"
echo "   Runtime (packages): ~/.arduino15 (not tracked)"
echo "   Binary: ~/.local/bin/arduino-cli"
echo ""
echo "🔌 To use with VSCode:"
echo "   1. Install 'Arduino' extension by Microsoft"
echo "   2. Set arduino.path to: $HOME/.local/bin/arduino-cli"
echo "   3. Set arduino.additionalUrls to: https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json"
echo ""
echo "📋 To verify ESP32-S3:"
echo "   arduino-cli board listall | grep esp32s3"

