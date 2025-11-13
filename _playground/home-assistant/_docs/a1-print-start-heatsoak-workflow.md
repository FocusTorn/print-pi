# Bambu Lab A1 Print Start Workflow - Slicer Gcode Guide
# 
# This document explains how to integrate the Home Assistant print start workflow
# into your slicer's start gcode.
#
# The workflow coordinates:
# 1. Bed heating to target temperature
# 2. Nozzle pre-heating to 150°C (pre-probe temp)
# 3. Heat soak monitoring (waits for chamber temp stabilization)
# 4. Pre-print checks
# 5. Final nozzle heating to print temperature
# 6. Print start when all conditions are met

## Overview

Since Bambu Lab printers don't use Klipper macros, we use Home Assistant to orchestrate
the workflow. The slicer gcode calls Home Assistant services via MQTT or HTTP.

## Method 1: Using Home Assistant Script (Recommended)

### Prerequisites

1. Home Assistant script `a1_print_start_heatsoak_workflow` must be configured
2. MQTT or HTTP API access to Home Assistant
3. BME680 heat soak sensor publishing to MQTT

### Slicer Start Gcode

Add this to your slicer's **Start Gcode** section:

```gcode
; === Bambu Lab A1 Print Start with Heat Soak ===
; This gcode calls Home Assistant to orchestrate the print start workflow

; Call Home Assistant script via MQTT
; Note: Adjust topic and payload based on your HA MQTT configuration
M118 P0 "Calling Home Assistant print start workflow..."

; Set temperatures via Home Assistant (these will be overridden by the script)
; But we set them here as fallback
M140 S{first_layer_bed_temperature[0]} ; Set bed temp
M104 S150 ; Set nozzle to pre-probe temp (150°C)

; Wait for Home Assistant script to complete
; The script will:
; 1. Heat bed to target
; 2. Heat nozzle to 150°C
; 3. Monitor heat soak
; 4. Run pre-print checks
; 5. Heat nozzle to final temp
; 6. Notify when ready

; Note: You may need to add a delay here or use MQTT to check script status
; For now, we'll wait a reasonable time for initial heating
G4 P30000 ; Wait 30 seconds for initial heating

; Continue with normal start sequence
M104 S{first_layer_temperature[0]} ; Set final nozzle temp
M140 S{first_layer_bed_temperature[0]} ; Ensure bed temp is set

; Wait for temperatures (Home Assistant script handles heat soak)
M190 S{first_layer_bed_temperature[0]} ; Wait for bed
M109 S{first_layer_temperature[0]} ; Wait for nozzle

; Home Assistant script should have completed heat soak by now
; Proceed with normal print start
G28 ; Home all axes
G92 E0 ; Reset extruder
G1 Z0.3 F3000 ; Move to layer height
G1 X3 Y3 F5000 ; Move to start position
G1 Z0.2 F3000 ; Move to first layer height
G1 X20 E10 F500 ; Prime line
G92 E0 ; Reset extruder
```

## Method 2: Direct MQTT/HTTP Calls (Advanced)

If you want more control, you can call Home Assistant services directly:

### Via MQTT

```gcode
; Publish to Home Assistant MQTT API
; Topic: homeassistant/services/script/a1_print_start_heatsoak_workflow
; Payload: {"bed_temp": 60, "nozzle_temp": 220, "nozzle_preheat_temp": 150}
```

### Via HTTP API

You'll need to use a custom script or tool that can make HTTP requests from gcode.

## Method 3: Simplified Approach (Current Workflow)

For now, use this simplified approach:

1. **In Slicer Start Gcode:**
   ```gcode
   ; Set initial temperatures
   M140 S{first_layer_bed_temperature[0]} ; Bed temp
   M104 S150 ; Nozzle pre-probe temp (150°C)
   
   ; Wait for initial heating
   M190 S{first_layer_bed_temperature[0]} ; Wait for bed
   M109 S150 ; Wait for nozzle pre-probe temp
   
   ; At this point, manually trigger Home Assistant script OR
   ; Add a delay to allow heat soak monitoring
   G4 P60000 ; Wait 60 seconds for heat soak (adjust as needed)
   
   ; Set final nozzle temperature
   M104 S{first_layer_temperature[0]} ; Final nozzle temp
   M109 S{first_layer_temperature[0]} ; Wait for final nozzle temp
   
   ; Continue with normal start sequence
   G28 ; Home
   ; ... rest of your start gcode
   ```

2. **Manually trigger Home Assistant script** before starting print:
   - Go to Home Assistant
   - Services → Scripts → `a1_print_start_heatsoak_workflow`
   - Set parameters:
     - `bed_temp`: Your bed temperature
     - `nozzle_temp`: Your nozzle temperature
     - `nozzle_preheat_temp`: 150 (default)
     - `soak_temp`: 40 (default)
     - `max_rate`: 0.1 (default)
   - Execute script
   - Wait for notification that all systems are ready
   - Then start print from slicer

## Recommended Workflow

**Best approach for now:**

1. **Configure Home Assistant script** with your typical print temperatures
2. **Before starting print:**
   - Trigger the `a1_print_start_heatsoak_workflow` script in Home Assistant
   - Wait for the "All systems ready" notification
3. **In slicer start gcode:**
   - Use simplified gcode that assumes temperatures are already set
   - Skip temperature setting/waiting commands
   - Just do homing and start printing

## Future Enhancement

A more integrated solution would:
- Use MQTT to communicate between slicer and Home Assistant
- Automatically trigger workflow when print starts
- Use Home Assistant's `button` entities or MQTT commands
- Add a custom Bambu Lab integration that handles this automatically

## Testing

1. Test the Home Assistant script manually first
2. Verify heat soak sensor is working
3. Test with a simple print
4. Adjust timeouts and thresholds as needed

## Troubleshooting

- **Script times out**: Increase timeout values in script
- **Heat soak never ready**: Check BME680 sensor is publishing correctly
- **Temperatures not reached**: Verify Bambu Lab integration is working
- **Script doesn't trigger**: Check Home Assistant logs for errors

