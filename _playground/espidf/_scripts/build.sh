#!/bin/bash
# ESP-IDF build, flash, and monitor script
# Usage: build.sh [project_dir] [--monitor] [--port PORT] [--target TARGET]

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
DEFAULT_TARGET="esp32s3"
MONITOR=false
PORT=""
TARGET="$DEFAULT_TARGET"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
PROJECT_DIR=""

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
        --target|-t)
            TARGET="$2"
            shift 2
            ;;
        --help|-h)
            echo "ESP-IDF Build Script"
            echo ""
            echo "Usage: build.sh [project_dir] [options]"
            echo ""
            echo "Options:"
            echo "  --monitor, -m        Open serial monitor after flash"
            echo "  --port, -p PORT     Specify port (e.g., /dev/ttyUSB0)"
            echo "  --target, -t TARGET  Specify target (default: esp32s3)"
            echo "  --help, -h           Show this help"
            echo ""
            echo "Examples:"
            echo "  build.sh my_project"
            echo "  build.sh my_project --monitor"
            echo "  build.sh my_project --port /dev/ttyUSB1"
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

# Check if ESP-IDF is activated
if [[ -z "$IDF_PATH" ]]; then
    echo -e "${YELLOW}⚠️  ESP-IDF environment not activated${NC}"
    echo -e "${BLUE}   Run 'get_idf' first, or source ~/esp/esp-idf/export.sh${NC}"
    exit 1
fi

# Auto-detect port if not specified
if [[ -z "$PORT" ]]; then
    echo -e "${BLUE}🔍 Auto-detecting ESP32 board...${NC}"
    
    if PORT_DETECTED=$("$SCRIPT_DIR/detect-port.sh" 2>/dev/null); then
        PORT="$PORT_DETECTED"
        echo -e "${GREEN}✅ Found board at: $PORT${NC}"
    else
        echo -e "${YELLOW}⚠️  No board detected. Using default: /dev/ttyUSB0${NC}"
        PORT="/dev/ttyUSB0"
    fi
fi

# Check if port exists
if [[ ! -e "$PORT" ]]; then
    echo -e "${RED}Error: Port $PORT does not exist${NC}" >&2
    exit 1
fi

# Check if target is set (sdkconfig should exist or set-target should be run)
if [[ ! -f "$PROJECT_DIR/sdkconfig" ]]; then
    echo -e "${BLUE}🎯 Setting target to $TARGET...${NC}"
    cd "$PROJECT_DIR"
    idf.py set-target "$TARGET"
fi

# Build
echo -e "${BLUE}🔨 Building $PROJECT_DIR...${NC}"
cd "$PROJECT_DIR"
if ! idf.py build; then
    echo -e "${RED}❌ Build failed${NC}" >&2
    exit 1
fi

# Flash
echo -e "${BLUE}📤 Flashing to $PORT...${NC}"
if ! idf.py -p "$PORT" flash; then
    echo -e "${RED}❌ Flash failed${NC}" >&2
    exit 1
fi

echo -e "${GREEN}✅ Flash successful!${NC}"

# Monitor if requested
if [[ "$MONITOR" == "true" ]]; then
    echo -e "${BLUE}📡 Opening serial monitor on $PORT...${NC}"
    echo -e "${YELLOW}Press Ctrl+] to exit${NC}"
    idf.py -p "$PORT" monitor
fi


