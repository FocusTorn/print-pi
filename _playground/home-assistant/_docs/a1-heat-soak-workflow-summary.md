# Bambu Lab A1 Print Start Workflow with Heat Soak

Complete workflow for coordinating print start with BME680 heat soak monitoring.

## Overview

This workflow replicates the Klipper `HEAT_SOAK` macro functionality for Bambu Lab A1 printers using Home Assistant automation.

### Workflow Steps

1. **Start print from slicer**
2. **Heat bed** to desired temperature
3. **Heat nozzle** to pre-probe temp (150°C)
4. **Start heat soak monitoring** (BME680 sensor)
5. **Wait for heat soak** - Either:
   - Chamber temp ≥ target_temp (default: 50°C), OR
   - Chamber temp ≥ soak_temp (default: 40°C) AND rate ≤ max_rate (default: 0.1°C/min)
6. **Run pre-print checks**
7. **Finish heating nozzle** to final print temperature (only after heat soak completes)
8. **Begin print** when bed, nozzle, and heat soak are all ready

## Files Created

### 1. Sensors (`sensors-bme680-heatsoak.yaml`)
- `sensor.bme680_chamber_temperature` - Current chamber temp
- `sensor.bme680_chamber_smoothed_temp` - Smoothed chamber temp
- `sensor.bme680_chamber_rate` - Rate of change (°C/min)
- `binary_sensor.bme680_heat_soak_ready` - Ready status

### 2. Script (`scripts/a1-print-start-heatsoak-workflow.yaml`)
- Orchestrates the entire workflow
- Parameters:
  - `bed_temp`: Target bed temperature
  - `nozzle_temp`: Final nozzle temperature
  - `nozzle_preheat_temp`: Pre-probe temp (default: 150°C)
  - `soak_temp`: Minimum chamber temp to start checking rate (default: 40°C)
  - `target_temp`: Target chamber temp - if reached, automatically ready (default: 50°C)
  - `max_rate`: Max rate of change (default: 0.1°C/min)

### 3. Automation (`automations/a1-heat-soak-monitor.yaml`)
- Monitors heat soak status during print start
- Logs progress and sends notifications

### 4. Documentation (`_docs/a1-print-start-heatsoak-workflow.md`)
- Complete guide for slicer gcode integration
- Multiple methods for triggering workflow

## Setup Instructions

### Step 1: Add Sensors to Home Assistant

Add to your `configuration.yaml` or packages:

```yaml
sensor: !include sensors-bme680-heatsoak.yaml
```

Or add to your packages directory and include it.

### Step 2: Add Script

Copy `scripts/a1-print-start-heatsoak-workflow.yaml` to your Home Assistant scripts directory or add to your configuration.

### Step 3: Add Automation

Copy `automations/a1-heat-soak-monitor.yaml` to your automations directory.

### Step 4: Restart Home Assistant

```bash
ha restart
```

### Step 5: Verify Sensors

Check that sensors are available:
- `sensor.bme680_chamber_temperature`
- `sensor.bme680_chamber_smoothed_temp`
- `sensor.bme680_chamber_rate`
- `binary_sensor.bme680_heat_soak_ready`

## Usage

### Method 1: Manual Trigger (Recommended for Testing)

1. Go to Home Assistant → Services
2. Select `script.a1_print_start_heatsoak_workflow`
3. Set parameters:
   - `bed_temp`: 60
   - `nozzle_temp`: 220
   - `nozzle_preheat_temp`: 150 (default)
   - `soak_temp`: 40 (default) - Minimum temp to start checking rate
   - `target_temp`: 50 (default) - If reached, automatically ready
   - `max_rate`: 0.1 (default) - Max rate of change
4. Execute script
5. Wait for "All systems ready" notification
6. Start print from slicer

### Method 2: Slicer Integration

See `_docs/a1-print-start-heatsoak-workflow.md` for detailed slicer gcode instructions.

## Workflow Details

### Phase 1: Initial Heating
- Bed heats to target temperature
- Nozzle heats to pre-probe temp (150°C)
- Timeout: 30 minutes

### Phase 2: Heat Soak Monitoring
- Waits for chamber temperature to stabilize
- **Two conditions (either one makes it ready):**
  1. **Target temp reached**: Chamber temp ≥ target_temp (default: 50°C) → automatically ready
  2. **Rate-based**: Chamber temp ≥ soak_temp (default: 40°C) AND rate ≤ max_rate (default: 0.1°C/min)
- Timeout: 15 minutes

### Phase 3: Pre-Print Checks
- Placeholder for your custom checks
- Add checks for:
  - Filament loaded
  - Bed leveling
  - Other conditions

### Phase 4: Final Heating (After Heat Soak)
- **Only starts AFTER heat soak completes**
- Nozzle heats to final print temperature
- Waits for nozzle to reach target temp
- Timeout: 10 minutes

### Phase 5: Ready
- All systems ready notification
- Print can begin

## Monitoring

### Home Assistant Logbook
The script logs progress at each phase:
- "Pre-heat complete. Starting heat soak monitoring..."
- "Heat soak ready. Running pre-print checks..."
- "Heating nozzle to print temperature: X°C"
- "All systems ready!"

### Notifications
- Persistent notification when heat soak is ready
- Final notification when all systems are ready

## Troubleshooting

### Script Times Out
- Check BME680 sensor is publishing correctly
- Verify sensor entities exist in Home Assistant
- Check Home Assistant logs for errors
- Increase timeout values if needed

### Heat Soak Never Ready
- Verify `sensor.bme680_chamber_rate` is updating
- Check that `smoothed_readings` ≥ 30 (needs 30 seconds of data)
- Verify chamber temperature is reaching soak_temp
- Adjust `soak_temp` or `max_rate` if needed

### Temperatures Not Reached
- Verify Bambu Lab integration is working
- Check `number.a1_bed_target` and `number.a1_nozzle_target` entities
- Verify printer is powered on and connected

### Script Doesn't Trigger
- Check Home Assistant logs: `ha logs`
- Verify script YAML syntax is correct
- Check that all required entities exist

## Customization

### Adjust Timeouts
Edit timeouts in `scripts/a1-print-start-heatsoak-workflow.yaml`:
- Initial heating: `timeout: "00:30:00"`
- Heat soak: `timeout: "00:15:00"`
- Final heating: `timeout: "00:10:00"`

### Add Pre-Print Checks
Add checks in Step 5 of the script:
```yaml
- condition: state
  entity_id: sensor.a1_filament_status
  state: "loaded"
```

### Adjust Temperature Tolerances
Change the ±2°C and ±5°C tolerances in wait templates:
```yaml
(states('sensor.a1_bed_temperature') | float >= bed_temp - 2)
```

## Integration with Existing Workflows

This workflow can be integrated with:
- Home Assistant automations
- Node-RED flows
- Other Home Assistant scripts
- MQTT-based systems

## Future Enhancements

- Automatic trigger when print starts
- MQTT integration for slicer communication
- Custom Bambu Lab integration
- Webhook support for remote triggering
- Dashboard cards for workflow status

## Related Files

- `/home/pi/_playground/home-assistant/sensors-bme680-heatsoak.yaml`
- `/home/pi/_playground/home-assistant/scripts/a1-print-start-heatsoak-workflow.yaml`
- `/home/pi/_playground/home-assistant/automations/a1-heat-soak-monitor.yaml`
- `/home/pi/_playground/home-assistant/_docs/a1-print-start-heatsoak-workflow.md`

