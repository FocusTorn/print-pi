#!/bin/bash
# Script to rename A1 entities from long IDs to short IDs
# Example: sensor.a1_03919d532705945_print_status -> sensor.a1_print_status
#
# ⚠️  WARNING: This modifies the entity registry directly
#    - Backup will be created automatically
#    - Update your automations/dashboards to use new entity IDs
#    - Home Assistant will need to be restarted

set -e

# Detect HA config directory
if [ -z "$HA_CONFIG_DIR" ]; then
    # Try common locations
    if [ -d "/home/pi/homeassistant" ]; then
        HA_CONFIG_DIR="/home/pi/homeassistant"
    elif [ -d "/config" ]; then
        HA_CONFIG_DIR="/config"
    else
        echo "Error: Could not find Home Assistant config directory"
        echo "Set HA_CONFIG_DIR environment variable"
        exit 1
    fi
fi
ENTITY_REGISTRY="${HA_CONFIG_DIR}/.storage/core.entity_registry"
BACKUP_DIR="${HA_CONFIG_DIR}/.storage/backups"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔄 A1 Entity ID Renamer${NC}"
echo -e "${CYAN}==========================${NC}"
echo

# Check if entity registry exists
if [ ! -f "$ENTITY_REGISTRY" ]; then
    echo -e "${RED}❌ Entity registry not found: ${ENTITY_REGISTRY}${NC}"
    exit 1
fi

# Create backup
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="${BACKUP_DIR}/entity_registry_$(date +%Y%m%d_%H%M%S).json"
cp "$ENTITY_REGISTRY" "$BACKUP_FILE"
echo -e "${GREEN}✅ Backup created: ${BACKUP_FILE}${NC}"
echo

# Find the device serial number (pattern: a1_SERIAL_entity)
SERIAL=$(python3 << 'PYEOF'
import json
import sys

with open(sys.argv[1], 'r') as f:
    reg = json.load(f)

entities = reg.get('data', {}).get('entities', [])
a1_entities = [e for e in entities if 'a1_' in e.get('entity_id', '').lower()]

if not a1_entities:
    print("", file=sys.stderr)
    sys.exit(1)

# Extract serial from first entity (format: a1_SERIAL_entity)
first_id = a1_entities[0].get('entity_id', '')
parts = first_id.split('_')
if len(parts) >= 3:
    print(parts[1])  # The serial number
else:
    print("", file=sys.stderr)
    sys.exit(1)
PYEOF
"$ENTITY_REGISTRY" 2>/dev/null)

if [ -z "$SERIAL" ]; then
    echo -e "${RED}❌ Could not detect A1 device serial number${NC}"
    echo "   Make sure you have A1 entities in Home Assistant"
    exit 1
fi

echo -e "${CYAN}Detected device serial: ${SERIAL}${NC}"
echo
echo -e "${YELLOW}⚠️  This will rename all entities from:${NC}"
echo -e "   ${CYAN}a1_${SERIAL}_*${NC}"
echo -e "${YELLOW}   to:${NC}"
echo -e "   ${CYAN}a1_*${NC}"
echo
echo -e "${YELLOW}⚠️  WARNING:${NC}"
echo "   • You will need to update all automations, scripts, and dashboards"
echo "   • Home Assistant will need to be restarted"
echo "   • Backup has been created automatically"
echo
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}❌ Cancelled${NC}"
    exit 0
fi

# Perform the rename
python3 << PYEOF
import json
import sys
from pathlib import Path

registry_file = Path(sys.argv[1])
backup_file = sys.argv[2]
serial = sys.argv[3]

# Load registry
with open(registry_file, 'r') as f:
    reg = json.load(f)

entities = reg.get('data', {}).get('entities', [])
renamed_count = 0
renames = []

for entity in entities:
    old_id = entity.get('entity_id', '')
    
    # Check if this is an A1 entity with the serial number
    if f'a1_{serial.lower()}_' in old_id.lower():
        # Create new entity ID by removing serial number
        new_id = old_id.replace(f'a1_{serial.lower()}_', 'a1_')
        new_id = new_id.replace(f'a1_{serial}_', 'a1_')  # Handle case variations
        
        if new_id != old_id:
            entity['entity_id'] = new_id
            renames.append((old_id, new_id))
            renamed_count += 1

# Save updated registry
with open(registry_file, 'w') as f:
    json.dump(reg, f, indent=2)

print(f"✅ Renamed {renamed_count} entities")
print()
print("Renamed entities:")
for old, new in renames[:20]:  # Show first 20
    print(f"  {old}")
    print(f"  → {new}")
    print()

if len(renames) > 20:
    print(f"  ... and {len(renames) - 20} more")

print()
print(f"⚠️  Next steps:")
print(f"  1. Restart Home Assistant: ha restart")
print(f"  2. Update all automations/dashboards to use new entity IDs")
print(f"  3. Backup saved at: {backup_file}")
PYEOF
"$ENTITY_REGISTRY" "$BACKUP_FILE" "$SERIAL"

echo
echo -e "${GREEN}✅ Entity rename complete!${NC}"
echo -e "${YELLOW}⚠️  Remember to restart Home Assistant and update your configs${NC}"

