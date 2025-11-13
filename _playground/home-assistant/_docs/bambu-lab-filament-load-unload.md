# Bambu Lab A1 Filament Load/Unload Scripts

## Overview

The Bambu Lab HACS integration provides services for loading and unloading filament. This document describes the scripts created to make these operations easy to use in Home Assistant.

## Available Scripts

### 1. `a1_load_filament`
Loads filament from an external spool or AMS tray into the extruder.

**Parameters:**
- `entity_id` (required): The external spool or AMS tray entity ID
  - Example: `sensor.a1_external_spool_external_spool`
- `temperature` (optional): Target nozzle temperature in Celsius
  - If not specified, uses the filament's default temperature (midpoint between min/max)

**Usage:**
```yaml
service: script.a1_load_filament
data:
  entity_id: sensor.a1_external_spool_external_spool
  temperature: 220
```

### 2. `a1_unload_filament`
Unloads filament from the extruder.

**Parameters:**
- `entity_id` (required): The external spool or AMS tray entity ID that has the filament loaded

**Usage:**
```yaml
service: script.a1_unload_filament
data:
  entity_id: sensor.a1_external_spool_external_spool
```

## Finding Your Filament Entities

To find your external spool or AMS tray entities:

### Method 1: Using HA Helper
```bash
ha list-entities spool
ha list-entities tray
```

### Method 2: Using Developer Tools
1. Go to **Developer Tools** → **States**
2. Search for: `externalspool` or `tray`
3. Look for entities like:
   - `sensor.a1_external_spool_external_spool` (external spool)
   - `sensor.a1_ams_tray_1` (AMS tray 1, if AMS is installed)
   - `sensor.a1_ams_tray_2` (AMS tray 2, if AMS is installed)

### Method 3: Using Python Script
```python
import json
from pathlib import Path

registry_file = Path("/home/pi/homeassistant/.storage/core.entity_registry")
with open(registry_file, 'r') as f:
    data = json.load(f)

entities = data.get('data', {}).get('entities', [])
for entity in entities:
    entity_id = entity.get('entity_id', '')
    if 'spool' in entity_id.lower() or 'tray' in entity_id.lower():
        print(f"{entity_id} - {entity.get('name')}")
```

## Available Entities (Current System)

Based on the current system configuration (after entity rename):
- `sensor.a1_external_spool_external_spool` (primary external spool)

## Using in Automations

### Example: Load Filament Before Print
```yaml
automation:
  - alias: "Load Filament Before Print"
    trigger:
      - platform: state
        entity_id: button.a1_start_printing
        to: "pressed"
    action:
      - service: script.a1_load_filament
        data:
          entity_id: sensor.a1_external_spool_external_spool
          temperature: 220
```

### Example: Unload Filament After Print
```yaml
automation:
  - alias: "Unload Filament After Print"
    trigger:
      - platform: state
        entity_id: sensor.a1_print_status
        to: "FINISH"
    action:
      - service: script.a1_unload_filament
        data:
          entity_id: sensor.a1_external_spool_external_spool
```

## Using in Dashboards

Add button cards to your dashboard:

```yaml
type: entities
entities:
  - entity: script.a1_load_filament
    name: Load Filament
  - entity: script.a1_unload_filament
    name: Unload Filament
```

Or use custom button cards:

```yaml
type: custom:button-card
entity: script.a1_load_filament
name: Load Filament
icon: mdi:printer-3d-nozzle
tap_action:
  action: call-service
  service: script.a1_load_filament
  service_data:
    entity_id: sensor.a1_external_spool_external_spool
    temperature: 220
```

## Direct Service Calls

You can also call the services directly without using scripts:

### Load Filament
```yaml
service: bambu_lab.load_filament
target:
  entity_id: sensor.a1_external_spool_external_spool
data:
  temperature: 220  # Optional
```

### Unload Filament
```yaml
service: bambu_lab.unload_filament
target:
  entity_id: sensor.a1_external_spool_external_spool
```

## Important Notes

1. **Firmware Requirement**: Requires firmware that supports `AMS_SWITCH_COMMAND` (newer firmware versions)

2. **Entity Target**: You must target the specific AMS tray or external spool entity, not the printer entity itself

3. **Temperature**: For `load_filament`, if temperature is not specified, it uses the midpoint between the filament's min and max temperature

4. **Safety**: Always ensure the printer is in a safe state before loading/unloading filament

## Troubleshooting

### Script Not Found
- Ensure scripts are copied to `/home/pi/homeassistant/scripts/`
- Check that `scripts.yaml` uses `!include_dir_named scripts/`
- Restart Home Assistant after adding scripts

### Entity Not Found
- Verify your Bambu Lab printer is connected and configured
- Check entity IDs in Developer Tools → States
- Ensure the integration is properly set up

### Service Call Fails
- Check that your printer firmware supports the feature
- Verify the entity ID is correct
- Check Home Assistant logs: `ha logs-tail 50`

## Files Location

- **Scripts (Tracked)**: `/home/pi/_playground/home-assistant/scripts/`
- **Scripts (Runtime)**: `/home/pi/homeassistant/scripts/`
- **Configuration**: `/home/pi/homeassistant/scripts.yaml`

## Related Documentation

- [Bambu Lab HACS Integration](https://github.com/greghesp/ha-bambulab)
- [Bambu Lab Wiki](https://wiki.bambulab.com/)
- Home Assistant Scripts Documentation

