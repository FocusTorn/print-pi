#!/usr/bin/env bash
# Quick script to check ESP32-S3 connection status

echo "=== ESP32-S3 Connection Check ==="
echo ""

echo "1. USB Devices:"
lsusb | grep -v "Linux Foundation" || echo "   No USB devices found (connect your ESP32-S3)"
echo ""

echo "2. Serial Ports:"
ls -la /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || echo "   No serial ports found"
echo ""

echo "3. Arduino CLI Board Detection:"
arduino-cli board list
echo ""

echo "4. Available ESP32-S3 Boards (definitions):"
arduino-cli board listall | grep -i "esp32.*s3.*dev" | head -3
echo ""

echo "5. Recent USB Events:"
dmesg | tail -5 | grep -i "usb\|tty" || echo "   No recent USB events"


