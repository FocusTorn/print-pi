#!/bin/bash
# BME680 Service Installation Script
# Installs self-contained package to ~/.local/share/bme680-service/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR"
DETECTOR="$PACKAGE_DIR/detectors/detect-bme680.sh"
SERVICE_DIR="$PACKAGE_DIR/services"
DATA_DIR="$PACKAGE_DIR/data"
MENU_SCRIPT="$PACKAGE_DIR/scripts/interactive-menu.sh"

# Capture original user's home directory (before sudo changes $HOME)
# Get home directory of the user who invoked sudo, or current user if not sudo'd
ORIGINAL_USER="${SUDO_USER:-$USER}"
ORIGINAL_HOME=$(getent passwd "$ORIGINAL_USER" | cut -d: -f6)

# Fallback if getent fails
if [ -z "$ORIGINAL_HOME" ]; then
    ORIGINAL_HOME="/home/$ORIGINAL_USER"
fi

# Installation paths - use original user's home, not root's
INSTALL_ROOT="$ORIGINAL_HOME/.local/share/bme680-service"
INSTALL_BIN="$ORIGINAL_HOME/.local/bin"
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
    
    # Check if uv is available (preferred) or fall back to python3 -m venv
    if command -v uv &> /dev/null; then
        # Use uv for venv creation and package management
        if [ ! -d "$VENV_DIR" ]; then
            print_info "  Creating virtual environment with uv..."
            uv venv "$VENV_DIR"
            print_success "  Virtual environment created"
        else
            print_info "  Virtual environment already exists, updating..."
        fi
        
        # Install dependencies with uv
        if [ -f "$DATA_DIR/requirements.txt" ]; then
            print_info "  Installing dependencies from requirements.txt with uv..."
            uv pip install -r "$DATA_DIR/requirements.txt" --python "$VENV_DIR/bin/python" --quiet
            print_success "  Dependencies installed"
        else
            print_warning "requirements.txt not found, skipping dependency installation"
        fi
    else
        # Fallback to traditional venv/pip
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
    
    # Copy service file and substitute user if needed
    # Use sed to replace User= in service file if it's generic
    if grep -q "User=pi" "$service_file"; then
        # Service file already has User=pi, use as-is
        cp "$service_file" "/etc/systemd/system/$service_name.service"
    else
        # Create service file with proper user
        sed "s|User=.*|User=$ORIGINAL_USER|g" "$service_file" > "/etc/systemd/system/$service_name.service"
    fi
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
    # Auto-elevate if needed (must be first)
    if [ "$EUID" -ne 0 ]; then
        # Preserve script path when elevating - use absolute path (no noisy output)
        local script_path="${BASH_SOURCE[0]}"
        if [ ! "${script_path:0:1}" = "/" ]; then
            script_path="$(cd "$(dirname "$script_path")" && pwd)/$(basename "$script_path")"
        fi
        exec sudo bash "$script_path" "$@"
    fi
    
    print_header
    
    # Always re-resolve paths after sudo (sudo changes working directory context)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PACKAGE_DIR="$SCRIPT_DIR"
    DETECTOR="$PACKAGE_DIR/detectors/detect-bme680.sh"
    SERVICE_DIR="$PACKAGE_DIR/services"
    DATA_DIR="$PACKAGE_DIR/data"
    MENU_SCRIPT="$PACKAGE_DIR/scripts/interactive-menu.sh"
    
    # Source menu functions (if available)
    local use_interactive_menu=false
    if [ -f "$MENU_SCRIPT" ] && source "$MENU_SCRIPT" && type interactive_menu >/dev/null 2>&1 && [ -t 0 ] && [ -t 1 ]; then
        use_interactive_menu=true
    else
        print_warning "Interactive menu unavailable; falling back to simple prompts."
    fi

    # State for wizard steps
    local step=1
    local install_readings=false
    local install_iaq=false
    local install_heat_soak=false
    local platform="mqtt"  # mqtt|ha (kept for backward compat)
    local install_broker="Y"
    local selected_indices_step1="0 1 2"
    local selected_indices_step2="0 1"
    local selected_indices_step0="0 1 2"  # default all selected

    while true; do
        if [ $step -eq 1 ]; then
            echo "[Space] Toggle   │  [Esc] Cancel"
            echo "[a] Toggle All   │  [b] Back"
            echo "[Enter] Confirm  │  [?] Help"
            echo
            print_info "Which services would you like to install?"
            if [ "$use_interactive_menu" = true ]; then
                local menu_options=(
                    "Sensor readings"
                    "IAQ (Air quality calculation, Safe to open flag)"
                    "Heat soak detection (Current enclosure temp, target enclosure temp, Rate of change [datapoints, value]"
                )
                local selected_result
                if [ -n "$selected_indices_step1" ]; then
                    selected_result=$(interactive_menu "${menu_options[@]}" --preselect "$selected_indices_step1")
                else
                    selected_result=$(interactive_menu "${menu_options[@]}")
                fi
                local rc=$?
                if [ $rc -eq 1 ]; then
                    print_info "Installation cancelled"; exit 0
                elif [ $rc -eq 2 ]; then
                    # Back from step 1 → cancel
                    print_info "Installation cancelled"; exit 0
                fi
                # reset flags
                install_readings=false; install_iaq=false; install_heat_soak=false
                for idx in $selected_result; do
                    case $idx in
                        0) install_readings=true ;;
                        1) install_iaq=true ;;
                        2) install_heat_soak=true ;;
                    esac
                done
                selected_indices_step1="$selected_result"
                if [ "$install_readings" = false ] && [ "$install_iaq" = false ] && [ "$install_heat_soak" = false ]; then
                    print_info "No services selected. Installation cancelled."; exit 0
                fi
            else
                echo "  1) Sensor readings"
                echo "  2) IAQ"
                echo "  3) Heat soak"
                echo "  4) All"
                echo "  5) Cancel"
                read -p "Choice [1-5]: " choice
                case $choice in
                    1) install_readings=true ;;
                    2) install_iaq=true ;;
                    3) install_heat_soak=true ;;
                    4) install_readings=true; install_iaq=true; install_heat_soak=true ;;
                    5) print_info "Installation cancelled"; exit 0 ;;
                    *) print_error "Invalid choice"; exit 1 ;;
                esac
            fi
            step=2
        elif [ $step -eq 2 ]; then
            # Installation type(s)
            if type clear_menu >/dev/null 2>&1; then clear_menu 5; fi
            echo "[Space] Toggle   │  [Esc] Cancel"
            echo "[a] Toggle All   │  [b] Back"
            echo "[Enter] Confirm  │  [?] Help"
            echo
            print_info "Which services would you like to install?"
            print_info "Which installation(s) would you like to perform?"
            if [ "$use_interactive_menu" = true ]; then
                local menu0=(
                    "Standalone MQTT"
                    "HA MQTT Receipt"
                    "HA Custom Integration"
                )
                local selected0
                selected0=$(interactive_menu "${menu0[@]}" --preselect "$selected_indices_step0")
                local rc0=$?
                if [ $rc0 -eq 1 ]; then print_info "Installation cancelled"; exit 0
                elif [ $rc0 -eq 2 ]; then step=1; continue; fi
                selected_indices_step0="$selected0"
                if [ -z "$selected_indices_step0" ]; then selected_indices_step0="0 1 2"; fi
            else
                echo "  1) Standalone MQTT"
                echo "  2) HA MQTT Receipt"
                echo "  3) HA Custom Integration"
                echo "  4) Back"
                echo "  5) Cancel"
                read -p "Choice [1-5]: " ch0
                case $ch0 in
                    1) selected_indices_step0="0" ;;
                    2) selected_indices_step0="1" ;;
                    3) selected_indices_step0="0 1 2" ;;
                    4) step=1; continue ;;
                    5) print_info "Installation cancelled"; exit 0 ;;
                    *) print_error "Invalid choice"; exit 1 ;;
                esac
            fi
            step=3
        elif [ $step -eq 3 ]; then
            # Determine selected platforms
            local want_mqtt=false
            local want_ha=false
            for idx in $selected_indices_step2; do
                case $idx in
                    0) want_mqtt=true ;;
                    1) want_ha=true ;;
                esac
            done
            if [ "$want_mqtt" = true ]; then
                # Clear previous platform menu lines so redraw doesn't climb
                if type clear_menu >/dev/null 2>&1; then
                    clear_menu 10
                fi
                echo "[Space] Toggle   │  [Esc] Cancel"
                echo "[b] Back        │  [Enter] Confirm"
                echo "[?] Help"
                if [ "$use_interactive_menu" = true ] && type yes_no_prompt >/dev/null 2>&1; then
                    yes_no_prompt "Install Mosquitto MQTT broker (y):" "Y"; rc=$?
                    if [ $rc -eq 1 ]; then install_broker="N"; elif [ $rc -eq 2 ]; then step=2; continue; else install_broker="Y"; fi
                else
                    read -p "Install Mosquitto MQTT broker? (Y/n): " ans; ans=${ans:-Y}; install_broker=$ans
                fi
            fi
            break
        fi
    done
    
    # Check if user cancelled (no services selected)
    if [ "$install_readings" = false ] && [ "$install_heat_soak" = false ]; then
        print_info "No services selected. Installation cancelled."
        exit 0
    fi
    
    # 2) Only now detect the sensor (after selection)
    echo
    detect_sensor
    
    # 3) Proceed with installation (after user selection and detection)
    echo
    print_info "Installing BME680 service package..."
    echo 
    
    # Install package files
    install_package_files
    
    # Setup Python environment
    setup_python_environment
    
    # Execute based on step 0 selections
    local do_standalone=false
    local do_ha_mqtt=false
    local do_ha_integration=false
    for idx in $selected_indices_step0; do
        case $idx in
            0) do_standalone=true ;;
            1) do_ha_mqtt=true ;;
            2) do_ha_integration=true ;;
        esac
    done

    if [ "$do_standalone" = true ] || [ "$do_ha_mqtt" = true ] || [ "$do_ha_integration" = true ]; then
        # Broker if MQTT path selected and user opted in
        if [ "$do_standalone" = true ] || [ "$do_ha_mqtt" = true ]; then
            if [[ "${install_broker^^}" = "Y" ]]; then
                print_info "Installing Mosquitto MQTT broker..."
                apt-get update -y >/dev/null 2>&1 || true
                apt-get install -y mosquitto mosquitto-clients >/dev/null 2>&1 || true
                systemctl enable --now mosquitto >/dev/null 2>&1 || true
                print_success "Mosquitto installed (or already present)."
            fi
        fi

        # Install services for base architecture
        if [ "$install_readings" = true ]; then install_service "bme680-base"; fi
        if [ "$install_iaq" = true ]; then install_service "bme680-iaq"; fi
        if [ "$install_heat_soak" = true ]; then install_service "bme680-heatsoak"; fi

        # HA MQTT wiring (install into HA packages and ensure include + mqtt: broker)
        if [ "$do_ha_mqtt" = true ]; then
            print_info "Configuring Home Assistant packages include and MQTT wiring..."
            local HA_CONF="$ORIGINAL_HOME/homeassistant/configuration.yaml"
            local HA_PKG_DIR="$ORIGINAL_HOME/homeassistant/packages"
            local ha_yaml_src="$PACKAGE_DIR/ha/sensors-bme680-mqtt.yaml"
            local ha_yaml_dst="$HA_PKG_DIR/bme680.yaml"
            if [ -f "$ha_yaml_src" ]; then
                mkdir -p "$HA_PKG_DIR"
                cp "$ha_yaml_src" "$ha_yaml_dst"
                print_success "Copied MQTT wiring to $ha_yaml_dst"
                # ensure packages include present
                if grep -Eq "^\s*packages:\s*!include_dir_named\s+packages" "$HA_CONF"; then
                    true
                elif grep -Eq "^homeassistant:\s*$" "$HA_CONF"; then
                    sed -i '/^homeassistant:\s*$/a\  packages: !include_dir_named packages' "$HA_CONF"
                    print_success "Added packages include under homeassistant:"
                else
                    printf '\n# Added by bme680 installer - Home Assistant packages include\n' >> "$HA_CONF"
                    printf 'homeassistant:\n  packages: !include_dir_named packages\n' >> "$HA_CONF"
                    print_success "Appended homeassistant: packages include"
                fi
                # Note: do not auto-add mqtt: broker block here; user configures MQTT integration
            else
                print_warning "HA MQTT YAML source not found (expected at $ha_yaml_src)."
            fi
        fi

        # HA Custom Integration scaffold (install into HA custom_components)
        if [ "$do_ha_integration" = true ]; then
            print_info "Installing Home Assistant custom integration..."
            local comp_src="$PACKAGE_DIR/ha/custom_components/bme680_monitor"
            local comp_dst="$ORIGINAL_HOME/homeassistant/custom_components/bme680_monitor"
            if [ -d "$comp_src" ]; then
                mkdir -p "$(dirname "$comp_dst")"
                rm -rf "$comp_dst"
                cp -r "$comp_src" "$comp_dst"
                print_success "Installed custom component to $comp_dst"
            else
                print_warning "Custom component scaffold not found at $comp_src"
            fi
        fi
    fi
    
    echo
    print_success "Installation complete!"
    echo
    print_info "Package installed to: $INSTALL_ROOT"
    print_info "Virtual environment: $VENV_DIR"
    echo
    print_info "Useful commands:"
    echo "  systemctl status bme680-base         # Raw readings"
    echo "  systemctl status bme680-iaq          # IAQ consumer"
    echo "  systemctl status bme680-heatsoak     # HeatSoak consumer"
}

main "$@"
