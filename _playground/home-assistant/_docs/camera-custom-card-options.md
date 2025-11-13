# Custom Card Options for Expandable Camera

This document outlines different approaches to creating an expandable camera card in Home Assistant using custom Lovelace cards.

## Current Setup (Working)

The current dashboard uses **two conditional cards** that show/hide based on `input_boolean.camera_a1_expanded`:
- Small view: 4 columns × 3 rows (when `off`)
- Large view: full width × 12 rows (when `on`)

**Location**: `dashboard-a1-sections.yaml` (lines 18-58)

## Custom Card Options

### Option 1: `custom:state-switch` ⭐ **Recommended**

**Status**: Not installed (needs HACS installation)

**Benefits**:
- Single card instead of two conditionals
- Cleaner YAML configuration
- Better performance
- Easier to maintain

**Installation**:
1. HACS → Frontend → Lovelace Cards
2. Search: `state-switch`
3. Install: "State Switch" by thomasloven
4. Restart Home Assistant

**Example**: See `dashboard-a1-camera-custom-card-example.yaml` (Example 1)

**Configuration**:
```yaml
- type: custom:state-switch
  entity: input_boolean.camera_a1_expanded
  states:
    "off":
      type: picture-entity
      entity: camera.a1_camera
      grid_options:
        columns: 4
        rows: 3
    "on":
      type: picture-entity
      entity: camera.a1_camera
      grid_options:
        columns: full
        rows: 12
```

---

### Option 2: `custom:button-card` ✅ **Already Installed**

**Status**: Installed (`/home/pi/homeassistant/www/community/button-card`)

**Benefits**:
- Already available (no installation needed)
- Can create interactive button with expand/collapse
- Supports custom styling

**Example**: See `dashboard-a1-camera-custom-card-example.yaml` (Example 2)

**Configuration**:
```yaml
- type: custom:button-card
  entity: input_boolean.camera_a1_expanded
  tap_action:
    action: toggle
  state:
    - value: "off"
      card:
        type: picture-entity
        entity: camera.a1_camera
    - value: "on"
      card:
        type: picture-entity
        entity: camera.a1_camera
```

---

### Option 3: `custom:layout-card` ✅ **Already Installed**

**Status**: Installed (`/home/pi/homeassistant/www/community/lovelace-layout-card`)

**Benefits**:
- Already available
- Advanced grid layout control
- Can create responsive layouts

**Example**: See `dashboard-a1-camera-custom-card-example.yaml` (Example 3)

---

### Option 4: `card-mod` ✅ **Already Installed**

**Status**: Installed (`/home/pi/homeassistant/www/community/lovelace-card-mod`)

**Benefits**:
- Already available
- Adds styling to existing cards
- Can add animations and transitions
- Works with current conditional setup

**Example**: See `dashboard-a1-camera-custom-card-example.yaml` (Example 4)

**Configuration**:
```yaml
- type: picture-entity
  entity: camera.a1_camera
  card_mod:
    style: |
      ha-card {
        border-radius: 12px;
        transition: all 0.3s ease;
      }
```

---

## Comparison

| Option | Installed | Complexity | Performance | Maintenance |
|--------|-----------|------------|-------------|-------------|
| **Current (Conditional)** | ✅ | Low | Good | Easy |
| **state-switch** | ❌ | Low | Best | Easiest |
| **button-card** | ✅ | Medium | Good | Medium |
| **layout-card** | ✅ | High | Good | Medium |
| **card-mod** | ✅ | Low | Good | Easy |

## Recommendation

**For new implementation**: Use `custom:state-switch` (Option 1)
- Cleanest solution
- Single card instead of two
- Best performance
- Requires HACS installation

**For quick enhancement**: Use `card-mod` (Option 4)
- Already installed
- Works with current setup
- Adds styling/animations
- No structural changes needed

## Testing

All examples are in:
- **Example file**: `/home/pi/_playground/home-assistant/dashboard-a1-camera-custom-card-example.yaml`
- **Documentation**: This file

To test:
1. Install `state-switch` if using Option 1
2. Copy the desired example section to your dashboard
3. Adjust entity IDs and grid options as needed
4. Refresh Home Assistant

## Notes

- The current working setup uses conditional cards (simple and reliable)
- Custom cards offer more features but may require installation
- All examples maintain the same toggle functionality
- Grid options can be adjusted for different sizes

