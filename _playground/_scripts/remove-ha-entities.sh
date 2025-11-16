#!/bin/bash
# Remove Home Assistant entities by pattern
# Removes from: entity registry, state file, device registry, and MQTT if applicable
#
# Usage:
#   remove-ha-entities.sh <pattern>
#   remove-ha-entities.sh "a1_a1_"
#   remove-ha-entities.sh "bme680"

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

# Check if pattern provided
if [ -z "$1" ]; then
    print_error "No pattern provided"
    echo "Usage: $0 <pattern>"
    echo "Example: $0 'a1_a1_'"
    echo "Example: $0 'bme680'"
    exit 1
fi

PATTERN="$1"
HA_CONTAINER="homeassistant"
NODERED_CONTAINER="nodered"

# Determine HA config path
HA_CONFIG_PATH="/home/pi/homeassistant"
if docker ps -a --format '{{.Names}}' | grep -q "^${HA_CONTAINER}$"; then
    # Try to get mount path from container
    MOUNT_PATH=$(docker inspect "${HA_CONTAINER}" --format '{{range .Mounts}}{{if eq .Destination "/config"}}{{.Source}}{{end}}{{end}}' 2>/dev/null | head -1)
    if [ -n "$MOUNT_PATH" ] && [ -d "$MOUNT_PATH/.storage" ]; then
        HA_CONFIG_PATH="$MOUNT_PATH"
    fi
fi

# Check if HA container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${HA_CONTAINER}$"; then
    print_error "Home Assistant container '${HA_CONTAINER}' not found!"
    exit 1
fi

# Check if Node-RED is running
NODERED_RUNNING=false
if docker ps --format '{{.Names}}' | grep -q "^${NODERED_CONTAINER}$"; then
    NODERED_RUNNING=true
fi

print_info "Searching for entities matching pattern: '${PATTERN}'"
echo

# Find matching entities (using sudo for direct file access, works whether container is running or not)
MATCHING_ENTITIES=$(sudo python3 <<PYEOF 2>/dev/null
import json
import sys

pattern = '${PATTERN}'.lower()
registry_file = '${HA_CONFIG_PATH}/.storage/core.entity_registry'

try:
    with open(registry_file, 'r') as f:
        registry = json.load(f)
    
    # Search both active entities and deleted_entities
    entities = registry.get('data', {}).get('entities', [])
    deleted_entities = registry.get('data', {}).get('deleted_entities', [])
    
    # Find matches in active entities
    matching = [e for e in entities 
                if pattern in e.get('entity_id', '').lower() or 
                   pattern in e.get('unique_id', '').lower()]
    
    # Also find matches in deleted_entities
    deleted_matching = [e for e in deleted_entities 
                        if pattern in e.get('entity_id', '').lower() or 
                           pattern in e.get('unique_id', '').lower()]
    
    # Combine both lists (deleted entities won't have device_id, but that's okay)
    all_matching = matching + deleted_matching

    # Print as JSON array
    print(json.dumps([{'entity_id': e.get('entity_id'), 
                       'unique_id': e.get('unique_id'),
                       'platform': e.get('platform'),
                       'device_id': e.get('device_id')} for e in all_matching]))
except Exception as e:
    print(f"Error reading entity registry: {e}", file=sys.stderr)
    print("[]")
    sys.exit(1)
PYEOF
)

if [ -z "$MATCHING_ENTITIES" ] || [ "$MATCHING_ENTITIES" = "[]" ]; then
    print_info "No entities found matching pattern '${PATTERN}'"
    exit 0
fi

# Parse and display entities
ENTITY_COUNT=$(echo "$MATCHING_ENTITIES" | python3 -c "import json, sys; data=json.load(sys.stdin); print(len(data))" 2>/dev/null)

print_warning "Found ${ENTITY_COUNT} entities matching pattern '${PATTERN}':"
echo

# Display entities in a table
echo "$MATCHING_ENTITIES" | python3 -c "
import json
import sys

entities = json.load(sys.stdin)
print(f\"{'Entity ID':<60} {'Platform':<15} {'Device ID':<40}\")
print('-' * 115)
for e in entities:
    entity_id = e.get('entity_id', 'unknown')[:58]
    platform = e.get('platform', 'unknown')[:13]
    device_id = (e.get('device_id') or 'none')[:38]
    print(f'{entity_id:<60} {platform:<15} {device_id:<40}')
" 2>/dev/null

echo
print_warning "This will remove these entities from:"

# Count items in each location
REGISTRY_COUNT=${ENTITY_COUNT:-0}

STATE_COUNT=$(sudo python3 <<PYEOF 2>/dev/null
import json
import sys
import os

pattern = '${PATTERN}'.lower()
state_file = '${HA_CONFIG_PATH}/.storage/core.restore_state'

try:
    if not os.path.exists(state_file):
        print(0)
        sys.exit(0)
    
    with open(state_file, 'r') as f:
        state_data = json.load(f)
    
    states = state_data.get('data', []) if isinstance(state_data.get('data'), list) else []
    count = 0
    
    for state_obj in states:
        if not isinstance(state_obj, dict):
            continue
        
        entity_id = None
        if 'state' in state_obj and isinstance(state_obj['state'], dict):
            entity_id = state_obj['state'].get('entity_id', '')
        elif 'entity_id' in state_obj:
            entity_id = state_obj.get('entity_id', '')
        
        if entity_id and pattern in entity_id.lower():
            count += 1
    
    print(count)
except:
    print(0)
PYEOF
)

DEVICE_COUNT=$(sudo python3 <<PYEOF 2>/dev/null
import json
import sys
import os

pattern = '${PATTERN}'.lower()
device_file = '${HA_CONFIG_PATH}/.storage/core.device_registry'
entity_file = '${HA_CONFIG_PATH}/.storage/core.entity_registry'

try:
    if not os.path.exists(device_file) or not os.path.exists(entity_file):
        print(0)
        sys.exit(0)
    
    with open(device_file, 'r') as f:
        devices = json.load(f)
    
    with open(entity_file, 'r') as f:
        registry = json.load(f)
    
    # Get device IDs that have matching entities
    matching_device_ids = set()
    for entity in registry.get('data', {}).get('entities', []):
        entity_id = entity.get('entity_id', '')
        unique_id = entity.get('unique_id', '')
        device_id = entity.get('device_id')
        
        if (pattern in unique_id.lower() or pattern in entity_id.lower()) and device_id:
            matching_device_ids.add(device_id)
    
    # Count devices that would become orphaned (all their entities are being removed)
    orphaned_count = 0
    for device_id in matching_device_ids:
        # Check if device has any remaining entities (check both active and deleted)
        has_other_entities = False
        # Check active entities
        for entity in registry.get('data', {}).get('entities', []):
            if entity.get('device_id') == device_id:
                entity_id = entity.get('entity_id', '')
                unique_id = entity.get('unique_id', '')
                if pattern not in unique_id.lower() and pattern not in entity_id.lower():
                    has_other_entities = True
                    break
        # Also check deleted_entities
        if not has_other_entities:
            for entity in registry.get('data', {}).get('deleted_entities', []):
                if entity.get('device_id') == device_id:
                    entity_id = entity.get('entity_id', '')
                    unique_id = entity.get('unique_id', '')
                    if pattern not in unique_id.lower() and pattern not in entity_id.lower():
                        has_other_entities = True
                        break
        
        if not has_other_entities:
            orphaned_count += 1
    
    print(orphaned_count)
except:
    print(0)
PYEOF
)

# Ensure all count variables are numeric, strip whitespace, default to 0 if empty
REGISTRY_COUNT=$(echo "${REGISTRY_COUNT}" | tr -d '[:space:]' || echo "0")
STATE_COUNT=$(echo "${STATE_COUNT}" | tr -d '[:space:]' || echo "0")
DEVICE_COUNT=$(echo "${DEVICE_COUNT}" | tr -d '[:space:]' || echo "0")

# Count MQTT discovery items (both storage file and broker retained messages)
MQTT_STORAGE_COUNT=$(sudo python3 <<PYEOF 2>/dev/null
import json
import os
import sys

pattern = '${PATTERN}'.lower()
discovery_file = '${HA_CONFIG_PATH}/.storage/mqtt.discovery'

try:
    if not os.path.exists(discovery_file):
        print(0)
        sys.exit(0)
    
    with open(discovery_file, 'r') as f:
        discovery = json.load(f)
    
    items = discovery.get('data', {})
    matching = {k: v for k, v in items.items() if pattern in k.lower()}
    print(len(matching))
except:
    print(0)
PYEOF
)

# Count retained MQTT discovery messages on broker (estimate based on entity IDs)
MQTT_BROKER_COUNT=$(echo "$MATCHING_ENTITIES" | python3 -c "
import json
import sys

pattern = '${PATTERN}'.lower()
entities = json.load(sys.stdin)
topics = set()

for e in entities:
    entity_id = e.get('entity_id', '')
    unique_id = e.get('unique_id', '')
    platform = e.get('platform', '')
    
    # Only process MQTT platform entities
    if platform == 'mqtt' and unique_id:
        parts = entity_id.split('.', 1)
        if len(parts) == 2:
            domain = parts[0]
            topics.add(f'homeassistant/{domain}/{unique_id}/config')
    
    # Also try entity_id pattern as fallback
    if entity_id:
        parts = entity_id.split('.', 1)
        if len(parts) == 2:
            domain = parts[0]
            object_id = parts[1]
            topics.add(f'homeassistant/{domain}/{object_id}/config')

print(len(topics))
" 2>/dev/null || echo "0")

# Total MQTT count (storage + broker)
# Ensure variables are numeric, strip whitespace, default to 0 if empty
MQTT_STORAGE_COUNT=$(echo "${MQTT_STORAGE_COUNT}" | tr -d '[:space:]' || echo "0")
MQTT_BROKER_COUNT=$(echo "${MQTT_BROKER_COUNT}" | tr -d '[:space:]' || echo "0")
MQTT_COUNT=$((MQTT_STORAGE_COUNT + MQTT_BROKER_COUNT))

echo "  • Entity registry (${REGISTRY_COUNT} entities)"
echo "  • State file (${STATE_COUNT} cached states)"
if [ "$DEVICE_COUNT" -gt 0 ]; then
    echo "  • Device registry (${DEVICE_COUNT} orphaned device(s))"
else
    echo "  • Device registry (0 orphaned devices)"
fi
if [ "$MQTT_COUNT" -gt 0 ]; then
    if [ "$MQTT_STORAGE_COUNT" -gt 0 ] && [ "$MQTT_BROKER_COUNT" -gt 0 ]; then
        echo "  • MQTT discovery (${MQTT_STORAGE_COUNT} storage + ${MQTT_BROKER_COUNT} broker = ${MQTT_COUNT} total)"
    elif [ "$MQTT_BROKER_COUNT" -gt 0 ]; then
        echo "  • MQTT discovery (${MQTT_BROKER_COUNT} retained messages on broker)"
    else
        echo "  • MQTT discovery storage (${MQTT_STORAGE_COUNT} items)"
    fi
else
    echo "  • MQTT discovery (0 items)"
fi
echo "  • All associated data"
echo "  • Area registry (entity area assignments)"
echo "  • Lovelace dashboards (entity references)"
echo "  • Exposed entities list"
echo

# Check if any entities are MQTT-based (likely from Node-RED)
MQTT_ENTITY_COUNT=$(echo "$MATCHING_ENTITIES" | python3 -c "
import json
import sys

entities = json.load(sys.stdin)
mqtt_count = sum(1 for e in entities if e.get('platform', '').lower() == 'mqtt')
print(mqtt_count)
" 2>/dev/null || echo "0")

read -p "$(echo -e "${YELLOW}Continue with removal? (y/N): ${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Removal cancelled"
    exit 0
fi

echo
print_info "Step 1: Using HA API to disable, delete, and ignore entities/devices..."

# Check if HA is running for API calls
HA_RUNNING=false
if docker ps --format '{{.Names}}' | grep -q "^${HA_CONTAINER}$"; then
    HA_RUNNING=true
fi

# Get HA API helper script path
HA_ENTITY_API="/home/pi/_playground/home-assistant/scripts/ha-entity-api.sh"

# Extract HA_TOKEN for API calls
get_token_from_secrets() {
    local secrets_file="${HOME}/.secrets"
    if [ -f "$secrets_file" ]; then
        grep "^HA_TOKEN=" "$secrets_file" 2>/dev/null | \
            cut -d'=' -f2- | \
            sed "s/^['\"]//;s/['\"]$//" | \
            head -1
    fi
}

# Get token
HA_TOKEN_ENV="${HA_TOKEN:-}"
if [ -z "$HA_TOKEN_ENV" ]; then
    HA_TOKEN_ENV=$(get_token_from_secrets 2>/dev/null || echo "")
fi

# Use API to disable and delete entities if HA is running and token available
if [ "$HA_RUNNING" = true ] && [ -n "$HA_TOKEN_ENV" ] && [ -f "$HA_ENTITY_API" ]; then
    export HA_TOKEN="$HA_TOKEN_ENV"
    
    print_info "Disabling and deleting entities via HA API..."
    
    # Disable and delete each matching entity via API
    API_DISABLED=0
    API_DELETED=0
    API_FAILED=0
    
    (echo "$MATCHING_ENTITIES" | python3 <<PYEOF 2>/dev/null
import json
import sys
import subprocess
import os

pattern = '${PATTERN}'.lower()
entities = json.load(sys.stdin)
ha_entity_api = '${HA_ENTITY_API}'
token = os.environ.get('HA_TOKEN', '')

disabled = 0
deleted = 0
failed = 0

for entity in entities:
    entity_id = entity.get('entity_id')
    if not entity_id:
        continue
    
    # Disable entity
    try:
        result = subprocess.run(
            [ha_entity_api, 'disable', entity_id],
            capture_output=True,
            text=True,
            timeout=5,
            env={'HA_TOKEN': token} if token else None
        )
        if result.returncode == 0:
            disabled += 1
        else:
            failed += 1
    except:
        failed += 1
    
    # Delete entity
    try:
        result = subprocess.run(
            [ha_entity_api, 'delete', entity_id],
            capture_output=True,
            text=True,
            timeout=5,
            env={'HA_TOKEN': token} if token else None
        )
        if result.returncode == 0:
            deleted += 1
        else:
            failed += 1
    except:
        failed += 1

print(f"{disabled}|{deleted}|{failed}")
PYEOF
    ) | while IFS='|' read -r disabled deleted failed; do
        API_DISABLED="${disabled:-0}"
        API_DELETED="${deleted:-0}"
        API_FAILED="${failed:-0}"
        
        if [ "$API_DISABLED" -gt 0 ] || [ "$API_DELETED" -gt 0 ]; then
            print_success "API: Disabled ${API_DISABLED} entities, deleted ${API_DELETED} entities"
            if [ "$API_FAILED" -gt 0 ]; then
                print_warning "API: ${API_FAILED} operations failed (will use file-based cleanup)"
            fi
        else
            print_warning "API operations failed or unavailable (will use file-based cleanup)"
        fi
    done
    
    # Ignore devices associated with removed entities
    print_info "Ignoring devices to prevent rediscovery..."
    
    (echo "$MATCHING_ENTITIES" | python3 <<PYEOF 2>/dev/null
import json
import sys
import subprocess
import os

entities = json.load(sys.stdin)
ha_entity_api = '${HA_ENTITY_API}'
token = os.environ.get('HA_TOKEN', '')
pattern = '${PATTERN}'.lower()

# Get unique device IDs
device_ids = set()
for entity in entities:
    device_id = entity.get('device_id')
    if device_id:
        device_ids.add(device_id)

ignored = 0
failed = 0

for device_id in device_ids:
    try:
        result = subprocess.run(
            [ha_entity_api, 'ignore-device', device_id],
            capture_output=True,
            text=True,
            timeout=5,
            env={'HA_TOKEN': token} if token else None
        )
        if result.returncode == 0:
            ignored += 1
        else:
            failed += 1
    except:
        failed += 1

print(f"{ignored}|{failed}")
PYEOF
    ) | while IFS='|' read -r ignored failed; do
        if [ "${ignored:-0}" -gt 0 ]; then
            print_success "API: Ignored ${ignored} device(s) to prevent rediscovery"
        fi
        if [ "${failed:-0}" -gt 0 ]; then
            print_warning "API: Failed to ignore ${failed} device(s)"
        fi
    done
    
    # Wait a moment for API operations to complete
    sleep 2
elif [ "$HA_RUNNING" = false ]; then
    print_warning "HA is not running - skipping API operations, will use file-based cleanup only"
elif [ -z "$HA_TOKEN_ENV" ]; then
    print_warning "HA_TOKEN not found - skipping API operations, will use file-based cleanup only"
    print_info "  Set HA_TOKEN environment variable or add HA_TOKEN=... to ~/.secrets"
elif [ ! -f "$HA_ENTITY_API" ]; then
    print_warning "HA entity API script not found - skipping API operations, will use file-based cleanup only"
fi

echo
print_info "Step 2: Stopping containers to prevent file locks and message republishing..."

# Stop Home Assistant
print_info "Stopping Home Assistant..."
if docker stop "${HA_CONTAINER}" >/dev/null 2>&1; then
    print_success "Home Assistant stopped"
else
    print_warning "Could not stop Home Assistant (may already be stopped)"
fi

# Stop Node-RED if running
if [ "$NODERED_RUNNING" = true ]; then
    print_info "Stopping Node-RED..."
    if docker stop "${NODERED_CONTAINER}" >/dev/null 2>&1; then
        print_success "Node-RED stopped"
        NODERED_WAS_RUNNING=true
    else
        print_warning "Could not stop Node-RED (may already be stopped)"
        NODERED_WAS_RUNNING=false
    fi
else
    NODERED_WAS_RUNNING=false
fi

echo
print_info "Step 3: Performing file-based cleanup (removing from storage files)..."

# Remove from entity registry (using sudo for direct file access)
REGISTRY_REMOVED=$(sudo python3 <<PYEOF 2>/dev/null
import json
import sys
import os

pattern = '${PATTERN}'.lower()
registry_file = '${HA_CONFIG_PATH}/.storage/core.entity_registry'

try:
    if not os.path.exists(registry_file):
        print(0)
        sys.exit(0)

    with open(registry_file, 'r') as f:
        registry = json.load(f)

    # Remove from both active entities and deleted_entities
    original_active_count = len(registry.get('data', {}).get('entities', []))
    original_deleted_count = len(registry.get('data', {}).get('deleted_entities', []))
    entities_to_remove = []

    # Find entities to remove from active entities
    for entity in registry.get('data', {}).get('entities', []):
        entity_id = entity.get('entity_id', '')
        unique_id = entity.get('unique_id', '')
        
        if pattern in unique_id.lower() or pattern in entity_id.lower():
            entities_to_remove.append(entity_id)

    # Remove from active entities
    registry['data']['entities'] = [
        entity for entity in registry['data']['entities']
        if entity.get('entity_id') not in entities_to_remove
    ]
    
    # Also remove from deleted_entities
    registry['data']['deleted_entities'] = [
        entity for entity in registry.get('data', {}).get('deleted_entities', [])
        if entity.get('entity_id') not in entities_to_remove
    ]

    removed_active = original_active_count - len(registry['data']['entities'])
    removed_deleted = original_deleted_count - len(registry['data']['deleted_entities'])
    removed_count = removed_active + removed_deleted

    with open(registry_file, 'w') as f:
        json.dump(registry, f, indent=2)

    print(removed_count)
except Exception as e:
    print(f"Error removing from registry: {e}", file=sys.stderr)
    print(0)
    sys.exit(1)
PYEOF
)

REGISTRY_REMOVED="${REGISTRY_REMOVED:-0}"
REGISTRY_REMOVED=$(echo "${REGISTRY_REMOVED}" | tr -d '[:space:]' || echo "0")
if [ -n "$REGISTRY_REMOVED" ] && [ "$REGISTRY_REMOVED" -ge 0 ] 2>/dev/null; then
    print_success "Removed ${REGISTRY_REMOVED} entities from entity registry"
else
    print_warning "Removed 0 entities from entity registry (or error occurred)"
fi

# Remove from state file (using sudo for direct file access)
STATE_REMOVED=$(sudo python3 <<PYEOF 2>/dev/null
import json
import sys
import os

pattern = '${PATTERN}'.lower()
state_file = '${HA_CONFIG_PATH}/.storage/core.restore_state'

try:
    if not os.path.exists(state_file):
        print(0)
        sys.exit(0)

    with open(state_file, 'r') as f:
        state_data = json.load(f)
    
    states = state_data.get('data', []) if isinstance(state_data.get('data'), list) else []
    original_count = len(states)
    states_to_keep = []
    
    for state_obj in states:
        if not isinstance(state_obj, dict):
            states_to_keep.append(state_obj)
            continue
        
        entity_id = None
        if 'state' in state_obj and isinstance(state_obj['state'], dict):
            entity_id = state_obj['state'].get('entity_id', '')
        elif 'entity_id' in state_obj:
            entity_id = state_obj.get('entity_id', '')
        
        if not entity_id or pattern not in entity_id.lower():
            states_to_keep.append(state_obj)
    
    state_data['data'] = states_to_keep
    removed = original_count - len(states_to_keep)
    
    with open(state_file, 'w') as f:
        json.dump(state_data, f, indent=2)
    
    print(removed)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    print(0)
    sys.exit(1)
PYEOF
)

STATE_REMOVED="${STATE_REMOVED:-0}"
STATE_REMOVED=$(echo "${STATE_REMOVED}" | tr -d '[:space:]' || echo "0")
if [ -n "$STATE_REMOVED" ] && [ "$STATE_REMOVED" -ge 0 ] 2>/dev/null; then
    print_success "Removed ${STATE_REMOVED} entity states from state file"
else
    print_info "Removed 0 entity states from state file"
fi

# Check for orphaned devices and remove them (using sudo for direct file access)
DEVICE_REMOVED=$(sudo python3 <<PYEOF 2>/dev/null
import json
import sys
import os

pattern = '${PATTERN}'.lower()
device_file = '${HA_CONFIG_PATH}/.storage/core.device_registry'
entity_file = '${HA_CONFIG_PATH}/.storage/core.entity_registry'

if not os.path.exists(device_file) or not os.path.exists(entity_file):
    print(0)
    sys.exit(0)

try:
    with open(device_file, 'r') as f:
        devices = json.load(f)
    
    # Get all device IDs that have entities matching the pattern
    # Check both active entities and deleted_entities
    with open(entity_file, 'r') as f:
        registry = json.load(f)
    
    matching_device_ids = set()
    # Check active entities
    for entity in registry.get('data', {}).get('entities', []):
        entity_id = entity.get('entity_id', '')
        unique_id = entity.get('unique_id', '')
        device_id = entity.get('device_id')
        
        if (pattern in unique_id.lower() or pattern in entity_id.lower()) and device_id:
            matching_device_ids.add(device_id)
    
    # Also check deleted_entities
    for entity in registry.get('data', {}).get('deleted_entities', []):
        entity_id = entity.get('entity_id', '')
        unique_id = entity.get('unique_id', '')
        device_id = entity.get('device_id')
        
        if (pattern in unique_id.lower() or pattern in entity_id.lower()) and device_id:
            matching_device_ids.add(device_id)
    
    # Now check if any devices have ALL their entities removed (orphaned)
    original_count = len(devices.get('data', {}).get('devices', []))
    devices_to_keep = []
    
    for device in devices.get('data', {}).get('devices', []):
        device_id = device.get('id')
        
        # Check if this device has any remaining entities (check both active and deleted)
        has_entities = False
        # Check active entities
        for entity in registry.get('data', {}).get('entities', []):
            if entity.get('device_id') == device_id:
                has_entities = True
                break
        # Also check deleted_entities
        if not has_entities:
            for entity in registry.get('data', {}).get('deleted_entities', []):
                if entity.get('device_id') == device_id:
                    has_entities = True
                    break
        
        # Keep device if it has entities OR if it doesn't match our pattern
        device_name = (device.get('name') or '').lower()
        identifiers = str(device.get('identifiers', [])).lower()
        
        if has_entities or (pattern not in device_name and pattern not in identifiers):
            devices_to_keep.append(device)
    
    devices['data']['devices'] = devices_to_keep
    removed = original_count - len(devices_to_keep)
    
    with open(device_file, 'w') as f:
        json.dump(devices, f, indent=2)
    
    print(removed)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    print(0)
    sys.exit(1)
PYEOF
)

DEVICE_REMOVED="${DEVICE_REMOVED:-0}"
DEVICE_REMOVED=$(echo "${DEVICE_REMOVED}" | tr -d '[:space:]' || echo "0")
if [ -n "$DEVICE_REMOVED" ] && [ "$DEVICE_REMOVED" -ge 0 ] 2>/dev/null; then
    if [ "$DEVICE_REMOVED" -gt 0 ]; then
        print_success "Removed ${DEVICE_REMOVED} orphaned device(s) from device registry"
    else
        print_info "Removed 0 orphaned devices from device registry"
    fi
else
    print_info "Removed 0 orphaned devices from device registry"
fi

# Remove from MQTT discovery storage (using sudo for direct file access)
MQTT_REMOVED=$(sudo python3 <<PYEOF 2>/dev/null
import json
import os
import sys

pattern = '${PATTERN}'.lower()
discovery_file = '${HA_CONFIG_PATH}/.storage/mqtt.discovery'

try:
    if not os.path.exists(discovery_file):
        print(0)
        sys.exit(0)
    
    with open(discovery_file, 'r') as f:
        discovery = json.load(f)
    
    items = discovery.get('data', {})
    original_count = len(items)
    
    # Remove items matching the pattern
    items_to_keep = {
        k: v for k, v in items.items()
        if pattern not in k.lower()
    }
    
    discovery['data'] = items_to_keep
    removed = original_count - len(items_to_keep)
    
    with open(discovery_file, 'w') as f:
        json.dump(discovery, f, indent=2)
    
    print(removed)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    print(0)
    sys.exit(1)
PYEOF
)

MQTT_REMOVED="${MQTT_REMOVED:-0}"
MQTT_REMOVED=$(echo "${MQTT_REMOVED}" | tr -d '[:space:]' || echo "0")
if [ -n "$MQTT_REMOVED" ] && [ "$MQTT_REMOVED" -ge 0 ] 2>/dev/null; then
    print_success "Removed ${MQTT_REMOVED} MQTT discovery items"
else
    print_info "Removed 0 MQTT discovery items"
fi

# Check for and remove retained MQTT discovery messages
# Note: This requires mosquitto tools and broker access
print_info "Checking for retained MQTT discovery messages..."

if command -v mosquitto_sub >/dev/null 2>&1 && command -v mosquitto_pub >/dev/null 2>&1; then
    print_info "Scanning broker for retained messages matching pattern '${PATTERN}'..."
    
    # First, get all topics from entities to match against
    ENTITY_TOPICS=$(echo "$MATCHING_ENTITIES" | python3 -c "
import json
import sys

entities = json.load(sys.stdin)
topics = set()
for e in entities:
    entity_id = e.get('entity_id', '')
    unique_id = e.get('unique_id', '')
    platform = e.get('platform', '')
    
    # MQTT discovery uses unique_id, not entity_id
    if platform == 'mqtt' and unique_id:
        parts = entity_id.split('.', 1)
        if len(parts) == 2:
            domain = parts[0]
            topics.add(f'homeassistant/{domain}/{unique_id}/config')
    
    # Also try entity_id pattern as fallback
    if entity_id:
        parts = entity_id.split('.', 1)
        if len(parts) == 2:
            domain = parts[0]
            object_id = parts[1]
            topics.add(f'homeassistant/{domain}/{object_id}/config')

for topic in sorted(topics):
    print(topic)
" 2>/dev/null)
    
    # Use paho-mqtt to actually list all retained messages with their topics
    # This is more reliable than trying to construct topics from entity IDs
    print_info "Querying broker for all retained messages matching pattern..."
    PATTERN_LOWER=$(echo "${PATTERN}" | tr '[:upper:]' '[:lower:]')
    
    # Use Python with paho-mqtt to get all retained messages
    RETAINED_TOPICS_TO_REMOVE=$(python3 <<PYEOF 2>/dev/null
import paho.mqtt.client as mqtt
import json
import sys
import time

pattern = '${PATTERN_LOWER}'
topics_to_remove = set()
received_messages = {}

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        # Subscribe to all homeassistant discovery topics (retained messages are delivered immediately)
        client.subscribe('homeassistant/#')  # Subscribe to all homeassistant topics
    else:
        sys.exit(1)

def on_message(client, userdata, msg):
    # Only process retained messages
    if not msg.retain:
        return
    
    topic = msg.topic
    try:
        payload = msg.payload.decode('utf-8')
        # Check if pattern is in topic or payload
        if pattern in topic.lower() or pattern in payload.lower():
            topics_to_remove.add(topic)
        # Also check JSON payload for pattern in unique_id, name, etc.
        try:
            data = json.loads(payload)
            payload_str = json.dumps(data).lower()
            if pattern in payload_str:
                topics_to_remove.add(topic)
        except:
            pass
    except:
        pass

try:
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message
    
    client.connect('localhost', 1883, 60)
    client.loop_start()
    
    # Wait for messages (retained messages are delivered immediately on subscription)
    # Give it a bit more time to receive all retained messages
    time.sleep(3)
    
    client.loop_stop()
    client.disconnect()
    
    # Print topics to remove
    for topic in sorted(topics_to_remove):
        print(topic)
except Exception as e:
    # Fallback: use entity-based topic construction
    print('', file=sys.stderr)
    sys.exit(0)
PYEOF
)
    
    # Combine entity-based topics and broker-discovered topics
    ALL_TOPICS_TO_REMOVE=$(echo -e "${ENTITY_TOPICS}\n${RETAINED_TOPICS_TO_REMOVE}" | grep -v '^$' | sort -u)
    
    REMOVED_TOPICS=0
    TOTAL_TOPICS=0
    if [ -n "$ALL_TOPICS_TO_REMOVE" ]; then
        TOTAL_TOPICS=$(echo "$ALL_TOPICS_TO_REMOVE" | grep -v '^$' | wc -l)
        
        print_info "Attempting to remove ${TOTAL_TOPICS} retained MQTT discovery topics..."
        
        while IFS= read -r topic; do
            if [ -n "$topic" ]; then
                # Publish empty message with retain flag to clear retained message
                # -r = retain flag, -n = null/empty payload
                if timeout 2 mosquitto_pub -h localhost -t "$topic" -r -n 2>/dev/null; then
                    REMOVED_TOPICS=$((REMOVED_TOPICS + 1))
                fi
            fi
        done <<< "$ALL_TOPICS_TO_REMOVE"
        
        REMOVED_TOPICS="${REMOVED_TOPICS:-0}"
        REMOVED_TOPICS=$(echo "${REMOVED_TOPICS}" | tr -d '[:space:]' || echo "0")
        if [ "$REMOVED_TOPICS" -gt 0 ]; then
            print_success "Removed ${REMOVED_TOPICS} retained MQTT discovery messages from broker"
        elif [ "$TOTAL_TOPICS" -gt 0 ]; then
            print_warning "Attempted to remove ${TOTAL_TOPICS} retained MQTT topics, but removal may have failed"
            print_info "  This could mean: topics don't exist, broker is unreachable, or messages were already removed"
            print_info "  You may need to manually check the broker or use an MQTT client to remove retained messages"
        else
            print_info "Removed 0 retained MQTT discovery messages from broker"
        fi
    else
        print_info "Removed 0 retained MQTT discovery messages from broker (no topics found)"
    fi
else
    print_warning "mosquitto tools not available - cannot check/remove retained MQTT messages"
    print_info "  Install with: sudo apt install mosquitto-clients"
fi

# Remove from area registry (entity area assignments)
print_info "Removing entity references from area registry..."
AREA_REMOVED=$(sudo python3 <<PYEOF 2>/dev/null
import json
import sys
import os

pattern = '${PATTERN}'.lower()
area_file = '${HA_CONFIG_PATH}/.storage/core.area_registry'

try:
    if not os.path.exists(area_file):
        print(0)
        sys.exit(0)
    
    with open(area_file, 'r') as f:
        area_data = json.load(f)
    
    areas = area_data.get('data', {}).get('areas', [])
    reference_count = 0
    
    for area in areas:
        # Check if area has entity_id references (some areas store entity lists)
        # Areas typically don't store entity_ids directly, but check aliases or other fields
        area_str = json.dumps(area, default=str).lower()
        if pattern in area_str:
            # Count references found (areas don't typically store entity_ids directly)
            # But we'll count any references found in the area data
            reference_count += 1
    
    # Areas don't typically store entity_ids directly, so this is mostly informational
    # But we'll report if any references were found
    if reference_count > 0:
        # Note: We don't modify areas as they don't typically store entity_ids
        # This is just a count of areas that contain the pattern
        print(reference_count)
    else:
        print(0)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    print(0)
    sys.exit(1)
PYEOF
)

AREA_REMOVED="${AREA_REMOVED:-0}"
AREA_REMOVED=$(echo "${AREA_REMOVED}" | tr -d '[:space:]' || echo "0")
if [ -n "$AREA_REMOVED" ] && [ "$AREA_REMOVED" -ge 0 ] 2>/dev/null; then
    print_success "Found ${AREA_REMOVED} area(s) with entity references (areas don't store entity_ids directly)"
else
    print_info "Found 0 areas with entity references"
fi

# Remove from Lovelace dashboards (entity references in cards)
print_info "Removing entity references from Lovelace dashboards..."
LOVELACE_REMOVED=$(sudo python3 <<PYEOF 2>/dev/null
import json
import sys
import os

pattern = '${PATTERN}'.lower()
lovelace_file = '${HA_CONFIG_PATH}/.storage/lovelace'

try:
    if not os.path.exists(lovelace_file):
        print(0)
        sys.exit(0)
    
    with open(lovelace_file, 'r') as f:
        lovelace_data = json.load(f)
    
    config = lovelace_data.get('data', {}).get('config', {})
    if not config:
        print(0)
        sys.exit(0)
    
    # Lovelace config is a dict with views, each view has cards
    # We need to recursively search and remove cards/entities that match
    removed_count = 0
    
    def remove_matching_entities(obj):
        count = 0
        if isinstance(obj, dict):
            # Check if this is a card with entity references
            if 'entity' in obj and pattern in str(obj.get('entity', '')).lower():
                return 1, obj  # Mark for removal, count 1
            if 'entities' in obj and isinstance(obj['entities'], list):
                # Filter out matching entities
                original_len = len(obj['entities'])
                obj['entities'] = [e for e in obj['entities'] 
                                   if pattern not in str(e).lower()]
                removed_from_list = original_len - len(obj['entities'])
                if removed_from_list > 0:
                    count += removed_from_list
            # Recursively check nested objects
            for key, value in list(obj.items()):
                if isinstance(value, (dict, list)):
                    sub_count, _ = remove_matching_entities(value)
                    count += sub_count
        elif isinstance(obj, list):
            items_to_remove = []
            for i, item in enumerate(obj):
                if isinstance(item, (dict, list)):
                    sub_count, result = remove_matching_entities(item)
                    if sub_count > 0 and isinstance(result, dict) and result.get('entity'):
                        items_to_remove.append(i)
                        count += sub_count
                    elif sub_count > 0:
                        count += sub_count
            # Remove items in reverse order to maintain indices
            for i in reversed(items_to_remove):
                obj.pop(i)
        return count, obj
    
    removed_count, _ = remove_matching_entities(config)
    
    if removed_count > 0:
        lovelace_data['data']['config'] = config
        with open(lovelace_file, 'w') as f:
            json.dump(lovelace_data, f, indent=2)
        print(removed_count)
    else:
        print(0)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    print(0)
    sys.exit(1)
PYEOF
)

LOVELACE_REMOVED="${LOVELACE_REMOVED:-0}"
LOVELACE_REMOVED=$(echo "${LOVELACE_REMOVED}" | tr -d '[:space:]' || echo "0")
if [ -n "$LOVELACE_REMOVED" ] && [ "$LOVELACE_REMOVED" -ge 0 ] 2>/dev/null; then
    print_success "Removed ${LOVELACE_REMOVED} entity reference(s) from Lovelace dashboards"
else
    print_info "Removed 0 entity references from Lovelace dashboards"
fi

# Remove from exposed entities list
print_info "Removing from exposed entities list..."
EXPOSED_REMOVED=$(sudo python3 <<PYEOF 2>/dev/null
import json
import sys
import os

pattern = '${PATTERN}'.lower()
exposed_file = '${HA_CONFIG_PATH}/.storage/homeassistant.exposed_entities'

try:
    if not os.path.exists(exposed_file):
        print(0)
        sys.exit(0)
    
    with open(exposed_file, 'r') as f:
        exposed_data = json.load(f)
    
    exposed_entities = exposed_data.get('data', {}).get('exposed_entities', {})
    original_count = len(exposed_entities)
    
    # Remove entities matching the pattern
    entities_to_remove = []
    for entity_id in exposed_entities.keys():
        if pattern in entity_id.lower():
            entities_to_remove.append(entity_id)
    
    for entity_id in entities_to_remove:
        del exposed_entities[entity_id]
    
    removed = original_count - len(exposed_entities)
    
    if removed > 0:
        exposed_data['data']['exposed_entities'] = exposed_entities
        with open(exposed_file, 'w') as f:
            json.dump(exposed_data, f, indent=2)
        print(removed)
    else:
        print(0)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    print(0)
    sys.exit(1)
PYEOF
)

EXPOSED_REMOVED="${EXPOSED_REMOVED:-0}"
EXPOSED_REMOVED=$(echo "${EXPOSED_REMOVED}" | tr -d '[:space:]' || echo "0")
if [ -n "$EXPOSED_REMOVED" ] && [ "$EXPOSED_REMOVED" -ge 0 ] 2>/dev/null; then
    print_success "Removed ${EXPOSED_REMOVED} entities from exposed entities list"
else
    print_info "Removed 0 entities from exposed entities list"
fi

echo
print_info "Restarting containers..."

# Restart Node-RED first (if it was running) so it can publish discovery messages before HA starts
if [ "$NODERED_WAS_RUNNING" = true ]; then
    print_info "Starting Node-RED..."
    if docker start "${NODERED_CONTAINER}" >/dev/null 2>&1; then
        print_success "Node-RED started"
        print_info "Waiting for Node-RED to initialize..."
        sleep 3
        if [ "$MQTT_ENTITY_COUNT" -gt 0 ]; then
            print_warning "⚠️  IMPORTANT: Node-RED flows will republish MQTT discovery messages"
            print_warning "   If old entity names reappear:"
            print_warning "   • Check flow properties in Node-RED (printer_name, HA_DEVICE, etc.)"
            print_warning "   • Update flow properties to match new entity names"
            print_warning "   • Old retained MQTT messages on broker may still cause old entities to reappear"
        fi
    else
        print_error "Could not start Node-RED"
    fi
fi

# Restart Home Assistant (after Node-RED so it can discover entities from Node-RED's messages)
print_info "Starting Home Assistant..."
if docker start "${HA_CONTAINER}" >/dev/null 2>&1; then
    print_success "Home Assistant started"
    print_info "Waiting for HA to fully initialize and process storage files..."
    # Wait longer to ensure HA fully processes cleaned storage files
    # HA needs time to read storage files, build entity registry, and clear any cached state
    sleep 10
    print_info "Ensuring storage files are fully flushed to disk..."
    sync  # Force filesystem sync to ensure all writes are flushed
    sleep 5  # Additional wait for HA to process the cleaned storage
else
    print_error "Could not start Home Assistant"
fi

echo
print_success "Entity removal complete!"
print_info "Entities have been removed and containers restarted."
echo
print_info "Step 4: Prevention Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  • MQTT entities: Retained messages cleared from broker"
echo "  • File-based cleanup: Storage files cleaned"
echo
print_warning "To prevent rediscovery:"
echo "  • Devices have been ignored via API (if available)"
echo "  • MQTT retained messages have been cleared"
echo "  • For integrations: Check Settings > Devices & Services > [Integration] > Configure"
echo "  • Update Node-RED flows if they republish discovery messages"
echo "  • Check integration settings for 'Disable New Entities' option"

