#!/bin/bash
# BME680 Service Installation Script
# Installs self-contained package to ~/.local/share/bme680-service/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR"
DETECTOR="$PACKAGE_DIR/detectors/detect-bme680.sh"
SERVICE_DIR="$PACKAGE_DIR/services"
DATA_DIR="$PACKAGE_DIR/data"

# Installation paths
INSTALL_ROOT="$HOME/.local/share/bme680-service"
INSTALL_BIN="$HOME/.local/bin"
VENV_DIR="$INSTALL_ROOT/.venv"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${CYAN}  BME680 Service Installation${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Detect BME680 sensor
detect_sensor() {
    print_info "Detecting BME680 sensor on I2C bus 1..."
    print_info "Checking both addresses (0x76 and 0x77) and verifying chip ID (0x61)..."
    
    if [ ! -f "$DETECTOR" ]; then
        print_error "Sensor detector script not found: $DETECTOR"
        exit 1
    fi
    
    chmod +x "$DETECTOR"
    
    # Run detector - checks both 0x76 and 0x77, verifies chip ID 0x61
    if SENSOR_ADDR=$("$DETECTOR" 1 2>/dev/null); then
        # Clean up output (first line is the detected address)
        SENSOR_ADDR=$(echo "$SENSOR_ADDR" | head -1 | tr -d '\n\r')
        
        print_success "BME680 sensor detected at I2C address: $SENSOR_ADDR"
        print_info "  ✓ Verified chip ID: 0x61 (confirmed BME680, not another sensor)"
        print_info "  ✓ Checked both addresses: 0x76 and 0x77"
        
        return 0
    else
        print_warning "BME680 sensor not detected on I2C bus 1"
        print_info "Verification performed:"
        
        # Check what's actually at each address
        CHECK_76=$(i2cget -y 1 0x76 0xD0 b 2>/dev/null || echo "none")
        CHECK_77=$(i2cget -y 1 0x77 0xD0 b 2>/dev/null || echo "none")
        
        if [ "$CHECK_76" != "none" ]; then
            if [ "$CHECK_76" = "0x61" ]; then
                print_info "  • Address 0x76: BME680 detected (chip ID 0x61)"
            else
                print_info "  • Address 0x76: Device present but chip ID is $CHECK_76 (not BME680)"
            fi
        else
            print_info "  • Address 0x76: No device"
        fi
        
        if [ "$CHECK_77" != "none" ]; then
            if [ "$CHECK_77" = "0x61" ]; then
                print_info "  • Address 0x77: BME680 detected (chip ID 0x61)"
            else
                print_info "  • Address 0x77: Device present but chip ID is $CHECK_77 (not BME680)"
            fi
        else
            print_info "  • Address 0x77: No device"
        fi
        print_info ""
        print_info "Checking if I2C is enabled..."
        
        if [ ! -c /dev/i2c-1 ]; then
            print_error "I2C device /dev/i2c-1 not found"
            print_info "Enable I2C in raspi-config: sudo raspi-config → Interface Options → I2C"
            exit 1
        fi
        
        print_warning "I2C is enabled but no BME680 detected"
        print_info "Possible reasons:"
        print_info "  • Sensor not connected or powered"
        print_info "  • Wrong I2C address (check SDO pin wiring)"
        print_info "  • Different sensor model (not BME680)"
        print_info ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Installation cancelled"
            exit 1
        fi
        return 1
    fi
}

# Install package files
install_package_files() {
    print_info "Installing package files to $INSTALL_ROOT..."
    
    # Create installation directory
    mkdir -p "$INSTALL_ROOT"
    
    # Copy monitor library
    if [ -d "$DATA_DIR/monitor" ]; then
        print_info "  Copying BME680 library..."
        cp -r "$DATA_DIR/monitor" "$INSTALL_ROOT/"
        print_success "  BME680 library installed"
    else
        print_error "Monitor library not found in package: $DATA_DIR/monitor"
        exit 1
    fi
    
    # Copy monitor scripts
    if [ -f "$DATA_DIR/monitor-iaq.py" ]; then
        cp "$DATA_DIR/monitor-iaq.py" "$INSTALL_ROOT/"
        chmod +x "$INSTALL_ROOT/monitor-iaq.py"
        print_success "  monitor-iaq.py installed"
    fi
    
    if [ -f "$DATA_DIR/monitor-temperature.py" ]; then
        cp "$DATA_DIR/monitor-temperature.py" "$INSTALL_ROOT/"
        chmod +x "$INSTALL_ROOT/monitor-temperature.py"
        print_success "  monitor-temperature.py installed"
    fi
    
    # Install CLI tool to ~/.local/bin
    if [ -f "$DATA_DIR/bme680-cli" ]; then
        mkdir -p "$INSTALL_BIN"
        cp "$DATA_DIR/bme680-cli" "$INSTALL_BIN/"
        chmod +x "$INSTALL_BIN/bme680-cli"
        print_success "  bme680-cli installed to $INSTALL_BIN"
    fi
    
    # Create config directory
    mkdir -p "$INSTALL_ROOT/config"
    
    print_success "Package files installed"
}

# Create virtual environment and install dependencies
setup_python_environment() {
    print_info "Setting up Python virtual environment..."
    
    # Check for Python 3
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 not found. Please install Python 3."
        exit 1
    fi
    
    PYTHON_VERSION=$(python3 --version)
    print_info "  Using $PYTHON_VERSION"
    
    # Create virtual environment
    if [ ! -d "$VENV_DIR" ]; then
        print_info "  Creating virtual environment..."
        python3 -m venv "$VENV_DIR"
        print_success "  Virtual environment created"
    else
        print_info "  Virtual environment already exists, updating..."
    fi
    
    # Activate venv and upgrade pip
    print_info "  Upgrading pip..."
    "$VENV_DIR/bin/pip" install --upgrade pip --quiet
    
    # Install dependencies
    if [ -f "$DATA_DIR/requirements.txt" ]; then
        print_info "  Installing dependencies from requirements.txt..."
        "$VENV_DIR/bin/pip" install -r "$DATA_DIR/requirements.txt" --quiet
        print_success "  Dependencies installed"
    else
        print_warning "requirements.txt not found, skipping dependency installation"
    fi
    
    print_success "Python environment ready"
}

# Install systemd service
install_service() {
    local service_name=$1
    local service_file="$SERVICE_DIR/$service_name.service"
    
    if [ ! -f "$service_file" ]; then
        print_error "Service file not found: $service_file"
        return 1
    fi
    
    print_info "Installing $service_name service..."
    
    # Copy service file
    cp "$service_file" "/etc/systemd/system/$service_name.service"
    print_success "Service file copied to /etc/systemd/system/"
    
    # Reload systemd
    systemctl daemon-reload
    print_success "Systemd daemon reloaded"
    
    # Enable service
    systemctl enable "$service_name.service"
    print_success "Service enabled (will start on boot)"
    
    # Check if service should be started
    if systemctl is-active --quiet "$service_name.service" 2>/dev/null; then
        print_info "Service is already running"
    else
        print_info "Starting $service_name service..."
        if systemctl start "$service_name.service"; then
            print_success "Service started successfully"
        else
            print_warning "Service start failed, check status with: systemctl status $service_name"
        fi
    fi
}

# Main installation
main() {
    print_header
    
    # Auto-elevate if needed (must be first)
    if [ "$EUID" -ne 0 ]; then
        print_info "Elevating privileges..."
        exec sudo "$0" "$@"
    fi
    
    detect_sensor
    
    echo
    print_info "Installing BME680 service package..."
    echo
    
    # Install package files
    install_package_files
    
    # Setup Python environment
    setup_python_environment
    
    echo
    print_info "Which services would you like to install?"
    echo "  1) IAQ Monitor (recommended)"
    echo "  2) Temperature Monitor"
    echo "  3) Both"
    echo "  4) Cancel"
    read -p "Choice [1-4]: " choice
    
    case $choice in
        1)
            install_service "bme680-iaq"
            ;;
        2)
            install_service "bme680-temperature"
            ;;
        3)
            install_service "bme680-iaq"
            install_service "bme680-temperature"
            ;;
        4)
            print_info "Installation cancelled"
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
    
    echo
    print_success "Installation complete!"
    echo
    print_info "Package installed to: $INSTALL_ROOT"
    print_info "Virtual environment: $VENV_DIR"
    echo
    print_info "Useful commands:"
    echo "  systemctl status bme680-iaq          # Check IAQ service status"
    echo "  systemctl status bme680-temperature   # Check temperature service status"
    echo "  journalctl -u bme680-iaq -f           # Follow IAQ service logs"
    echo "  journalctl -u bme680-temperature -f  # Follow temperature service logs"
    echo "  $PACKAGE_DIR/uninstall.sh  # Uninstall (auto-elevates)"
}

main "$@"
