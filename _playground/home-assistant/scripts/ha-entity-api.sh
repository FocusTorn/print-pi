#!/bin/bash
# Home Assistant Entity Management API Helper
# Provides programmatic access to HA entity registry API for disable/delete/ignore operations
#
# Usage:
#   ha-entity-api.sh disable <entity_id>
#   ha-entity-api.sh delete <entity_id>
#   ha-entity-api.sh ignore-device <device_id>
#   ha-entity-api.sh get-entity <entity_id>
#   ha-entity-api.sh get-device <device_id>
#   ha-entity-api.sh list-entities [pattern]
#   ha-entity-api.sh list-devices [pattern]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
HA_CONTAINER="homeassistant"
HA_API_BASE="http://localhost:8123/api"
DOCKER_CMD="docker"

# Check if we need sudo for docker
if ! docker ps &> /dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
fi

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

# Extract HA_TOKEN from secrets file
get_token_from_secrets() {
    local secrets_file="${HOME}/.secrets"
    
    if [ ! -f "$secrets_file" ]; then
        return 1
    fi
    
    grep "^HA_TOKEN=" "$secrets_file" 2>/dev/null | \
        cut -d'=' -f2- | \
        sed "s/^['\"]//;s/['\"]$//" | \
        head -1
}

# Get authentication token
get_ha_token() {
    # Try environment variable first
    if [ -n "$HA_TOKEN" ]; then
        echo "$HA_TOKEN"
        return 0
    fi
    
    # Try secrets file
    if TOKEN=$(get_token_from_secrets 2>/dev/null); [ -n "$TOKEN" ]; then
        echo "$TOKEN"
        return 0
    fi
    
    # Try to extract from HA storage
    if $DOCKER_CMD ps --format '{{.Names}}' | grep -q "^${HA_CONTAINER}$"; then
        TOKEN=$($DOCKER_CMD exec "${HA_CONTAINER}" python3 <<'PYEOF' 2>/dev/null
import json
import os

token_files = [
    '/config/.storage/auth_provider.homeassistant',
    '/config/.storage/auth',
]

for token_file in token_files:
    if os.path.exists(token_file):
        try:
            with open(token_file, 'r') as f:
                data = json.load(f)
                # Look for refresh_tokens
                if 'data' in data and 'refresh_tokens' in data['data']:
                    for token_data in data['data']['refresh_tokens']:
                        if 'token' in token_data:
                            print(token_data['token'])
                            exit(0)
        except:
            pass
PYEOF
        )
        
        if [ -n "$TOKEN" ]; then
            echo "$TOKEN"
            return 0
        fi
    fi
    
    return 1
}

# Make HA API call
ha_api_call() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    local token
    
    if ! token=$(get_ha_token); then
        print_error "No HA token found!"
        echo "Set HA_TOKEN environment variable or add HA_TOKEN=... to ~/.secrets"
        return 1
    fi
    
    if ! $DOCKER_CMD ps --format '{{.Names}}' | grep -q "^${HA_CONTAINER}$"; then
        print_error "Home Assistant container is not running!"
        return 1
    fi
    
    local url="${HA_API_BASE}${endpoint}"
    local curl_cmd="curl -s -w '\n%{http_code}' -X ${method}"
    curl_cmd="${curl_cmd} -H 'Authorization: Bearer ${token}'"
    curl_cmd="${curl_cmd} -H 'Content-Type: application/json'"
    
    if [ -n "$data" ]; then
        curl_cmd="${curl_cmd} -d '${data}'"
    fi
    
    curl_cmd="${curl_cmd} '${url}'"
    
    local response
    response=$($DOCKER_CMD exec "${HA_CONTAINER}" bash -c "$curl_cmd" 2>&1)
    
    local http_code
    http_code=$(echo "$response" | tail -1 | tr -d '\r\n')
    local response_body
    response_body=$(echo "$response" | sed '$d')
    
    echo "$http_code|$response_body"
}

# Disable an entity
cmd_disable_entity() {
    local entity_id="$1"
    
    if [ -z "$entity_id" ]; then
        print_error "Entity ID required"
        echo "Usage: $0 disable <entity_id>"
        exit 1
    fi
    
    print_info "Disabling entity: ${entity_id}"
    
    local result
    result=$(ha_api_call "POST" "/config/entity_registry/${entity_id}/disable")
    local http_code
    http_code=$(echo "$result" | cut -d'|' -f1)
    local response_body
    response_body=$(echo "$result" | cut -d'|' -f2-)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        print_success "Entity disabled: ${entity_id}"
        return 0
    else
        print_error "Failed to disable entity (HTTP ${http_code})"
        if [ -n "$response_body" ]; then
            echo "$response_body" | head -5
        fi
        return 1
    fi
}

# Delete an entity
cmd_delete_entity() {
    local entity_id="$1"
    
    if [ -z "$entity_id" ]; then
        print_error "Entity ID required"
        echo "Usage: $0 delete <entity_id>"
        exit 1
    fi
    
    print_info "Deleting entity: ${entity_id}"
    
    local result
    result=$(ha_api_call "DELETE" "/config/entity_registry/${entity_id}")
    local http_code
    http_code=$(echo "$result" | cut -d'|' -f1)
    local response_body
    response_body=$(echo "$result" | cut -d'|' -f2-)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
        print_success "Entity deleted: ${entity_id}"
        return 0
    else
        print_error "Failed to delete entity (HTTP ${http_code})"
        if [ -n "$response_body" ]; then
            echo "$response_body" | head -5
        fi
        return 1
    fi
}

# Ignore a device
cmd_ignore_device() {
    local device_id="$1"
    
    if [ -z "$device_id" ]; then
        print_error "Device ID required"
        echo "Usage: $0 ignore-device <device_id>"
        exit 1
    fi
    
    print_info "Ignoring device: ${device_id}"
    
    # Ignore device via API
    local result
    result=$(ha_api_call "POST" "/config/device_registry/${device_id}/ignore" '{"ignore":true}')
    local http_code
    http_code=$(echo "$result" | cut -d'|' -f1)
    local response_body
    response_body=$(echo "$result" | cut -d'|' -f2-)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        print_success "Device ignored: ${device_id}"
        return 0
    else
        print_error "Failed to ignore device (HTTP ${http_code})"
        if [ -n "$response_body" ]; then
            echo "$response_body" | head -5
        fi
        return 1
    fi
}

# Get entity information
cmd_get_entity() {
    local entity_id="$1"
    
    if [ -z "$entity_id" ]; then
        print_error "Entity ID required"
        echo "Usage: $0 get-entity <entity_id>"
        exit 1
    fi
    
    local result
    result=$(ha_api_call "GET" "/config/entity_registry/${entity_id}")
    local http_code
    http_code=$(echo "$result" | cut -d'|' -f1)
    local response_body
    response_body=$(echo "$result" | cut -d'|' -f2-)
    
    if [ "$http_code" = "200" ]; then
        echo "$response_body" | python3 -m json.tool 2>/dev/null || echo "$response_body"
    else
        print_error "Failed to get entity (HTTP ${http_code})"
        if [ -n "$response_body" ]; then
            echo "$response_body" | head -5
        fi
        return 1
    fi
}

# Get device information
cmd_get_device() {
    local device_id="$1"
    
    if [ -z "$device_id" ]; then
        print_error "Device ID required"
        echo "Usage: $0 get-device <device_id>"
        exit 1
    fi
    
    local result
    result=$(ha_api_call "GET" "/config/device_registry/${device_id}")
    local http_code
    http_code=$(echo "$result" | cut -d'|' -f1)
    local response_body
    response_body=$(echo "$result" | cut -d'|' -f2-)
    
    if [ "$http_code" = "200" ]; then
        echo "$response_body" | python3 -m json.tool 2>/dev/null || echo "$response_body"
    else
        print_error "Failed to get device (HTTP ${http_code})"
        if [ -n "$response_body" ]; then
            echo "$response_body" | head -5
        fi
        return 1
    fi
}

# List entities
cmd_list_entities() {
    local pattern="${1:-}"
    
    local result
    result=$(ha_api_call "GET" "/config/entity_registry/list")
    local http_code
    http_code=$(echo "$result" | cut -d'|' -f1)
    local response_body
    response_body=$(echo "$result" | cut -d'|' -f2-)
    
    if [ "$http_code" != "200" ]; then
        print_error "Failed to list entities (HTTP ${http_code})"
        return 1
    fi
    
    echo "$response_body" | python3 <<PYEOF
import json
import sys

try:
    data = json.load(sys.stdin)
    entities = data if isinstance(data, list) else []
    
    pattern = '${pattern}'.lower() if '${pattern}' else ''
    
    matching = [e for e in entities 
                if not pattern or 
                pattern in e.get('entity_id', '').lower() or
                pattern in e.get('name', '').lower() or
                pattern in e.get('unique_id', '').lower()]
    
    if matching:
        print(f"{'Entity ID':<50} {'Name':<30} {'Platform':<15} {'Disabled':<10}")
        print("-" * 105)
        for e in sorted(matching, key=lambda x: x.get('entity_id', '')):
            entity_id = e.get('entity_id', 'unknown')[:48]
            name = (e.get('name') or 'N/A')[:28]
            platform = e.get('platform', 'unknown')[:13]
            disabled = 'Yes' if e.get('disabled_by') else 'No'
            print(f"{entity_id:<50} {name:<30} {platform:<15} {disabled:<10}")
        print(f"\nTotal: {len(matching)} entities" + (f" matching '{pattern}'" if pattern else ""))
    else:
        print("No entities found" + (f" matching '{pattern}'" if pattern else ""))
except Exception as e:
    print(f"Error parsing response: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
}

# List devices
cmd_list_devices() {
    local pattern="${1:-}"
    
    local result
    result=$(ha_api_call "GET" "/config/device_registry/list")
    local http_code
    http_code=$(echo "$result" | cut -d'|' -f1)
    local response_body
    response_body=$(echo "$result" | cut -d'|' -f2-)
    
    if [ "$http_code" != "200" ]; then
        print_error "Failed to list devices (HTTP ${http_code})"
        return 1
    fi
    
    echo "$response_body" | python3 <<PYEOF
import json
import sys

try:
    data = json.load(sys.stdin)
    devices = data if isinstance(data, list) else []
    
    pattern = '${pattern}'.lower() if '${pattern}' else ''
    
    matching = [d for d in devices 
                if not pattern or 
                pattern in d.get('name', '').lower() or
                any(pattern in str(ident).lower() for ident in d.get('identifiers', []))]
    
    if matching:
        print(f"{'Device ID':<40} {'Name':<30} {'Manufacturer':<20} {'Ignored':<10}")
        print("-" * 100)
        for d in sorted(matching, key=lambda x: x.get('name', '')):
            device_id = d.get('id', 'unknown')[:38]
            name = (d.get('name') or 'N/A')[:28]
            manufacturer = (d.get('manufacturer') or 'N/A')[:18]
            ignored = 'Yes' if d.get('disabled_by') else 'No'
            print(f"{device_id:<40} {name:<30} {manufacturer:<20} {ignored:<10}")
        print(f"\nTotal: {len(matching)} devices" + (f" matching '{pattern}'" if pattern else ""))
    else:
        print("No devices found" + (f" matching '{pattern}'" if pattern else ""))
except Exception as e:
    print(f"Error parsing response: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
}

# Main command dispatcher
main() {
    local command="${1:-}"
    
    case "$command" in
        disable)
            shift
            cmd_disable_entity "$@"
            ;;
        delete)
            shift
            cmd_delete_entity "$@"
            ;;
        ignore-device)
            shift
            cmd_ignore_device "$@"
            ;;
        get-entity)
            shift
            cmd_get_entity "$@"
            ;;
        get-device)
            shift
            cmd_get_device "$@"
            ;;
        list-entities)
            shift
            cmd_list_entities "$@"
            ;;
        list-devices)
            shift
            cmd_list_devices "$@"
            ;;
        *)
            echo "Home Assistant Entity Management API Helper"
            echo
            echo "Usage: $0 <command> [options]"
            echo
            echo "Commands:"
            echo "  disable <entity_id>          Disable an entity"
            echo "  delete <entity_id>           Delete an entity"
            echo "  ignore-device <device_id>    Ignore a device (prevent rediscovery)"
            echo "  get-entity <entity_id>       Get entity information"
            echo "  get-device <device_id>       Get device information"
            echo "  list-entities [pattern]      List all entities (optionally filtered)"
            echo "  list-devices [pattern]       List all devices (optionally filtered)"
            echo
            echo "Authentication:"
            echo "  Set HA_TOKEN environment variable or add HA_TOKEN=... to ~/.secrets"
            exit 1
            ;;
    esac
}

main "$@"

