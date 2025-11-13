#!/bin/bash
# Wrapper script for bme680-base-readings.py
# Reads config from YAML and passes heatsoak parameters

CONFIG_FILE="/home/pi/.config/bme680-monitor/config.yaml"

# Default values
READ_INTERVAL=1
PUBLISH_INTERVAL=30
TEMP_OFFSET=-4.0
TEMP_SMOOTH=4.0
RATE_START_TYPE="absolute"
RATE_START_TEMP=40.0
RATE_CHANGE_PLATEAU=0.1
TARGET_TEMP=""
RATE_SMOOTH_TIME=30.0

# Try to read from config file
if [ -f "$CONFIG_FILE" ]; then
    READ_INTERVAL=$(python3 -c "import yaml; f=open('$CONFIG_FILE', 'r'); d=yaml.safe_load(f); f.close(); print(d.get('mqtt', {}).get('read_interval', 1))" 2>/dev/null || echo "1")
    PUBLISH_INTERVAL=$(python3 -c "import yaml; f=open('$CONFIG_FILE', 'r'); d=yaml.safe_load(f); f.close(); print(d.get('mqtt', {}).get('publish_interval', 30))" 2>/dev/null || echo "30")
    TEMP_OFFSET=$(python3 -c "import yaml; f=open('$CONFIG_FILE', 'r'); d=yaml.safe_load(f); f.close(); print(d.get('mqtt', {}).get('temp_offset', -4.0))" 2>/dev/null || echo "-4.0")
    TEMP_SMOOTH=$(python3 -c "import yaml; f=open('$CONFIG_FILE', 'r'); d=yaml.safe_load(f); f.close(); print(d.get('mqtt', {}).get('temp_smooth', 4.0))" 2>/dev/null || echo "4.0")
    RATE_START_TYPE=$(python3 -c "import yaml; f=open('$CONFIG_FILE', 'r'); d=yaml.safe_load(f); f.close(); print(d.get('mqtt', {}).get('heatsoak', {}).get('rate_start_type', 'absolute'))" 2>/dev/null || echo "absolute")
    RATE_START_TEMP=$(python3 -c "import yaml; f=open('$CONFIG_FILE', 'r'); d=yaml.safe_load(f); f.close(); print(d.get('mqtt', {}).get('heatsoak', {}).get('rate_start_temp', 40.0))" 2>/dev/null || echo "40.0")
    RATE_CHANGE_PLATEAU=$(python3 -c "import yaml; f=open('$CONFIG_FILE', 'r'); d=yaml.safe_load(f); f.close(); print(d.get('mqtt', {}).get('heatsoak', {}).get('rate_change_plateau', 0.1))" 2>/dev/null || echo "0.1")
    TARGET_TEMP=$(python3 -c "import yaml; f=open('$CONFIG_FILE', 'r'); d=yaml.safe_load(f); f.close(); t=d.get('mqtt', {}).get('heatsoak', {}).get('target_temp'); print(t if t is not None else '')" 2>/dev/null || echo "")
    RATE_SMOOTH_TIME=$(python3 -c "import yaml; f=open('$CONFIG_FILE', 'r'); d=yaml.safe_load(f); f.close(); print(d.get('mqtt', {}).get('heatsoak', {}).get('rate_smooth_time', 30.0))" 2>/dev/null || echo "30.0")
fi

# Build command arguments
CMD_ARGS="--mqtt-host localhost --topic sensors/bme680/raw --read-interval $READ_INTERVAL --publish-interval $PUBLISH_INTERVAL --temp-offset $TEMP_OFFSET --temp-smooth $TEMP_SMOOTH --rate-start-type $RATE_START_TYPE --rate-start-temp $RATE_START_TEMP --rate-change-plateau $RATE_CHANGE_PLATEAU --rate-smooth $RATE_SMOOTH_TIME"

# Add target_temp if configured
if [ -n "$TARGET_TEMP" ]; then
    CMD_ARGS="$CMD_ARGS --target-temp $TARGET_TEMP"
fi

# Execute the main script with all parameters
exec /home/pi/.local/share/bme680-service/.venv/bin/python -u \
    /home/pi/.local/share/bme680-service/mqtt/base-readings.py \
    $CMD_ARGS

