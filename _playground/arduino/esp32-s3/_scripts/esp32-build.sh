#!/bin/bash
# Unified ESP32-S3 build, upload, and monitor script
# Usage: esp32-build.sh [project_dir] [--monitor] [--port PORT] [--fqbn FQBN]
# 
# This script auto-detects the ESP32-S3 board port if not specified.
# It compiles, uploads, and optionally monitors the serial output.

set -e

# Get script directory for helper scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
DEFAULT_FQBN="esp32:esp32:esp32s3"
DEFAULT_BAUDRATE=115200
JOBS=$(nproc)
MONITOR=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
PROJECT_DIR=""
PORT=""
FQBN="$DEFAULT_FQBN"

while [[ $# -gt 0 ]]; do
    case $1 in
        --monitor|-m)
            MONITOR=true
            shift
            ;;
        --port|-p)
            PORT="$2"
            shift 2
            ;;
        --fqbn|-b)
            FQBN="$2"
            shift 2
            ;;
        --help|-h)
            echo "ESP32-S3 Unified Build Script"
            echo ""
            echo "Usage: esp32-build.sh [project_dir] [options]"
            echo ""
            echo "Options:"
            echo "  --monitor, -m     Open serial monitor after upload"
            echo "  --port, -p PORT   Specify port (e.g., /dev/ttyUSB0)"
            echo "  --fqbn, -b FQBN   Specify FQBN (default: esp32:esp32:esp32s3)"
            echo "  --help, -h         Show this help"
            echo ""
            echo "Examples:"
            echo "  esp32-build.sh Blink_ESP32S3"
            echo "  esp32-build.sh Blink_ESP32S3 --monitor"
            echo "  esp32-build.sh Blink_ESP32S3 --port /dev/ttyUSB1"
            exit 0
            ;;
        *)
            if [[ -z "$PROJECT_DIR" ]]; then
                PROJECT_DIR="$1"
            fi
            shift
            ;;
    esac
done

# If no project dir specified, use current directory
if [[ -z "$PROJECT_DIR" ]]; then
    PROJECT_DIR="."
fi

# Resolve absolute path
if [[ "$PROJECT_DIR" != "." ]]; then
    if [[ ! -d "$PROJECT_DIR" ]]; then
        echo -e "${RED}Error: Project directory not found: $PROJECT_DIR${NC}" >&2
        exit 1
    fi
    PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)
else
    PROJECT_DIR=$(pwd)
fi

# Auto-detect port if not specified
if [[ -z "$PORT" ]]; then
    echo -e "${BLUE}🔍 Auto-detecting ESP32-S3 board...${NC}"
    
    # Use the port detection script
    if PORT_DETECTED=$("$SCRIPT_DIR/esp32-detect-port.sh" 2>/dev/null); then
        PORT="$PORT_DETECTED"
        echo -e "${GREEN}✅ Found board at: $PORT${NC}"
    else
        echo -e "${RED}Error: No boards found. Is your ESP32-S3 connected?${NC}" >&2
        exit 1
    fi
fi

# Check if port exists
if [[ ! -e "$PORT" ]]; then
    echo -e "${RED}Error: Port $PORT does not exist${NC}" >&2
    exit 1
fi

# Check if sketch.yaml exists and use its FQBN if available
if [[ -f "$PROJECT_DIR/sketch.yaml" ]]; then
    SKETCH_FQBN=$(grep "default_fqbn:" "$PROJECT_DIR/sketch.yaml" | awk '{print $2}' || true)
    if [[ -n "$SKETCH_FQBN" ]]; then
        FQBN="$SKETCH_FQBN"
        echo -e "${BLUE}📋 Using FQBN from sketch.yaml: $FQBN${NC}"
    fi
fi

# Compile
echo -e "${BLUE}🔨 Compiling $PROJECT_DIR...${NC}"
if ! arduino-cli compile -j "$JOBS" --fqbn "$FQBN" "$PROJECT_DIR"; then
    echo -e "${RED}❌ Compilation failed${NC}" >&2
    exit 1
fi

# Upload
echo -e "${BLUE}📤 Uploading to $PORT...${NC}"
if ! arduino-cli upload -p "$PORT" --fqbn "$FQBN" "$PROJECT_DIR"; then
    echo -e "${RED}❌ Upload failed${NC}" >&2
    exit 1
fi

echo -e "${GREEN}✅ Upload successful!${NC}"

# Monitor if requested
if [[ "$MONITOR" == "true" ]]; then
    echo -e "${BLUE}📡 Opening serial monitor on $PORT at $DEFAULT_BAUDRATE baud...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
    arduino-cli monitor -p "$PORT" --config baudrate="$DEFAULT_BAUDRATE"
fi
