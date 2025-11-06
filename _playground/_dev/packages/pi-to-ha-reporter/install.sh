#!/bin/bash
# Pi to Home Assistant Reporter Installation Script
# Installs self-contained package to ~/.local/share/pi-to-ha-reporter/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR"
SERVICE_DIR="$PACKAGE_DIR/services"
DATA_DIR="$PACKAGE_DIR/data"
CONFIG_DIR="$PACKAGE_DIR/config"

# Import logger utility
source "${SCRIPT_DIR}/../_utilities/logger/import.sh"

# Capture original user's home directory (before sudo changes $HOME)
ORIGINAL_USER="${SUDO_USER:-$USER}"
ORIGINAL_HOME=$(getent passwd "$ORIGINAL_USER" | cut -d: -f6)

# Fallback if getent fails
if [ -z "$ORIGINAL_HOME" ]; then
    ORIGINAL_HOME="/home/$ORIGINAL_USER"
fi

# Installation paths - use original user's home, not root's
INSTALL_ROOT="$ORIGINAL_HOME/.local/share/pi-to-ha-reporter"
INSTALL_CONFIG="$INSTALL_ROOT/config"
VENV_DIR="$INSTALL_ROOT/.venv"
SERVICE_NAME="pi-to-ha-reporter"

# Parse arguments
VERBOSE=false
ARGS=()
for arg in "$@"; do
    case $arg in
        --verbose|-v)
            VERBOSE=true
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
done
set -- "${ARGS[@]}"

# Initialize logger
logger_init "pi-to-ha-reporter"
# Debug is disabled by default, only enable if --verbose was passed
if [ "$VERBOSE" = "true" ]; then
    logger_set_debug true
fi

print_header() {
    echo "═══════════════════════════════════════"
    echo "  Pi to HA Reporter Installation"
    echo "═══════════════════════════════════════"
    echo
}

# Auto-elevate to root if needed
if [ "$EUID" -ne 0 ]; then
    logger_debug "This script requires sudo privileges for systemd service installation"
    logger_debug "Attempting to elevate privileges..."
    if [ "$VERBOSE" = "true" ]; then
        exec sudo "$0" --verbose "$@"
    else
        exec sudo "$0" "$@"
    fi
fi

# Verify we're running as root
if [ "$EUID" -ne 0 ]; then
    logger_error "This script must be run as root (or with sudo)"
    exit 1
fi

install_package_files() {
    logger_debug "Installing package files to $INSTALL_ROOT..."
    
    # Create installation directory
    mkdir -p "$INSTALL_ROOT"
    mkdir -p "$INSTALL_CONFIG"
    
    # Copy data files
    logger_debug "Copying script files..."
    cp "$DATA_DIR/pi-to-ha-reporter.py" "$INSTALL_ROOT/"
    chmod +x "$INSTALL_ROOT/pi-to-ha-reporter.py"
    
    # Copy config template if it doesn't exist
    if [ ! -f "$INSTALL_CONFIG/config.ini" ]; then
        logger_debug "Creating configuration file from template..."
        cp "$CONFIG_DIR/config.ini.dist" "$INSTALL_CONFIG/config.ini"
        chown -R "$ORIGINAL_USER:$ORIGINAL_USER" "$INSTALL_CONFIG"
        logger_success "Configuration file created at $INSTALL_CONFIG/config.ini"
    else
        logger_debug "Configuration file already exists, skipping..."
    fi
    
    # Set ownership
    chown -R "$ORIGINAL_USER:$ORIGINAL_USER" "$INSTALL_ROOT"
    
    logger_success "Package files installed"
}

setup_python_environment() {
    logger_debug "Setting up Python virtual environment..."
    
    # Check if uv is available
    if ! command -v uv &> /dev/null; then
        logger_debug "⚠️ uv not found, checking for python3-venv..."
        
        # Use system venv
        if [ -d "$VENV_DIR" ]; then
            logger_debug "Virtual environment already exists, skipping creation..."
        else
            sudo -u "$ORIGINAL_USER" python3 -m venv "$VENV_DIR"
            logger_success "Created virtual environment using python3-venv"
        fi
        
        # Install dependencies
        logger_debug "Installing Python dependencies..."
        sudo -u "$ORIGINAL_USER" "$VENV_DIR/bin/pip" install --upgrade pip wheel >/dev/null 2>&1
        sudo -u "$ORIGINAL_USER" "$VENV_DIR/bin/pip" install -r "$DATA_DIR/requirements.txt" >/dev/null 2>&1
    else
        # Use uv (faster)
        if [ -d "$VENV_DIR" ]; then
            logger_debug "Virtual environment already exists, skipping creation..."
        else
            sudo -u "$ORIGINAL_USER" uv venv "$VENV_DIR"
            logger_success "Created virtual environment using uv"
        fi
        
        # Install dependencies
        logger_debug "Installing Python dependencies..."
        sudo -u "$ORIGINAL_USER" uv pip install -r "$DATA_DIR/requirements.txt" --python "$VENV_DIR/bin/python" >/dev/null 2>&1 || \
        sudo -u "$ORIGINAL_USER" "$VENV_DIR/bin/pip" install -r "$DATA_DIR/requirements.txt" >/dev/null 2>&1
    fi
    
    logger_success "Python environment set up"
}

install_service() {
    local service_file="$SERVICE_DIR/${SERVICE_NAME}.service"
    
    if [ ! -f "$service_file" ]; then
        logger_error "Service file not found: $service_file"
        exit 1
    fi
    
    logger_debug "Installing systemd service..."
    
    # Get user's primary group
    ORIGINAL_GROUP=$(id -gn "$ORIGINAL_USER" 2>/dev/null || echo "$ORIGINAL_USER")
    
    # Replace %i and %h placeholders with actual user and home
    sed "s|User=%i|User=$ORIGINAL_USER|g; s|Group=%i|Group=$ORIGINAL_GROUP|g; s|%h|$ORIGINAL_HOME|g" "$service_file" > "/etc/systemd/system/${SERVICE_NAME}.service"
    
    # Reload systemd
    systemctl daemon-reload
    
    logger_success "Service file installed to /etc/systemd/system/${SERVICE_NAME}.service"
}

enable_service() {
    logger_debug "Enabling service to start on boot..."
    systemctl enable "${SERVICE_NAME}.service" >/dev/null 2>&1 || true
    logger_success "Service enabled"
    
    logger_debug "Starting service..."
    if systemctl start "${SERVICE_NAME}.service"; then
        logger_success "Service started successfully"
    else
        logger_warn "Service failed to start (this may be expected if MQTT broker is not configured)"
        logger_info "Check status with: systemctl status ${SERVICE_NAME}"
    fi
}

main() {
    print_header
    
    logger_debug "Installation details:"
    logger_debug "   User: $ORIGINAL_USER"
    logger_debug "   Home: $ORIGINAL_HOME"
    logger_debug "   Install path: $INSTALL_ROOT"
    echo
    
    # Check if MQTT broker is running
    if systemctl is-active --quiet mosquitto 2>/dev/null; then
        logger_success "Mosquitto MQTT broker is running"
    else
        logger_warn "Mosquitto MQTT broker not detected (service may fail to start)"
        logger_debug "  Install with: sudo apt-get install mosquitto mosquitto-clients"
    fi
    echo
    
    # Install package files
    install_package_files
    
    # Setup Python environment
    setup_python_environment
    
    # Install systemd service
    install_service
    
    # Enable and start service
    enable_service
    
    echo
    logger_success "Installation complete!"
    echo
    logger_info "Package installed to: $INSTALL_ROOT"
    logger_info "Virtual environment: $VENV_DIR"
    logger_info "Configuration: $INSTALL_CONFIG/config.ini"
    echo
    logger_info "Useful commands:"
    echo "     systemctl status ${SERVICE_NAME}     # Check service status"
    echo "     systemctl start ${SERVICE_NAME}      # Start service"
    echo "     systemctl stop ${SERVICE_NAME}       # Stop service"
    echo "     journalctl -u ${SERVICE_NAME} -f     # View logs"
    echo
    logger_warn "⚠️  Remember to edit $INSTALL_CONFIG/config.ini with your MQTT broker settings if they are not set to the default"
}

main "$@"
