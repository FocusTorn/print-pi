# Home Assistant Custom Cards

This directory contains custom card definitions for Home Assistant dashboards.

## Available Cards

### `a1-hotend-filament-control.yaml`

A custom card displaying:
- **LOAD** and **UNLOAD** buttons for filament control
- Hotend temperature progress bar (current/target)
- Color-coded status indicators

**Features:**
- Visual temperature progress bar showing current vs target
- Current and target temperature display
- Status indicator (Ready/Heating/Cold/Idle)
- Integrated Load/Unload filament buttons

**Entities Used:**
- `sensor.a1_nozzle_temperature` - Current hotend temperature
- `sensor.a1_nozzle_target_temperature` - Target hotend temperature
- `sensor.a1_external_spool_external_spool` - External spool entity for filament operations

## Usage

### Option 1: Edit Dashboard in YAML Mode (Recommended)

1. Go to your dashboard
2. Click the three dots menu (⋮) → **Edit Dashboard**
3. Click the three dots menu again → **Edit in YAML**
4. Add this card to your `cards:` section:

```yaml
cards:
  - type: vertical-stack
    cards:
      # Paste the entire content from a1-hotend-filament-control.yaml
      # starting from the "cards:" section
```

Or copy the entire content from `a1-hotend-filament-control-inline.yaml` and paste it as a card entry.

### Option 2: Add via UI (Manual Steps)

1. Add a **Vertical Stack** card to your dashboard
2. Click the three dots on the card → **Edit in YAML**
3. Replace the content with the entire content from `a1-hotend-filament-control.yaml`
4. Save

### Option 3: Raw YAML Dashboard File

If editing raw dashboard YAML files, you can use:

```yaml
cards:
  - type: vertical-stack
    cards:
      # Copy content from a1-hotend-filament-control.yaml starting from "cards:"
```

**Note:** `!include` directives don't work when editing dashboards in the UI. You must paste the card content directly.

## Requirements

**Required Custom Cards:**
- `button-card` (HACS: [button-card](https://github.com/custom-cards/button-card))
- `card-mod` (HACS: [card-mod](https://github.com/thomasloven/lovelace-card-mod))

**Required Scripts:**
- `script.a1_load_filament`
- `script.a1_unload_filament`

**Required Entities:**
- `sensor.a1_nozzle_temperature`
- `sensor.a1_nozzle_target_temperature`
- `sensor.a1_external_spool_external_spool`

## Installation

1. Ensure required custom cards are installed via HACS
2. Copy card files to your HA config directory (if needed)
3. Include the card in your dashboard YAML
4. Reload the dashboard

## Customization

### Adjusting Colors

Edit the RGB values in the card:
- Green (Ready/Load): `rgb(76, 175, 80)`
- Red (Unload/Cold): `rgb(244, 67, 54)`
- Orange (Heating): `rgb(255, 152, 0)`
- Blue (Target): `rgb(33, 150, 243)`

### Adjusting Temperature Range

Change `max_temp` in the progress bar calculation (default: 300°C):

```yaml
{% set max_temp = 300 %}  # Change this value
```

### Changing Button Behavior

Modify the `tap_action` sections to change what happens when buttons are clicked.

