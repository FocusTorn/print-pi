#!/bin/bash
# BME680 Service Uninstallation Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR"
IMENU_DIR="$PACKAGE_DIR/../_utilities/iMenu"

# Parse command line arguments
VERBOSE=false
for arg in "$@"; do
    case "$arg" in
        --verbose|-v)
            VERBOSE=true
            ;;
        --help|-h)
            echo "Usage: $0 [--verbose|-v] [--help|-h]"
            echo ""
            echo "Options:"
            echo "  --verbose, -v    Show detailed information messages"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
    esac
done

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

print_success() { #>
    echo -e "${GREEN}✅ $1${NC}"
} #<
print_error() { #>
    echo -e "${RED}❌ $1${NC}"
} #<
print_warning() { #>
    echo -e "${YELLOW}⚠️  $1${NC}"
} #<
print_info() { #>
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}ℹ️  $1${NC}"
    fi
} #<

remove_bme680_entities() { #>
    print_info "Removing BME680 entities from Home Assistant entity registry and state file..."
    
    local removed_count=0
    local state_removed_count=0
    local registry_file="/config/.storage/core.entity_registry"
    local state_file="/config/.storage/core.restore_state"
    
    # Try to remove entities by directly modifying the entity registry file
    if docker ps --format '{{.Names}}' | grep -q "^homeassistant$"; then
        # Check if registry file exists
        if docker exec homeassistant test -f "$registry_file" 2>/dev/null; then
            # Use Python to remove ALL entities that have 'bme680' in unique_id or entity_id
            removed_count=$(docker exec homeassistant python3 -c "
import json
import sys

registry_file = '$registry_file'

try:
    # Read registry
    with open(registry_file, 'r') as f:
        registry = json.load(f)
    
    # Find ALL entities to remove - match detection logic
    original_count = len(registry.get('data', {}).get('entities', []))
    entities_to_remove = []
    
    for entity in registry.get('data', {}).get('entities', []):
        entity_id = entity.get('entity_id', '')
        unique_id = entity.get('unique_id', '')
        
        # Remove any entity with 'bme680' in unique_id or entity_id (matches detection logic)
        if 'bme680' in unique_id.lower() or 'bme680' in entity_id.lower():
            entities_to_remove.append(entity_id)
    
    # Remove entities
    registry['data']['entities'] = [
        entity for entity in registry['data']['entities']
        if entity.get('entity_id') not in entities_to_remove
    ]
    removed_count = original_count - len(registry['data']['entities'])
    
    # Write back
    with open(registry_file, 'w') as f:
        json.dump(registry, f, indent=2)
    
    print(removed_count)
except Exception as e:
    print(0, file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || echo "0")
        fi
        
        # Also remove from state file (where live states are stored)
        if docker exec homeassistant test -f "$state_file" 2>/dev/null; then
            state_removed_count=$(docker exec homeassistant python3 -c "
import json
import sys

state_file = '$state_file'

try:
    # Read state file
    with open(state_file, 'r') as f:
        state_data = json.load(f)
    
    # Get states list
    states = []
    if isinstance(state_data, dict) and 'data' in state_data:
        data_content = state_data['data']
        if isinstance(data_content, list):
            states = data_content
    
    original_count = len(states)
    states_to_keep = []
    
    # Remove states for BME680 entities
    for state_obj in states:
        if not isinstance(state_obj, dict):
            states_to_keep.append(state_obj)
            continue
        
        entity_id = None
        if 'state' in state_obj and isinstance(state_obj['state'], dict):
            entity_id = state_obj['state'].get('entity_id', '')
        elif 'entity_id' in state_obj:
            entity_id = state_obj.get('entity_id', '')
        
        # Keep state if it's not a BME680 entity
        if not entity_id or 'bme680' not in entity_id.lower():
            states_to_keep.append(state_obj)
    
    state_data['data'] = states_to_keep
    removed_count = original_count - len(states_to_keep)
    
    # Write back
    with open(state_file, 'w') as f:
        json.dump(state_data, f, indent=2)
    
    print(removed_count)
except Exception as e:
    print(0, file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || echo "0")
        fi
    fi
    
    if [ -n "$removed_count" ] && [ "$removed_count" -gt 0 ]; then
        print_success "Removed $removed_count BME680 entities from registry"
    else
        if [ "$removed_count" = "0" ] && [ -n "$removed_count" ]; then
            # Check if there actually were entities to remove (might indicate a script error)
            actual_count=$(docker exec homeassistant python3 -c "
import json
try:
    with open('$registry_file', 'r') as f:
        registry = json.load(f)
        bme680 = [e for e in registry.get('data', {}).get('entities', []) 
                  if 'bme680' in e.get('unique_id', '').lower() or 'bme680' in e.get('entity_id', '').lower()]
        print(len(bme680))
except:
    print(0)
" 2>/dev/null || echo "0")
            if [ "$actual_count" -gt 0 ]; then
                print_warning "Removal reported 0, but $actual_count entities still exist - there may have been an error"
            else
                print_success "No BME680 entities found in registry (or already removed)"
            fi
        else
            print_success "No BME680 entities found in registry (or already removed)"
        fi
    fi
    
    if [ -n "$state_removed_count" ] && [ "$state_removed_count" -gt 0 ]; then
        print_success "Removed $state_removed_count BME680 entity states from state file"
    fi
} #<

remove_bme680_device() { #>
    print_info "Removing BME680 device from Home Assistant device registry..."
    
    local removed_count=0
    local device_registry_file="/config/.storage/core.device_registry"
    
    # Try to remove device by directly modifying the device registry file
    if docker ps --format '{{.Names}}' | grep -q "^homeassistant$"; then
        # Check if registry file exists
        if docker exec homeassistant test -f "$device_registry_file" 2>/dev/null; then
            # Use Python to remove ALL devices that have 'bme680' in name or identifiers
            removed_count=$(docker exec homeassistant python3 -c "
import json
import sys

device_registry_file = '$device_registry_file'

try:
    # Read device registry
    with open(device_registry_file, 'r') as f:
        device_registry = json.load(f)
    
    # Find ALL devices to remove
    original_count = len(device_registry.get('data', {}).get('devices', []))
    devices_to_remove = []
    
    for device in device_registry.get('data', {}).get('devices', []):
        device_name = device.get('name', '')
        device_id = device.get('id', '')
        identifiers = str(device.get('identifiers', []))
        
        # Remove any device with 'bme680' in name or identifiers
        if 'bme680' in device_name.lower() or 'bme680' in identifiers.lower():
            devices_to_remove.append(device_id)
    
    # Remove devices
    device_registry['data']['devices'] = [
        device for device in device_registry['data']['devices']
        if device.get('id') not in devices_to_remove
    ]
    removed_count = original_count - len(device_registry['data']['devices'])
    
    # Write back
    with open(device_registry_file, 'w') as f:
        json.dump(device_registry, f, indent=2)
    
    print(removed_count)
except Exception as e:
    print(0, file=sys.stderr)
    sys.exit(1)
" 2>/dev/null || echo "0")
        fi
    fi
    
    if [ -n "$removed_count" ] && [ "$removed_count" -gt 0 ]; then
        print_success "Removed $removed_count BME680 device(s) from device registry"
    else
        print_success "No BME680 devices found in device registry (or already removed)"
    fi
} #<

reload_ha_core() { #>
    print_info "Reloading Home Assistant core configuration..."
    
    # Try using ha helper script first (if available)
    if command -v ha >/dev/null 2>&1; then
        # Try reload_core_config first (faster than full restart)
        if ha service call config.reload_core_config >/dev/null 2>&1; then
            print_success "Home Assistant core configuration reloaded (via ha helper)"
            return 0
        fi
        # Fallback to restart if reload doesn't work
        if ha restart >/dev/null 2>&1; then
            print_success "Home Assistant restarted (via ha helper)"
            return 0
        fi
    fi
    
    # Try docker exec with supervisor API (if supervised installation)
    if docker ps --format '{{.Names}}' | grep -q "^homeassistant$"; then
        # Try supervisor API first (for supervised installations)
        if docker exec homeassistant curl -s -X POST http://supervisor/core/reload 2>/dev/null | grep -q "ok"; then
            print_success "Home Assistant core configuration reloaded (via supervisor API)"
            return 0
        fi
        
        # Fallback: Try HA API with localhost (may require token, but worth trying)
        # Note: This will fail if token is required, but we'll catch it
        if docker exec homeassistant curl -s -X POST -H "Content-Type: application/json" http://localhost:8123/api/services/config/reload_core_config 2>/dev/null | grep -q -E "(reload|ok|success)"; then
            print_success "Home Assistant core configuration reloaded (via HA API)"
            return 0
        fi
    fi
    
    # If all methods fail, inform user
    print_warning "Could not automatically reload Home Assistant core configuration"
    print_info "  Please reload manually:"
    print_info "    - Run: ha restart"
    print_info "    - Or use: Developer Tools > YAML > Reload Core Configuration"
    return 1
} #<

remove_mqtt_discovery_messages() { #>
    print_info "Checking for MQTT discovery messages that might recreate entities..."
    
    # This function attempts to remove retained MQTT discovery messages
    # Note: This requires MQTT broker access, which may not be available
    # This is a best-effort attempt to prevent entity recreation
    
    # Check if mosquitto_pub is available (for removing retained messages)
    if ! command -v mosquitto_pub >/dev/null 2>&1 && ! command -v mosquitto >/dev/null 2>&1; then
        print_info "  MQTT tools not available, skipping discovery message cleanup"
        print_info "  If entities are recreated, manually remove retained messages from MQTT broker"
        return 0
    fi
    
    # Common MQTT discovery topic patterns for BME680
    # These would need to be removed from the broker to prevent auto-discovery
    print_info "  Note: MQTT discovery messages may need manual removal from broker"
    print_info "  Look for retained messages on topics like:"
    print_info "    - homeassistant/sensor/bme680*/config"
    print_info "    - homeassistant/binary_sensor/bme680*/config"
    print_info "  Use MQTT broker tools or HA MQTT integration to remove them"
    
    return 0
} #<

if [ "$EUID" -ne 0 ]; then #> Auto-elevate to root if needed
    if [ "$VERBOSE" = true ]; then
        print_info "This script requires sudo privileges"
        print_info "Attempting to elevate privileges..."
    fi
    exec sudo "$0" "$@"
fi #<

uninstall_service() { #>
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
} #<

cleanup_all_service_files() { #>
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
} #<

print_info "BME680 Service Uninstallation"
echo

# Source iMenu (includes iWizard)
if [ -f "$IMENU_DIR/iMenu.sh" ]; then
    source "$IMENU_DIR/iMenu.sh"
else
    print_warning "iMenu not found at $IMENU_DIR/iMenu.sh"
    print_warning "Falling back to simple prompts..."
fi

# Build dynamic menu options based on what exists
menu_options=()
option_types=()  # Track what type each option is: "service", "ha_entities", "ha_package", "config"

# Check for services
if systemctl list-units --all --type=service | grep -q "bme680-base-mqtt.service"; then
    menu_options+=("Base readings service (MQTT) - Includes sensor readings and heatsoak calculations")
    option_types+=("service:bme680-base-mqtt")
fi

if systemctl list-units --all --type=service | grep -q "bme680-iaq-mqtt.service"; then
    menu_options+=("IAQ monitor service (MQTT)")
    option_types+=("service:bme680-iaq-mqtt")
fi

# Legacy service names (for backward compatibility)
if systemctl list-units --all --type=service | grep -q "bme680-heatsoak-mqtt.service"; then
    menu_options+=("Heat soak detection service (MQTT) - DEPRECATED (now part of base service)")
    option_types+=("service:bme680-heatsoak-mqtt")
fi

if systemctl list-units --all --type=service | grep -q "bme680-base.service"; then
    menu_options+=("Base readings service (legacy) - bme680-base")
    option_types+=("service:bme680-base")
fi

if systemctl list-units --all --type=service | grep -q "bme680-readings.service"; then
    menu_options+=("Sensor readings service (legacy) - bme680-readings")
    option_types+=("service:bme680-readings")
fi

if systemctl list-units --all --type=service | grep -q "bme680-heat-soak.service"; then
    menu_options+=("Heat soak detection service (legacy) - bme680-heat-soak")
    option_types+=("service:bme680-heat-soak")
fi

# Check for HA entities (always show option if HA is available, even if count is 0)
if docker ps --format '{{.Names}}' | grep -q "^homeassistant$"; then
    # Check for all BME680 entities
    entity_count=$(docker exec homeassistant python3 -c "
import json
try:
    with open('/config/.storage/core.entity_registry', 'r') as f:
        registry = json.load(f)
        bme_entities = [e for e in registry.get('data', {}).get('entities', []) if 'bme680' in e.get('unique_id', '').lower() or 'bme680' in e.get('entity_id', '').lower()]
        print(len(bme_entities))
except:
    print(0)
" 2>/dev/null || echo "0")
    
    # Check specifically for MQTT platform entities
    mqtt_entity_count=$(docker exec homeassistant python3 -c "
import json
try:
    with open('/config/.storage/core.entity_registry', 'r') as f:
        registry = json.load(f)
        bme_entities = [e for e in registry.get('data', {}).get('entities', []) if ('bme680' in e.get('unique_id', '').lower() or 'bme680' in e.get('entity_id', '').lower()) and e.get('platform') == 'mqtt']
        print(len(bme_entities))
except:
    print(0)
" 2>/dev/null || echo "0")
    
    # Always show the option if HA is available (for cleanup even if count is 0)
    if [ -n "$entity_count" ]; then
        if [ "$entity_count" -gt 0 ]; then
            if [ "$mqtt_entity_count" -gt 0 ] && [ "$mqtt_entity_count" -eq "$entity_count" ]; then
                # All entities are MQTT, show MQTT-specific label
                menu_options+=("Home Assistant MQTT entities ($mqtt_entity_count BME680 MQTT entities in entity registry)")
            elif [ "$mqtt_entity_count" -gt 0 ]; then
                # Some are MQTT, show both counts
                menu_options+=("Home Assistant entities ($entity_count total, $mqtt_entity_count MQTT BME680 entities in entity registry)")
            else
                # None are MQTT
                menu_options+=("Home Assistant entities ($entity_count BME680 entities in entity registry)")
            fi
        else
            menu_options+=("Home Assistant entities (0 BME680 entities in entity registry)")
        fi
        option_types+=("ha_entities")
    fi
fi

# Check for HA package file
if [ -f "$HA_PKG_DIR/bme680_mqtt.yaml" ] || [ -f "$HA_PKG_DIR/bme680_heatsoak_mqtt.yaml" ] || [ -f "$HA_PKG_DIR/bme680_heatsoak_mqtt.yaml.disabled" ] || [ -d "$HA_CUSTOM_COMPONENTS" ]; then
    menu_options+=("Home Assistant integration files (MQTT packages and custom component)")
    option_types+=("ha_package")
fi

# Check for config file
if [ -d "$CONFIG_DIR" ] && [ -f "$CONFIG_DIR/config.yaml" ]; then
    menu_options+=("Configuration files ($CONFIG_DIR)")
    option_types+=("config")
fi

# Collect all prompts first, then process
services_to_uninstall=()
remove_config=false
remove_ha_integration=false
remove_ha_entities=false

# If nothing found, inform user and exit
if [ ${#menu_options[@]} -eq 0 ]; then
    print_info "No BME680 components found to uninstall"
    exit 0
fi

# Build wizard configuration with dynamic multiselect
# Start with base config
UNINSTALL_WIZARD_CONFIG='{"title": "BME680 Service Uninstallation", "steps": []}'

# Single multiselect step with all available options (all selected by default)
if [ ${#menu_options[@]} -gt 0 ]; then
    # Convert menu_options array to JSON array format (simple strings)
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
    
    # Build preselect array (all indices selected by default)
    preselect_json="["
    first=true
    for i in "${!menu_options[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            preselect_json="$preselect_json,"
        fi
        preselect_json="$preselect_json$i"
    done
    preselect_json="$preselect_json]"
    
    # Add single multiselect step with all options preselected
    step1=$(cat <<EOF
{
    "type": "multiselect",
    "message": "ℹ️  What would you like to uninstall? (All selected by default)",
    "options": $options_json,
    "preselect": $preselect_json
}
EOF
)
    UNINSTALL_WIZARD_CONFIG=$(echo "$UNINSTALL_WIZARD_CONFIG" | jq --argjson step "$step1" '.steps += [$step]' 2>/dev/null || echo "$UNINSTALL_WIZARD_CONFIG")
fi

# Run single wizard with all steps
if type iwizard_run_inline >/dev/null 2>&1 && [ -t 0 ] && [ -t 1 ]; then
    wizard_results=$(iwizard_run_inline "$UNINSTALL_WIZARD_CONFIG")
    wizard_exit=$?
    
    if [ $wizard_exit -ne 0 ]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
    
    # Parse results - single multiselect step
    # Result is an array of selected values (indices as strings)
    result_array=$(echo "$wizard_results" | jq -r ".step0.result[]?" 2>/dev/null || echo "")
    
    # Check if result is null or empty array
    result_check=$(echo "$wizard_results" | jq -r ".step0.result" 2>/dev/null || echo "null")
    if [ "$result_check" = "null" ] || [ "$result_check" = "[]" ] || [ -z "$result_array" ]; then
        # If nothing explicitly selected, use defaults (all selected)
        # This handles the case where user just presses enter with all defaults selected
        for i in "${!menu_options[@]}"; do
            option_type="${option_types[$i]}"
            case "$option_type" in
                service:*)
                    service_name="${option_type#service:}"
                    services_to_uninstall+=("$service_name")
                    ;;
                ha_entities)
                    remove_ha_entities=true
                    ;;
                ha_package)
                    remove_ha_integration=true
                    ;;
                config)
                    remove_config=true
                    ;;
            esac
        done
    else
        # Process explicitly selected options
        for idx in $result_array; do
            # Convert string index to integer
            idx_int=$((idx + 0))
            option_type="${option_types[$idx_int]}"
            case "$option_type" in
                service:*)
                    # Extract service name after the colon
                    service_name="${option_type#service:}"
                    services_to_uninstall+=("$service_name")
                    ;;
                ha_entities)
                    remove_ha_entities=true
                    ;;
                ha_package)
                    remove_ha_integration=true
                    ;;
                config)
                    remove_config=true
                    ;;
            esac
        done
    fi
elif type interactive_menu >/dev/null 2>&1 && [ -t 0 ] && [ -t 1 ]; then
    # Fallback to old interactive_menu if available
    selected=$(interactive_menu "${menu_options[@]}")
    menu_exit=$?
    
    if [ $menu_exit -ne 0 ] || [ -z "$selected" ]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
    
    # Process selected options based on their types
    for idx in $selected; do
        option_type="${option_types[$idx]}"
        case "$option_type" in
            service:*)
                # Extract service name after the colon
                service_name="${option_type#service:}"
                services_to_uninstall+=("$service_name")
                ;;
            ha_entities)
                remove_ha_entities=true
                ;;
            ha_package)
                remove_ha_integration=true
                ;;
            config)
                remove_config=true
                ;;
        esac
    done
else
    # Fallback to simple prompts
    print_warning "Interactive menu not available, using simple prompts..."
    
    echo
    print_info "Available components to uninstall:"
    for i in "${!menu_options[@]}"; do
        echo "  $((i+1))) ${menu_options[$i]}"
    done
    echo
    
    read -p "Enter numbers (space-separated) of items to uninstall, or 'all' for everything [default: all]: " selection
    
    # Default to "all" if empty
    if [ -z "$selection" ]; then
        selection="all"
    fi
    
    if [ "$selection" = "all" ]; then
        # Select all options
        for i in "${!menu_options[@]}"; do
            option_type="${option_types[$i]}"
            case "$option_type" in
                service:*)
                    service_name="${option_type#service:}"
                    services_to_uninstall+=("$service_name")
                    ;;
                ha_entities)
                    remove_ha_entities=true
                    ;;
                ha_package)
                    remove_ha_integration=true
                    ;;
                config)
                    remove_config=true
                    ;;
            esac
        done
    else
        # Process selected indices
        for idx in $selection; do
            # Convert to 0-based index
            actual_idx=$((idx - 1))
            if [ $actual_idx -ge 0 ] && [ $actual_idx -lt ${#menu_options[@]} ]; then
                option_type="${option_types[$actual_idx]}"
                case "$option_type" in
                    service:*)
                        service_name="${option_type#service:}"
                        services_to_uninstall+=("$service_name")
                        ;;
                    ha_entities)
                        remove_ha_entities=true
                        ;;
                    ha_package)
                        remove_ha_integration=true
                        ;;
                    config)
                        remove_config=true
                        ;;
                esac
            fi
        done
    fi
fi

# If nothing selected, exit
if [ ${#services_to_uninstall[@]} -eq 0 ] && [ "$remove_ha_integration" = false ] && [ "$remove_ha_entities" = false ] && [ "$remove_config" = false ]; then
    print_info "Nothing selected. Uninstallation cancelled."
    exit 0
fi

# Show summary of what will be uninstalled
echo
print_info "Uninstalling the following:"
echo

if [ ${#services_to_uninstall[@]} -gt 0 ]; then
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
fi

if [ "$remove_ha_entities" = true ]; then
    echo "  • Home Assistant entities (from entity registry)"
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
echo
if [ ${#services_to_uninstall[@]} -gt 0 ]; then
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
fi

# Remove HA integration files FIRST (before entities) to prevent recreation
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
fi

# Remove HA entities (can be done independently or after removing integration files)
# Note: If both package file and entities are removed, HA restart will ensure clean state
if [ "$remove_ha_entities" = true ]; then
    remove_bme680_entities
    # CRITICAL: Also remove the device from device registry
    # This prevents HA from recreating entities on restart
    remove_bme680_device
    # Also check for MQTT discovery messages that might recreate entities
    remove_mqtt_discovery_messages
    
    # CRITICAL: Restart HA immediately to clear entities from runtime memory
    # This is required - entities are in HA's memory until restart
    echo
    print_info "Restarting Home Assistant to clear entities from runtime memory..."
    if ha restart >/dev/null 2>&1; then
        print_success "Home Assistant restarted - entities should now be fully removed"
    else
        print_warning "Could not automatically restart Home Assistant"
        print_warning "⚠️  REQUIRED: Restart HA manually with: ha restart"
        print_warning "   Entities are still in HA's runtime memory until restart"
    fi
fi
# Remove config files if requested (independent of services)
if [ "$remove_config" = true ]; then
    print_info "Removing configuration files..."
    
    # Check if config.yaml is a symlink
    if [ -L "$CONFIG_DIR/config.yaml" ]; then
        symlink_target=$(readlink -f "$CONFIG_DIR/config.yaml" 2>/dev/null)
        print_info "  Config file is a symlink pointing to: $symlink_target"
        print_info "  Removing symlink only (target file will be preserved)"
        rm -f "$CONFIG_DIR/config.yaml"
        # Remove directory only if it's empty
        if [ -d "$CONFIG_DIR" ] && [ -z "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]; then
            rmdir "$CONFIG_DIR" 2>/dev/null || true
        fi
    else
        # Regular file or directory - remove normally
        rm -rf "$CONFIG_DIR"
    fi
    print_success "Configuration files removed"
fi

# Final recommendation: Restart HA to clear entities from runtime memory
if [ "$remove_ha_entities" = true ] || [ "$remove_ha_integration" = true ]; then
    echo
    print_info "⚠️  REQUIRED: Restart Home Assistant to complete entity removal"
    print_info "   Entities have been removed from registry and state files,"
    print_info "   but they're still in HA's runtime memory until restart."
    print_info ""
    print_info "   Run: ha restart"
    print_info "   Or use: Settings > System > Restart"
    print_info ""
    if [ "$remove_ha_integration" = true ]; then
        print_info "   After restart, if entities reappear, they may be recreated from:"
        print_info "   - MQTT discovery messages (check with: mosquitto_sub -h localhost -t 'homeassistant/#' -C 1 --retained-only)"
        print_info "   - Cached MQTT integration configuration"
    fi
fi

echo
print_success "Uninstallation complete!"
