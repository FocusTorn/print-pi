# Horseshoe Card

Local version of `flex-horseshoe-card` renamed to `horseshoe-card` for easy identification, with improved NaN handling, error resilience, and **preset system** for simplified configuration.

## Card Name

**Registered as:** `horseshoe-card` (not `flex-horseshoe-card`)
**Usage:** `type: custom:horseshoe-card`

This allows you to easily identify which version is loaded and causing errors.

## Directory Structure

```
_playground/home-assistant/custom-cards/horseshoe-card/
├── horseshoe-card.js    # Main card file (source)
└── README.md            # This file

www/custom-cards/horseshoe-card/
└── horseshoe-card.js    # Copy from _playground (runtime)
```

Both directories have the same structure for consistency.

## Features

### 1. **NaN Protection**
   - Validates all inputs (start, end, val) are valid numbers
   - Returns 0 instead of NaN for invalid inputs
   - Prevents division by zero errors

### 2. **Improved Value Calculation**
   - Converts min/max/state to numbers with fallbacks
   - Validates calculated value before use
   - Clamps value between 0 and 1

### 3. **Safe Gradient Offset Calculation**
   - Validates `val` before calculating `color1_offset`
   - Prevents "NaN%" errors in SVG gradient stops
   - Falls back to 0% if value is invalid

### 4. **Preset System** (NEW!)
   - Predefined layouts for common use cases
   - Simplified YAML configuration
   - Auto-maps entities to layout positions
   - Easy to extend with new presets

## Installation

1. **Copy to Home Assistant www directory:**
   ```bash
   sudo mkdir -p /home/pi/homeassistant/www/custom-cards/horseshoe-card
   sudo cp horseshoe-card.js /home/pi/homeassistant/www/custom-cards/horseshoe-card/
   sudo chown -R pi:pi /home/pi/homeassistant/www/custom-cards/horseshoe-card
   ```

2. **Add to Lovelace Resources:**
   - Go to **Settings** → **Dashboards** → **Resources**
   - Add resource: `/local/custom-cards/horseshoe-card/horseshoe-card.js`
   - Set type: **JavaScript Module**
   - **Important:** Remove or disable the HACS `flex-horseshoe-card` resource to avoid conflicts

## Usage

### Standard Configuration (Full Control)

```yaml
type: custom:horseshoe-card
entities:
  - entity: sensor.example
    decimals: 1
    unit: '°C'
primary_entity: entity.0
horseshoe_scale:
  min: 0
  max: 100
layout:
  states:
    - id: 0
      entity_index: 0
      xpos: 50
      ypos: 30
      # ... full layout config
```

### Preset Configuration (Simplified)

```yaml
type: custom:horseshoe-card
preset: "temp-3"  # Use temperature preset with 3 metrics

entities:
  - entity: sensor.smoothed_temperature    # Primary (auto-mapped to state id 0)
    decimals: 1
    unit: "°C"
  - entity: sensor.base_temperature        # Base (auto-mapped to state id 2)
    decimals: 1
    unit: "°C"
  - entity: sensor.smoothing_buffer        # Buffer (auto-mapped to state id 4)
    decimals: 0
    unit: ""

primary_entity: entity.0
horseshoe_scale:
  min: "{{ states('sensor.min_temp') | default(0, true) | float(0) }}"
  max: "{{ states('sensor.max_temp') | default(100, true) | float(100) }}"
color_stops:
  "0": "#2196F3"
  "25": "#4CAF50"
  "40": "#FF9800"
  "50": "#F44336"
```

## Available Presets

### `temp-3`
Temperature gauge with 3 metrics:
- **Primary value**: Large display at top center
- **T-formation layout**: 
  - Left: "B:" label + base temperature
  - Right: "S:" label + smoothing buffer
- **Auto entity mapping**:
  - State id 0 → Entity 0 (primary)
  - State id 2 → Entity 1 (base)
  - State id 4 → Entity 2 (buffer)
  - Labels (id 1, 3) → Entity 0 (for compatibility)

## Customizing Presets

You can override any preset value in your YAML:

```yaml
preset: "temp-3"
entities: [...]
# Override preset's show settings
show:
  scale_tickmarks: true  # Override preset's false
# Override specific layout positions
layout:
  states:
    - id: 0
      ypos: 25  # Move primary value higher
```

## Benefits

- ✅ No more "NaN%" errors when entities are unavailable
- ✅ Graceful handling of missing or invalid entity states
- ✅ Better error resilience
- ✅ **Easy identification** - card name is `horseshoe-card`
- ✅ **Simplified configuration** with presets
- ✅ **Auto entity mapping** - less YAML to write
- ✅ Maintains full compatibility with original card configuration

## Maintenance

- **Location**: `/home/pi/_playground/home-assistant/custom-cards/horseshoe-card/`
- **Source**: Based on flex-horseshoe-card from HACS
- **Version**: Local v2 (improved error handling, preset system)
- **Card Name**: `horseshoe-card` (registered as different custom element)

## Identifying Which Card is Loaded

When you see errors in the browser console, check the card name:
- `flex-horseshoe-card.js` = HACS version (original)
- `horseshoe-card.js` = Local fixed version (this one)

## Adding New Presets

To add a new preset, edit `horseshoe-card.js` and add to the `PRESETS` object:

```javascript
const PRESETS = {
  'temp-3': { ... },
  'your-preset-name': {
    layout: {
      states: [ /* layout states */ ],
      hlines: [ /* horizontal lines */ ],
      vlines: [ /* vertical lines */ ]
    },
    show: { /* display options */ }
  }
};
```

## Future Improvements

Potential enhancements:
- [ ] More preset templates (rate-3, dual-gauge, etc.)
- [ ] Dynamic preset generation based on entity count
- [ ] Bounding box calculations for automatic positioning
- [ ] Text size calculations for optimal spacing
- [ ] Add logging for invalid states (debug mode)
- [ ] Configurable fallback behavior
- [ ] Performance optimizations
