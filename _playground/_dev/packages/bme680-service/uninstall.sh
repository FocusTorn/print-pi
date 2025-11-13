#!/bin/bash
# BME680 Service Uninstallation Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR"
IMENU_DIR="$PACKAGE_DIR/../_utilities/iMenu"

# Capture original user's home (before sudo)
ORIGINAL_USER="${SUDO_USER:-$USER}"
ORIGINAL_HOME=$(getent passwd "$ORIGINAL_USER" 2>/dev/null | cut -d: -f6)
if [ -z "$ORIGINAL_HOME" ]; then
    ORIGINAL_HOME="/home/$ORIGINAL_USER"
fi

INSTALL_ROOT="$ORIGINAL_HOME/.local/share/bme680-service"
INSTALL_BIN="$ORIGINAL_HOME/.local/bin"
CONFIG_DIR="$ORIGINAL_HOME/.config/bme680-monitor"
HA_PKG_DIR="$ORIGINAL_HOME/homeassistant/packages"
HA_CUSTOM_COMPONENTS="$ORIGINAL_HOME/homeassistant/custom_components/bme680_monitor"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

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
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Auto-elevate to root if needed
if [ "$EUID" -ne 0 ]; then
    print_info "This script requires sudo privileges"
    print_info "Attempting to elevate privileges..."
    exec sudo "$0" "$@"
fi

uninstall_service() {
    local service_name=$1
    
    if ! systemctl list-units --all --type=service | grep -q "$service_name.service"; then
        print_info "Service $service_name not installed, skipping"
        return 0
    fi
    
    print_info "Stopping $service_name service..."
    systemctl stop "$service_name.service" 2>/dev/null || true
    
    print_info "Disabling $service_name service..."
    systemctl disable "$service_name.service" 2>/dev/null || true
    
    print_info "Removing service file..."
    rm -f "/etc/systemd/system/$service_name.service"
    
    print_success "Uninstalled $service_name"
}

print_info "BME680 Service Uninstallation"
echo

# Source iMenu (includes iWizard)
if [ -f "$IMENU_DIR/iMenu.sh" ]; then
    source "$IMENU_DIR/iMenu.sh"
else
    print_warning "iMenu not found at $IMENU_DIR/iMenu.sh"
    print_warning "Falling back to simple prompts..."
fi

# Build menu options based on installed services
menu_options=()

if systemctl list-units --all --type=service | grep -q "bme680-base-mqtt.service"; then
    menu_options+=("Base readings service (MQTT) - Includes sensor readings and heatsoak calculations")
fi

if systemctl list-units --all --type=service | grep -q "bme680-iaq-mqtt.service"; then
    menu_options+=("IAQ monitor service (MQTT)")
fi

# Legacy service names (for backward compatibility)
if systemctl list-units --all --type=service | grep -q "bme680-heatsoak-mqtt.service"; then
    menu_options+=("Heat soak detection service (MQTT) - DEPRECATED (now part of base service)")
fi

if systemctl list-units --all --type=service | grep -q "bme680-base.service"; then
    menu_options+=("Base readings service (legacy) - bme680-base")
fi

if systemctl list-units --all --type=service | grep -q "bme680-readings.service"; then
    menu_options+=("Sensor readings service (legacy) - bme680-readings")
fi

if systemctl list-units --all --type=service | grep -q "bme680-heat-soak.service"; then
    menu_options+=("Heat soak detection service (legacy) - bme680-heat-soak")
fi

# Collect all prompts first, then process
services_to_uninstall=()
remove_config=false
remove_ha_integration=false
proceed_with_uninstall=false

if [ ${#menu_options[@]} -eq 0 ]; then
    print_info "No BME680 services found installed"
    exit 0
fi

# Step 1: Prompt for services to uninstall
print_info "Select services to uninstall:"
echo

if type iprompt_run >/dev/null 2>&1 && [ -t 0 ] && [ -t 1 ]; then
    step1=(
        "multiselect"
        "ℹ️  Which services would you like to uninstall?"
        "${menu_options[@]}"
    )
    
    wizard_result=$(iprompt_run "uninstall_services" "${step1[@]}")
    wizard_exit=$?
    
    if [ $wizard_exit -ne 0 ] || [ -z "$wizard_result" ]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
    
    # Store service names to uninstall
    for idx in $wizard_result; do
        case "${menu_options[$idx]}" in
            *"bme680-base-mqtt"*|*"Base readings service (MQTT)"*)
                services_to_uninstall+=("bme680-base-mqtt")
                ;;
            *"bme680-iaq-mqtt"*|*"IAQ monitor service (MQTT)"*)
                services_to_uninstall+=("bme680-iaq-mqtt")
                ;;
            *"bme680-heatsoak-mqtt"*|*"Heat soak detection service (MQTT)"*)
                services_to_uninstall+=("bme680-heatsoak-mqtt")
                ;;
            *"bme680-base"*|*"Base readings service (legacy)"*)
                services_to_uninstall+=("bme680-base")
                ;;
            *"bme680-readings"*|*"Sensor readings service (legacy)"*)
                services_to_uninstall+=("bme680-readings")
                ;;
            *"bme680-heat-soak"*|*"Heat soak detection service (legacy)"*)
                services_to_uninstall+=("bme680-heat-soak")
                ;;
        esac
    done
elif type interactive_menu >/dev/null 2>&1 && [ -t 0 ] && [ -t 1 ]; then
    # Fallback to old interactive_menu if available
    selected=$(interactive_menu "${menu_options[@]}")
    menu_exit=$?
    
    if [ $menu_exit -ne 0 ] || [ -z "$selected" ]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
    
    # Store service names to uninstall
    for idx in $selected; do
        case "${menu_options[$idx]}" in
            *"bme680-base-mqtt"*|*"Base readings service (MQTT)"*)
                services_to_uninstall+=("bme680-base-mqtt")
                ;;
            *"bme680-iaq-mqtt"*|*"IAQ monitor service (MQTT)"*)
                services_to_uninstall+=("bme680-iaq-mqtt")
                ;;
            *"bme680-heatsoak-mqtt"*|*"Heat soak detection service (MQTT)"*)
                services_to_uninstall+=("bme680-heatsoak-mqtt")
                ;;
            *"bme680-base"*|*"Base readings service (legacy)"*)
                services_to_uninstall+=("bme680-base")
                ;;
            *"bme680-readings"*|*"Sensor readings service (legacy)"*)
                services_to_uninstall+=("bme680-readings")
                ;;
            *"bme680-heat-soak"*|*"Heat soak detection service (legacy)"*)
                services_to_uninstall+=("bme680-heat-soak")
                ;;
        esac
    done
else
    # Fallback to simple prompts
    print_warning "Interactive menu not available, using simple prompts..."
    
    if systemctl list-units --all --type=service | grep -q "bme680-base-mqtt.service"; then
        read -p "Uninstall base readings service (MQTT)? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            services_to_uninstall+=("bme680-base-mqtt")
        fi
    fi
    
    if systemctl list-units --all --type=service | grep -q "bme680-iaq-mqtt.service"; then
        read -p "Uninstall IAQ monitor service (MQTT)? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            services_to_uninstall+=("bme680-iaq-mqtt")
        fi
    fi
    
    # Legacy service names (for backward compatibility)
    if systemctl list-units --all --type=service | grep -q "bme680-heatsoak-mqtt.service"; then
        read -p "Uninstall heat soak detection service (MQTT)? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            services_to_uninstall+=("bme680-heatsoak-mqtt")
        fi
    fi
    
    if systemctl list-units --all --type=service | grep -q "bme680-base.service"; then
        read -p "Uninstall base readings service (legacy)? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            services_to_uninstall+=("bme680-base")
        fi
    fi
    
    if systemctl list-units --all --type=service | grep -q "bme680-readings.service"; then
        read -p "Uninstall sensor readings service (legacy)? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            services_to_uninstall+=("bme680-readings")
        fi
    fi
    
    if systemctl list-units --all --type=service | grep -q "bme680-heat-soak.service"; then
        read -p "Uninstall heat soak detection service (legacy)? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            services_to_uninstall+=("bme680-heat-soak")
        fi
    fi
fi

# If no services selected, exit
if [ ${#services_to_uninstall[@]} -eq 0 ]; then
    print_info "No services selected. Uninstallation cancelled."
    exit 0
fi

# Step 2: Prompt for HA integration removal
if [ -f "$HA_PKG_DIR/bme680_mqtt.yaml" ] || [ -f "$HA_PKG_DIR/bme680_heatsoak_mqtt.yaml" ] || [ -f "$HA_PKG_DIR/bme680_heatsoak_mqtt.yaml.disabled" ] || [ -d "$HA_CUSTOM_COMPONENTS" ]; then
    echo
    if type iprompt_run >/dev/null 2>&1 && [ -t 0 ] && [ -t 1 ]; then
        ha_step=(
            "confirm"
            "ℹ️  Remove Home Assistant integration files (MQTT packages and custom component)?"
            "--default" "false"
        )
        
        ha_result=$(iprompt_run "remove_ha_integration" "${ha_step[@]}")
        ha_exit=$?
        
        if [ $ha_exit -eq 0 ] && [ "$ha_result" = "true" ]; then
            remove_ha_integration=true
        fi
    else
        read -p "Remove Home Assistant integration files? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            remove_ha_integration=true
        fi
    fi
fi

# Step 3: Prompt for config removal
if [ -d "$CONFIG_DIR" ]; then
    echo
    if type iprompt_run >/dev/null 2>&1 && [ -t 0 ] && [ -t 1 ]; then
        config_step=(
            "confirm"
            "ℹ️  Remove configuration files ($CONFIG_DIR)?"
            "--default" "false"
        )
        
        config_result=$(iprompt_run "remove_config" "${config_step[@]}")
        config_exit=$?
        
        if [ $config_exit -eq 0 ] && [ "$config_result" = "true" ]; then
            remove_config=true
        fi
    else
        read -p "Remove configuration files from $CONFIG_DIR? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            remove_config=true
        fi
    fi
fi

# Step 4: Show summary and confirm to proceed
echo
print_info "The following will be uninstalled:"
echo
for service in "${services_to_uninstall[@]}"; do
    echo "  • $service service"
done

# Package files and CLI are always removed if services are being uninstalled
if [ -d "$INSTALL_ROOT" ]; then
    echo "  • Package files ($INSTALL_ROOT)"
fi

if [ -f "$INSTALL_BIN/bme680-cli" ]; then
    echo "  • CLI tool ($INSTALL_BIN/bme680-cli)"
fi

if [ "$remove_ha_integration" = true ]; then
    echo "  • Home Assistant integration files:"
    if [ -f "$HA_PKG_DIR/bme680_mqtt.yaml" ]; then
        echo "    - MQTT package: $HA_PKG_DIR/bme680_mqtt.yaml"
    fi
    if [ -f "$HA_PKG_DIR/bme680_heatsoak_mqtt.yaml" ]; then
        echo "    - MQTT package: $HA_PKG_DIR/bme680_heatsoak_mqtt.yaml"
    fi
    if [ -f "$HA_PKG_DIR/bme680_heatsoak_mqtt.yaml.disabled" ]; then
        echo "    - MQTT package: $HA_PKG_DIR/bme680_heatsoak_mqtt.yaml.disabled"
    fi
    if [ -d "$HA_CUSTOM_COMPONENTS" ]; then
        echo "    - Custom component: $HA_CUSTOM_COMPONENTS"
    fi
fi

if [ "$remove_config" = true ]; then
    echo "  • Configuration files ($CONFIG_DIR)"
fi

echo

# Step 5: Ask for final confirmation to proceed
if type iprompt_run >/dev/null 2>&1 && [ -t 0 ] && [ -t 1 ]; then
    confirm_step=(
        "confirm"
        "ℹ️  Proceed with uninstallation?"
        "--default" "false"
    )
    
    confirm_result=$(iprompt_run "confirm_uninstall" "${confirm_step[@]}")
    confirm_exit=$?
    
    if [ $confirm_exit -ne 0 ] || [ "$confirm_result" != "true" ]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
    proceed_with_uninstall=true
else
    read -p "Proceed with uninstallation? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        proceed_with_uninstall=true
    else
        print_info "Uninstallation cancelled"
        exit 0
    fi
fi

# Now process all the options
if [ "$proceed_with_uninstall" = true ]; then
    echo
    print_info "Uninstalling services..."
    for service in "${services_to_uninstall[@]}"; do
        uninstall_service "$service"
    done
    
    print_info "Reloading systemd daemon..."
    systemctl daemon-reload
    
    # Remove package files and CLI automatically (no point keeping them without services)
    if [ -d "$INSTALL_ROOT" ]; then
        print_info "Removing package files..."
        rm -rf "$INSTALL_ROOT"
        print_success "Package files removed"
    fi
    
    if [ -f "$INSTALL_BIN/bme680-cli" ]; then
        print_info "Removing CLI tool..."
        rm -f "$INSTALL_BIN/bme680-cli"
        print_success "CLI tool removed"
    fi
    
    # Remove HA integration files if requested
    if [ "$remove_ha_integration" = true ]; then
        print_info "Removing Home Assistant integration files..."
        
        # Remove MQTT package files
        if [ -f "$HA_PKG_DIR/bme680_mqtt.yaml" ]; then
            rm -f "$HA_PKG_DIR/bme680_mqtt.yaml"
            print_success "Removed MQTT package: bme680_mqtt.yaml"
        fi
        
        if [ -f "$HA_PKG_DIR/bme680_heatsoak_mqtt.yaml" ]; then
            rm -f "$HA_PKG_DIR/bme680_heatsoak_mqtt.yaml"
            print_success "Removed MQTT package: bme680_heatsoak_mqtt.yaml"
        fi
        
        if [ -f "$HA_PKG_DIR/bme680_heatsoak_mqtt.yaml.disabled" ]; then
            rm -f "$HA_PKG_DIR/bme680_heatsoak_mqtt.yaml.disabled"
            print_success "Removed MQTT package: bme680_heatsoak_mqtt.yaml.disabled"
        fi
        
        # Remove custom component
        if [ -d "$HA_CUSTOM_COMPONENTS" ]; then
            rm -rf "$HA_CUSTOM_COMPONENTS"
            print_success "Removed custom component: bme680_monitor"
        fi
        
        echo
        print_info "⚠️  IMPORTANT: Reload Home Assistant Core to apply changes"
        print_info "   Run: ha reload core"
        print_info "   Or use: Developer Tools > YAML > Reload Core Configuration"
        echo
    fi
    
    # Remove config files if requested
    if [ "$remove_config" = true ]; then
        print_info "Removing configuration files..."
        rm -rf "$CONFIG_DIR"
        print_success "Configuration files removed"
    fi
    
    print_success "Uninstallation complete!"
fi
