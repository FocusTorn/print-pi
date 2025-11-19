#!/bin/bash
# Fast compilation script for ESP32-S3 projects
# Uses parallel compilation with all available CPU cores

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKETCH_DIR="${1:-.}"

# Get number of CPU cores
JOBS=$(nproc)

echo "🔨 Compiling with $JOBS parallel jobs..."
cd "$SCRIPT_DIR/$SKETCH_DIR" || cd "$SKETCH_DIR" || exit 1

arduino-cli compile -j "$JOBS" .
