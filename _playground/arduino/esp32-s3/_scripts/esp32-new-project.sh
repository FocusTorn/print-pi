#!/bin/bash
# Create new ESP32-S3 project with proper structure
# Usage: esp32-new-project.sh <project_name>

set -e

if [[ $# -eq 0 ]]; then
    echo "Usage: esp32-new-project.sh <project_name>"
    exit 1
fi

PROJECT_NAME="$1"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$BASE_DIR/$PROJECT_NAME"

if [[ -d "$PROJECT_DIR" ]]; then
    echo "Error: Project directory already exists: $PROJECT_DIR" >&2
    exit 1
fi

echo "Creating ESP32-S3 project: $PROJECT_NAME"
mkdir -p "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/.vscode"

# Create main sketch file
cat > "$PROJECT_DIR/$PROJECT_NAME.ino" << 'SKETCH_EOF'
/*
  Project Name
  Description of your project
*/

void setup() {
  // Initialize serial communication
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("ESP32-S3 Project Started!");
}

void loop() {
  // Your code here
  delay(1000);
}
SKETCH_EOF

# Create sketch.yaml with defaults
cat > "$PROJECT_DIR/sketch.yaml" << YAML_EOF
default_fqbn: esp32:esp32:esp32s3
default_port: /dev/ttyUSB0
YAML_EOF

# Create .vscode/settings.json
cat > "$PROJECT_DIR/.vscode/settings.json" << JSON_EOF
{
  "arduino.path": "/home/pi/.local/bin/arduino-cli",
  "arduino.additionalUrls": [
    "https://dl.espressif.com/dl/package_esp32_index.json"
  ],
  "arduino.defaultBaudRate": 115200,
  "arduino.logLevel": "info",
  "arduino.board": "esp32:esp32:esp32s3",
  "arduino.port": "/dev/ttyUSB0"
}
JSON_EOF

# Create README.md
cat > "$PROJECT_DIR/README.md" << README_EOF
# $PROJECT_NAME

ESP32-S3 project description.

## Quick Start

\`\`\`bash
# Build and upload
make all

# Or use the helper script
$BASE_DIR/_scripts/esp32-build.sh . --monitor
\`\`\`

## Configuration

- FQBN: \`esp32:esp32:esp32s3\`
- Port: Auto-detected (or set in sketch.yaml)
- Baud Rate: 115200
README_EOF

# Create Makefile
cat > "$PROJECT_DIR/Makefile" << MAKEFILE_EOF
# Makefile for $PROJECT_NAME
# ESP32-S3 Arduino Project

PORT ?= \$(shell $BASE_DIR/_scripts/esp32-detect-port.sh 2>/dev/null || echo /dev/ttyUSB0)
FQBN ?= esp32:esp32:esp32s3
SKETCH ?= .
JOBS ?= \$(shell nproc)
BAUDRATE ?= 115200

.DEFAULT_GOAL := help

.PHONY: help build upload monitor clean all list-boards

help:
	@echo "$PROJECT_NAME - ESP32-S3 Arduino Project"
	@echo ""
	@echo "Commands:"
	@echo "  make build        - Compile the sketch"
	@echo "  make upload       - Compile and upload to board"
	@echo "  make monitor      - Open serial monitor"
	@echo "  make all          - Upload and monitor"
	@echo "  make clean        - Clean build cache"
	@echo "  make list-boards  - List connected boards"
	@echo ""
	@echo "Configuration:"
	@echo "  PORT=\$(PORT)"
	@echo "  FQBN=\$(FQBN)"

build:
	@echo "🔨 Compiling..."
	arduino-cli compile -j \$(JOBS) --fqbn \$(FQBN) \$(SKETCH)

upload: build
	@echo "📤 Uploading to \$(PORT)..."
	arduino-cli upload -p \$(PORT) --fqbn \$(FQBN) \$(SKETCH)

monitor:
	@echo "📡 Opening serial monitor on \$(PORT) at \$(BAUDRATE) baud..."
	arduino-cli monitor -p \$(PORT) --config baudrate=\$(BAUDRATE)

all: upload monitor

clean:
	@echo "🧹 Cleaning build cache..."
	arduino-cli cache clean

list-boards:
	@echo "🔌 Connected boards:"
	arduino-cli board list
MAKEFILE_EOF

echo "✅ Project created: $PROJECT_DIR"
echo ""
echo "Next steps:"
echo "  cd $PROJECT_DIR"
echo "  make all"

