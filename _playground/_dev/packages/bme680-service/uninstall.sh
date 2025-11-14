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

# Clean up any remaining bme680 service files (including backups and deprecated services)
cleanup_all_service_files() {
    print_info "Cleaning up any remaining bme680 service files..."
    
    # Find all bme680 service files
    local service_files
    service_files=$(find /etc/systemd/system -name "*bme680*" -type f 2>/dev/null)
    
    if [ -n "$service_files" ]; then
        while IFS= read -r service_file; do
            if [ -f "$service_file" ]; then
                local service_name
                service_name=$(basename "$service_file")
                # Remove .backup extension if present to get actual service name
                local actual_service="${service_name%.backup}"
                actual_service="${actual_service%.service}"
                
                print_info "  Removing $service_name..."
                systemctl stop "$actual_service.service" 2>/dev/null || true
                systemctl disable "$actual_service.service" 2>/dev/null || true
                rm -f "$service_file"
                print_success "  Removed $service_name"
            fi
        done <<< "$service_files"
    else
        print_info "  No additional service files found"
    fi
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

# Build wizard configuration with all steps dynamically
# Start with base config
UNINSTALL_WIZARD_CONFIG='{"title": "BME680 Service Uninstallation", "steps": []}'

# Step 1: Services to uninstall (always present)
if [ ${#menu_options[@]} -gt 0 ]; then
    # Convert menu_options array to JSON array format
    options_json="["
    first=true
    for option in "${menu_options[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            options_json="$options_json,"
        fi
        # Escape quotes in option text
        escaped_option=$(echo "$option" | sed 's/"/\\"/g')
        options_json="$options_json\"$escaped_option\""
    done
    options_json="$options_json]"
    
    # Add services step
    step1=$(cat <<EOF
{
    "type": "multiselect",
    "message": "ℹ️  Which services would you like to uninstall?",
    "options": $options_json
}
EOF
)
    UNINSTALL_WIZARD_CONFIG=$(echo "$UNINSTALL_WIZARD_CONFIG" | jq --argjson step "$step1" '.steps += [$step]' 2>/dev/null || echo "$UNINSTALL_WIZARD_CONFIG")
fi

# Step 2: HA integration removal (conditional)
if [ -f "$HA_PKG_DIR/bme680_mqtt.yaml" ] || [ -f "$HA_PKG_DIR/bme680_heatsoak_mqtt.yaml" ] || [ -f "$HA_PKG_DIR/bme680_heatsoak_mqtt.yaml.disabled" ] || [ -d "$HA_CUSTOM_COMPONENTS" ]; then
    step2='{"type": "confirm", "message": "ℹ️  Remove Home Assistant integration files (MQTT packages and custom component)?", "initial": false}'
    UNINSTALL_WIZARD_CONFIG=$(echo "$UNINSTALL_WIZARD_CONFIG" | jq --argjson step "$step2" '.steps += [$step]' 2>/dev/null || echo "$UNINSTALL_WIZARD_CONFIG")
fi

# Step 3: Config removal (conditional)
if [ -d "$CONFIG_DIR" ]; then
    # Escape config dir path for JSON
    config_dir_escaped=$(echo "$CONFIG_DIR" | sed 's/"/\\"/g')
    step3="{\"type\": \"confirm\", \"message\": \"ℹ️  Remove configuration files ($config_dir_escaped)?\", \"initial\": false}"
    UNINSTALL_WIZARD_CONFIG=$(echo "$UNINSTALL_WIZARD_CONFIG" | jq --argjson step "$step3" '.steps += [$step]' 2>/dev/null || echo "$UNINSTALL_WIZARD_CONFIG")
fi

# Step 4: Final confirmation (always present)
step4='{"type": "confirm", "message": "ℹ️  Proceed with uninstallation?", "initial": false}'
UNINSTALL_WIZARD_CONFIG=$(echo "$UNINSTALL_WIZARD_CONFIG" | jq --argjson step "$step4" '.steps += [$step]' 2>/dev/null || echo "$UNINSTALL_WIZARD_CONFIG")

# Run single wizard with all steps
if type iwizard_run_inline >/dev/null 2>&1 && [ -t 0 ] && [ -t 1 ]; then
    wizard_results=$(iwizard_run_inline "$UNINSTALL_WIZARD_CONFIG")
    wizard_exit=$?
    
    if [ $wizard_exit -ne 0 ]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
    
    # Parse results - step indices depend on which conditional steps were included
    step_idx=0
    
    # Step 1: Services (always step0)
    wizard_result=$(echo "$wizard_results" | jq -r ".step${step_idx}.result" 2>/dev/null || echo "")
    step_idx=$((step_idx + 1))
    
    if [ -z "$wizard_result" ] || [ "$wizard_result" = "null" ]; then
        print_info "No services selected. Uninstallation cancelled."
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
    
    # Step 2: HA integration (conditional)
    if [ -f "$HA_PKG_DIR/bme680_mqtt.yaml" ] || [ -f "$HA_PKG_DIR/bme680_heatsoak_mqtt.yaml" ] || [ -f "$HA_PKG_DIR/bme680_heatsoak_mqtt.yaml.disabled" ] || [ -d "$HA_CUSTOM_COMPONENTS" ]; then
        ha_result=$(echo "$wizard_results" | jq -r ".step${step_idx}.result" 2>/dev/null || echo "false")
        step_idx=$((step_idx + 1))
        if [ "$ha_result" = "true" ]; then
            remove_ha_integration=true
        fi
    fi
    
    # Step 3: Config removal (conditional)
    if [ -d "$CONFIG_DIR" ]; then
        config_result=$(echo "$wizard_results" | jq -r ".step${step_idx}.result" 2>/dev/null || echo "false")
        step_idx=$((step_idx + 1))
        if [ "$config_result" = "true" ]; then
            remove_config=true
        fi
    fi
    
    # Step 4: Final confirmation (always last)
    confirm_result=$(echo "$wizard_results" | jq -r ".step${step_idx}.result" 2>/dev/null || echo "false")
    if [ "$confirm_result" = "true" ]; then
        proceed_with_uninstall=true
    else
        print_info "Uninstallation cancelled"
        exit 0
    fi
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

# If no services selected, exit (shouldn't happen with wizard, but check anyway)
if [ ${#services_to_uninstall[@]} -eq 0 ]; then
    print_info "No services selected. Uninstallation cancelled."
    exit 0
fi

# Show summary of what will be uninstalled
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

# Now process all the options
if [ "$proceed_with_uninstall" = true ]; then
    echo
    print_info "Uninstalling services..."
    for service in "${services_to_uninstall[@]}"; do
        uninstall_service "$service"
    done
    
    print_info "Reloading systemd daemon..."
    systemctl daemon-reload
    
    # Clean up any remaining service files (backups, deprecated services, etc.)
    cleanup_all_service_files
    
    # Kill any remaining bme680 processes
    print_info "Stopping any remaining bme680 processes..."
    pkill -f "bme680.*wrapper" 2>/dev/null || true
    pkill -f "base-readings.py" 2>/dev/null || true
    pkill -f "monitor-heatsoak.py" 2>/dev/null || true
    pkill -f "monitor-iaq.py" 2>/dev/null || true
    sleep 1  # Give processes time to stop
    
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
        
        # Remove custom component (check both possible locations)
        if [ -d "$HA_CUSTOM_COMPONENTS" ]; then
            rm -rf "$HA_CUSTOM_COMPONENTS"
            print_success "Removed custom component: bme680_monitor"
        fi
        # Also check for old location (bme680-monitor instead of bme680_monitor)
        if [ -d "$ORIGINAL_HOME/homeassistant/bme680-monitor" ]; then
            rm -rf "$ORIGINAL_HOME/homeassistant/bme680-monitor"
            print_success "Removed custom component (old location): bme680-monitor"
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
