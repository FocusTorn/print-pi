# Bambu Lab A1 Dashboard Guide

Complete guide to creating a beautiful dashboard for your Bambu Lab A1 3D printer in Home Assistant.

## Quick Start

### Method 1: Using the Web UI (Recommended for Beginners)

**Step 1: Open Home Assistant**
- Go to http://192.168.1.159:8123 in your browser
- Log in if needed

**Step 2: Edit Your Dashboard**
- On the **Overview** page, click the **three dots (⋮)** in the top-right corner
- Select **Edit Dashboard**
- Click **Done** if a popup asks to take control (this enables editing)

**Step 3: Add Your First Card**
- Scroll to the bottom and click **Add Card**
- You'll see various card types:
  - **Entities** - Display multiple sensors/controls in a list
  - **Gauge** - Show temperature or progress as a gauge
  - **History Graph** - Show trends over time
  - **Bambu Lab** - Custom printer card (if available)

**Step 4: Add Entities to Card**
- When you select a card type, you'll see a "Choose entity" button
- Click it and start typing "bambu" or "A1"
- Select the entities you want to display
- Click **Save**

**Common First Cards:**
1. **Entities Card** → Add printer status, bed temp, nozzle temp
2. **Gauge Card** → Show print progress %
3. **Entities Card** → Add control buttons (pause, resume, cancel)

**Done!** Your A1 printer information is now on your dashboard.

### Option 2: Using YAML (Advanced Control)

Create a YAML file for full customization:

```yaml
# Save as: a1-dashboard.yaml or add to your Lovelace config
views:
  - title: A1 Printer
    path: a1-dashboard
    icon: mdi:printer-3d
    cards:
      # Full Printer Status Card (Custom Bambu Card)
      - type: custom:bambu-lab-card
        entity: sensor.a1_status
        show_name: true
        show_icon: true
        
      # Print Progress
      - type: gauge
        entity: sensor.a1_print_progress
        name: Print Progress
        severity:
          green: 0
          yellow: 30
          red: 70
        min: 0
        max: 100
        
      # Bed Temperature
      - type: gauge
        entity: sensor.a1_bed_temperature
        name: Bed Temp
        severity:
          green: 0
          yellow: 50
          red: 80
        min: 0
        max: 120
        
      # Nozzle Temperature
      - type: gauge
        entity: sensor.a1_nozzle_temperature
        name: Nozzle Temp
        severity:
          green: 0
          yellow: 200
          red: 250
        min: 0
        max: 300
        
      # Main Control
      - type: entities
        title: Printer Control
        entities:
          - switch.a1_printing
          - button.a1_pause
          - button.a1_resume
          - button.a1_cancel
          
      # Current Print Info
      - type: entities
        title: Current Print
        entities:
          - sensor.a1_current_file
          - sensor.a1_print_time
          - sensor.a1_remaining_time
          - sensor.a1_layer_info
          
      # Sensors Overview
      - type: entities
        title: Printer Status
        entities:
          - sensor.a1_filament_used
          - sensor.a1_chamber_temperature
          - sensor.a1_nozzle_temperature_current
          - sensor.a1_bed_temperature_current
          
      # Graph Card for Temperature History
      - type: history-graph
        hours: 24
        refresh_interval: 60
        entities:
          - sensor.a1_nozzle_temperature
          - sensor.a1_bed_temperature
          - sensor.a1_chamber_temperature
```

## Common A1 Entities

Based on the Bambu Lab integration, here are typical entity patterns:

### Sensors
- `sensor.a1_status` - Overall printer status
- `sensor.a1_print_progress` - Print completion %
- `sensor.a1_bed_temperature` - Bed temperature (°C)
- `sensor.a1_nozzle_temperature` - Nozzle temperature (°C)
- `sensor.a1_chamber_temperature` - Chamber temperature (°C)
- `sensor.a1_current_file` - Currently printing file
- `sensor.a1_print_time` - Elapsed print time
- `sensor.a1_remaining_time` - Estimated time remaining
- `sensor.a1_layer_info` - Current layer info
- `sensor.a1_filament_used` - Filament usage

### Controls (Switches/Buttons)
- `switch.a1_printing` - Print on/off
- `button.a1_pause` - Pause print
- `button.a1_resume` - Resume print
- `button.a1_cancel` - Cancel print
- `button.a1_start_print` - Start new print

**⚠️ Important:** Replace `a1` in these examples with your actual device ID/name from the integration. The exact entity names will depend on:
- How the integration configured your printer
- Whether you gave it a custom name during setup
- The serial number or other identifier used

## Finding Your Entity Names

To find the exact entity names for your printer:

1. **Via Web UI:**
   - Settings → Devices & Services → Bambu Lab
   - Click on your A1 device
   - View all entities

2. **Via CLI:**
```bash
ha entities | grep -i bambu
# or
ha states | grep -i bambu
```

3. **Developer Tools:**
   - Settings → Developer Tools → States
   - Search for "bambu" or "a1"

## Using Bambu Lab Custom Cards

You have the Bambu Lab cards installed (version 0.6.19). These provide:

### Custom Card Types
- **bambu-lab-card** - Comprehensive printer overview card
- **bambu-printer-card** - Detailed printer status card
- **bambu-vacuum-card** - Vacuum bed monitoring

### Example Custom Card Usage
```yaml
type: custom:bambu-lab-card
entity: sensor.a1_status
show_camera: true
show_bed_temp: true
show_nozzle_temp: true
```

## Creating the Dashboard

### Method 1: Add to Existing Overview

1. Go to **Overview**
2. Click **three dots (⋮)** → **Edit Dashboard**
3. Scroll to bottom
4. Click **Add Card**
5. Choose card type and configure

### Method 2: Create New Dashboard

1. Go to **Settings** → **Dashboards**
2. Click **Add Dashboard** → **New Dashboard**
3. Name it "A1 Printer" (or similar)
4. Choose icon: `mdi:printer-3d`
5. Click **Create**
6. In new dashboard: **Edit Dashboard** → **Add Card**

### Method 3: YAML Mode (Advanced)

1. Go to **Overview** → **three dots (⋮)** → **Edit Dashboard**
2. Click **three dots (⋮)** again → **Raw config editor**
3. Paste your YAML configuration
4. Click **Save**

## Dashboard Layout Suggestions

### Compact Single View
Perfect for mobile or small screens:

```yaml
cards:
  - type: custom:bambu-lab-card
    entity: sensor.a1_status
  - type: gauge
    entity: sensor.a1_print_progress
    name: Progress
  - type: entities
    entities:
      - sensor.a1_bed_temperature
      - sensor.a1_nozzle_temperature
```

### Multi-View Dashboard
Organize by function:

```yaml
views:
  - title: Status
    path: a1-status
    cards:
      # Status overview cards
      
  - title: Control
    path: a1-control
    cards:
      # Control buttons and switches
      
  - title: History
    path: a1-history
    cards:
      # Graphs and historical data
```

## Troubleshooting

### Entities Not Showing

**Problem:** Can't find A1 entities in card editor

**Solutions:**
1. Verify integration is configured:
   ```bash
   ha entities | grep -i bambu
   ```
2. Restart Home Assistant:
   ```bash
   ha restart
   ```
3. Check integration status:
   - Settings → Devices & Services → Bambu Lab

### Custom Cards Not Available

**Problem:** Can't find "Bambu Lab" card in card picker

**Solutions:**
1. Verify cards are loaded:
   ```bash
   python3 -c "import json; print(json.load(open('/home/pi/homeassistant/.storage/lovelace_resources')))"
   ```
2. Clear browser cache (Ctrl+Shift+R)
3. Reinstall if needed via HACS

### Printer Not Connecting

**Problem:** Integration shows offline or not connected

**Solutions:**
1. Check LAN Mode is enabled on printer:
   - Bambu Studio → Device → Network → Enable LAN-Only Mode
2. Verify IP address in integration settings
3. Check network connectivity:
   ```bash
   ping <printer-ip>
   ```

## Resources

- **Integration GitHub:** https://github.com/greghesp/ha-bambulab
- **Cards GitHub:** https://github.com/m0r13/ha-bambulab-cards
- **Official Docs:** https://wiki.bambulab.com/
- **Home Assistant Forum:** https://community.home-assistant.io/

## Quick Commands

```bash
# Restart HA after changes
ha restart

# Check A1 entities
ha entities | grep -i bambu

# View HA logs
ha logs-tail 50

# Backup current config
ha backup "a1-dashboard-$(date +%Y%m%d)"

# List all integrations
ha integrations
```

---

**Last Updated:** November 2025  
**Integration:** Bambu Lab HA Integration  
**Cards Version:** 0.6.19  
**HA Version:** Latest

