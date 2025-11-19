#!/bin/bash
# Auto-detect ESP32-S3 board port
# Usage: esp32-detect-port.sh

BOARD_LIST=$(arduino-cli board list 2>/dev/null | grep -E "ttyUSB|ttyACM" || true)

if [[ -z "$BOARD_LIST" ]]; then
    echo "No boards found" >&2
    exit 1
fi

# Extract first port
PORT=$(echo "$BOARD_LIST" | head -1 | awk '{print $1}')

if [[ -z "$PORT" ]]; then
    echo "Could not detect board port" >&2
    exit 1
fi

echo "$PORT"

