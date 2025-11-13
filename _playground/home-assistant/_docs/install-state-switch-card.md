# Installing State Switch Card for Expandable Camera

The camera card now uses `custom:state-switch` which provides a cleaner, single-card solution for expandable views.

## Installation via HACS

1. **Open HACS** in Home Assistant
2. **Go to Frontend** → **Lovelace Cards**
3. **Click "Explore & Download Repositories"** (bottom right)
4. **Search for**: `state-switch`
5. **Select**: `State Switch` by `thomasloven`
6. **Click "Download"**
7. **Restart Home Assistant**

## Alternative: Manual Installation

If HACS isn't available:

```bash
cd /home/pi/homeassistant/www/community
git clone https://github.com/thomasloven/lovelace-state-switch.git state-switch
```

Then restart Home Assistant.

## How It Works

The `state-switch` card replaces the two conditional cards with a single card that:
- Switches between small (4×3) and large (full×12) views
- Based on `input_boolean.camera_a1_expanded` state
- Maintains the same tap-to-toggle functionality
- Provides cleaner YAML configuration

## Benefits

- ✅ Single card instead of two conditionals
- ✅ Cleaner configuration
- ✅ Better performance (one card instead of two)
- ✅ Easier to maintain

