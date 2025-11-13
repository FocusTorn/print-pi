#!/bin/bash

# list-cards.sh - List all custom cards and their activation status
# Usage: ./list-cards.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PLAYGROUND_CARDS_DIR="/home/pi/_playground/home-assistant/custom-cards"
HA_WWW_DIR="/home/pi/homeassistant/www/community"

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo -e "${CYAN}Custom Cards Status${NC}"
echo "===================="
echo

# List cards in playground
echo -e "${CYAN}Available Cards (in _playground):${NC}"
if [ ! -d "$PLAYGROUND_CARDS_DIR" ] || [ -z "$(ls -A "$PLAYGROUND_CARDS_DIR" 2>/dev/null)" ]; then
    echo "  (no cards found)"
else
    for card_dir in "$PLAYGROUND_CARDS_DIR"/*; do
        if [ -d "$card_dir" ]; then
            CARD_NAME=$(basename "$card_dir")
            CARD_TARGET="${HA_WWW_DIR}/${CARD_NAME}"
            
            # Check if activated
            if [ -L "$CARD_TARGET" ]; then
                STATUS="${GREEN}ACTIVATED${NC}"
                TARGET=$(readlink "$CARD_TARGET")
                if [ "$TARGET" = "$card_dir" ]; then
                    LINK_STATUS="(correct)"
                else
                    LINK_STATUS="(points to: $TARGET)"
                fi
            elif [ -e "$CARD_TARGET" ]; then
                STATUS="${YELLOW}EXISTS (not symlink)${NC}"
                LINK_STATUS="(might be HACS card)"
            else
                STATUS="${BLUE}INACTIVE${NC}"
                LINK_STATUS=""
            fi
            
            # Check for JavaScript file
            JS_FILE="${card_dir}/${CARD_NAME}.js"
            if [ ! -f "$JS_FILE" ]; then
                JS_FILES=$(find "$card_dir" -maxdepth 1 -name "*.js" | head -1)
                if [ -n "$JS_FILES" ]; then
                    JS_FILE=$(basename "$JS_FILES")
                else
                    JS_FILE="(no .js file found)"
                fi
            else
                JS_FILE="${CARD_NAME}.js"
            fi
            
            echo "  ${CARD_NAME}"
            echo "    Status: ${STATUS} ${LINK_STATUS}"
            echo "    JS File: ${JS_FILE}"
            echo
        fi
    done
fi

echo
echo -e "${CYAN}Activated Cards (in HA www):${NC}"
if [ ! -d "$HA_WWW_DIR" ] || [ -z "$(ls -A "$HA_WWW_DIR" 2>/dev/null)" ]; then
    echo "  (no activated cards)"
else
    for card_link in "$HA_WWW_DIR"/*; do
        if [ -L "$card_link" ]; then
            CARD_NAME=$(basename "$card_link")
            TARGET=$(readlink "$card_link")
            echo "  ${CARD_NAME}"
            echo "    → ${TARGET}"
            echo
        fi
    done
fi

echo
echo -e "${CYAN}Quick Commands:${NC}"
echo "  ./activate-card.sh <card-name>    - Activate a card"
echo "  ./deactivate-card.sh <card-name>  - Deactivate a card"
echo "  ./list-cards.sh                   - List all cards (this command)"

