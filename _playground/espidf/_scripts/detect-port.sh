#!/bin/bash
# Auto-detect ESP32 board port
# Returns the first available ESP32-compatible port

# Common ESP32 USB-to-serial chip VID:PID pairs
# CH340: 1a86:7523, 1a86:5523
# CP2102: 10c4:ea60
# FTDI: 0403:6001, 0403:6015
# ESP32-S3 built-in: 303a:1001

# Check common ports in order
PORTS=(
    "/dev/ttyUSB0"
    "/dev/ttyUSB1"
    "/dev/ttyACM0"
    "/dev/ttyACM1"
)

for port in "${PORTS[@]}"; do
    if [[ -e "$port" ]]; then
        # Check if it's likely an ESP32 by checking USB device info
        if lsusb | grep -qE "(1a86:7523|1a86:5523|10c4:ea60|0403:6001|0403:6015|303a:1001)"; then
            echo "$port"
            exit 0
        fi
        # If we can't determine, return first available port
        echo "$port"
        exit 0
    fi
done

# No port found
exit 1


