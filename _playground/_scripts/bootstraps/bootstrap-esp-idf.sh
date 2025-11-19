#!/usr/bin/env bash
# Bootstrap ESP-IDF for ESP32-S3 development
# Installs ESP-IDF framework and sets up development environment

set -e

echo "🔌 Bootstrapping ESP-IDF for ESP32-S3 development..."

# Check if ESP-IDF is already installed
INSTALL_IDF=true
if [ -d "$HOME/esp/esp-idf" ] && command -v idf.py &> /dev/null; then
    echo "✅ ESP-IDF appears to be installed"
    echo "   Location: $HOME/esp/esp-idf"
    
    read -p "Reinstall anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "⏭️  Skipping ESP-IDF installation, using existing installation"
        INSTALL_IDF=false
    fi
fi

# Check Python (should already be installed)
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found. Please install Python 3.6+ first."
    exit 1
fi

PYTHON_VERSION=$(python3 --version)
echo "✅ Python found: $PYTHON_VERSION"

# Check pip (should already be installed)
if ! python3 -m pip --version &> /dev/null && ! pip3 --version &> /dev/null; then
    echo "⚠️  pip not found. ESP-IDF install script may need it."
    echo "   Consider installing: sudo apt install python3-pip"
else
    echo "✅ pip found"
fi

# Install prerequisites (Python and pip should already be installed)
echo "📦 Installing prerequisites..."
sudo apt update
sudo apt install -y \
    git \
    wget \
    flex \
    bison \
    gperf \
    cmake \
    ninja-build \
    ccache \
    libffi-dev \
    libssl-dev \
    dfu-util \
    libusb-1.0-0

echo "ℹ️  Note: ESP-IDF will create its own Python virtual environment in ~/.espressif/python-env"
echo "   This is separate from your uv-managed environments."
echo "   ESP-IDF's install.sh script will use pip internally to install dependencies."

# Install ESP-IDF if needed
if [ "$INSTALL_IDF" = true ]; then
    echo "📥 Installing ESP-IDF..."
    
    # Create esp directory
    mkdir -p ~/esp
    cd ~/esp
    
    # Clone ESP-IDF (using release/v5.1 for stability, or master for latest)
    if [ ! -d "esp-idf" ]; then
        echo "📥 Cloning ESP-IDF repository..."
        git clone --recursive https://github.com/espressif/esp-idf.git
    else
        echo "📥 Updating existing ESP-IDF repository..."
        cd esp-idf
        git pull
        git submodule update --init --recursive
        cd ..
    fi
    
    cd esp-idf
    
    # Run install script
    echo "🔧 Running ESP-IDF install script..."
    ./install.sh esp32s3
    
    echo "✅ ESP-IDF installation complete!"
fi

# Set up environment
echo "⚙️  Setting up environment..."

# Add to .zshrc if not already there
if ! grep -q "ESP-IDF" ~/.zshrc; then
    cat >> ~/.zshrc << 'EOF'

# ┌────────────────────────────────────────────────────────────────────────────────────────────────┐
# │                                        ESP-IDF SETUP                                            │
# └────────────────────────────────────────────────────────────────────────────────────────────────┘

# ESP-IDF environment
if [ -f "$HOME/esp/esp-idf/export.sh" ]; then
    alias get_idf='. $HOME/esp/esp-idf/export.sh'
    # Uncomment the line below to auto-load ESP-IDF in every shell (slower startup)
    # . $HOME/esp/esp-idf/export.sh
fi
EOF
    echo "✅ Added ESP-IDF setup to ~/.zshrc"
    echo "   Run 'get_idf' to activate ESP-IDF environment, or restart your shell"
else
    echo "✅ ESP-IDF setup already in ~/.zshrc"
fi

# Create project directory structure
echo "📁 Creating project structure..."
mkdir -p ~/_playground/espidf/projects

# Create a simple hello world project template
PROJECT_TEMPLATE_DIR="$HOME/_playground/espidf/projects/hello_world_template"
if [ ! -d "$PROJECT_TEMPLATE_DIR" ]; then
    echo "📝 Creating hello_world project template..."
    mkdir -p "$PROJECT_TEMPLATE_DIR/main"
    
    cat > "$PROJECT_TEMPLATE_DIR/CMakeLists.txt" << 'CMAKE_EOF'
cmake_minimum_required(VERSION 3.16)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(hello_world)
CMAKE_EOF

    cat > "$PROJECT_TEMPLATE_DIR/main/CMakeLists.txt" << 'CMAKE_EOF'
idf_component_register(SRCS "main.c"
                    INCLUDE_DIRS ".")
CMAKE_EOF

    cat > "$PROJECT_TEMPLATE_DIR/main/main.c" << 'C_EOF'
#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"

static const char *TAG = "hello_world";

void app_main(void)
{
    ESP_LOGI(TAG, "Hello from ESP32-S3!");
    
    int count = 0;
    while (1) {
        ESP_LOGI(TAG, "Count: %d", count++);
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
C_EOF

    cat > "$PROJECT_TEMPLATE_DIR/README.md" << 'README_EOF'
# ESP32-S3 Hello World (ESP-IDF)

Simple ESP-IDF project template for ESP32-S3.

## Setup

1. Activate ESP-IDF environment:
   ```bash
   get_idf
   ```

2. Set target:
   ```bash
   idf.py set-target esp32s3
   ```

3. Build:
   ```bash
   idf.py build
   ```

4. Flash:
   ```bash
   idf.py -p /dev/ttyUSB0 flash
   ```

5. Monitor:
   ```bash
   idf.py -p /dev/ttyUSB0 monitor
   ```

## Project Structure

- `main/main.c` - Main application code
- `CMakeLists.txt` - Project build configuration
- `main/CMakeLists.txt` - Component build configuration
README_EOF

    echo "✅ Created hello_world template at $PROJECT_TEMPLATE_DIR"
fi

echo ""
echo "✅ ESP-IDF bootstrap complete!"
echo ""
echo "Next steps:"
echo "  1. Restart your shell or run: source ~/.zshrc"
echo "  2. Activate ESP-IDF: get_idf"
echo "  3. Create a project: ~/_playground/espidf/_scripts/new-project.sh my_project"
echo "     Or use template: cp -r ~/_playground/espidf/projects/hello_world_template my_project"
echo "  4. Set target: cd my_project && idf.py set-target esp32s3"
echo "  5. Build: idf.py build"
echo ""
echo "📁 ESP-IDF projects directory: ~/_playground/espidf/projects/"
echo "📚 Helper scripts: ~/_playground/espidf/_scripts/"
echo ""
echo "📚 Documentation: https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/"

