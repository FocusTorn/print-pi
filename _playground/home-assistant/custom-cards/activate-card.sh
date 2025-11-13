#!/bin/bash

# activate-card.sh - Activate a custom card in Home Assistant
# Usage: ./activate-card.sh <card-name>
# Example: ./activate-card.sh example-card

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PLAYGROUND_CARDS_DIR="/home/pi/_playground/home-assistant/custom-cards"
HA_WWW_DIR="/home/pi/homeassistant/www/community"

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if card name provided
if [ -z "$1" ]; then
    print_error "No card name provided!"
    echo "Usage: $0 <card-name>"
    echo "Example: $0 example-card"
    exit 1
fi

CARD_NAME="$1"
CARD_SOURCE="${PLAYGROUND_CARDS_DIR}/${CARD_NAME}"
CARD_TARGET="${HA_WWW_DIR}/${CARD_NAME}"

# Check if card source exists
if [ ! -d "$CARD_SOURCE" ]; then
    print_error "Card directory not found: ${CARD_SOURCE}"
    echo "Available cards:"
    ls -1 "$PLAYGROUND_CARDS_DIR" 2>/dev/null | sed 's/^/  - /' || echo "  (no cards found)"
    exit 1
fi

# Check if card JavaScript file exists
CARD_JS="${CARD_SOURCE}/${CARD_NAME}.js"
if [ ! -f "$CARD_JS" ]; then
    print_warning "Card JavaScript file not found: ${CARD_JS}"
    print_info "Looking for .js files in card directory..."
    JS_FILES=$(find "$CARD_SOURCE" -maxdepth 1 -name "*.js" | head -1)
    if [ -z "$JS_FILES" ]; then
        print_error "No JavaScript files found in card directory!"
        exit 1
    fi
    print_info "Found: $(basename "$JS_FILES")"
    CARD_JS="$JS_FILES"
fi

# Ensure HA www directory exists
if [ ! -d "$HA_WWW_DIR" ]; then
    print_info "Creating HA www directory: ${HA_WWW_DIR}"
    mkdir -p "$HA_WWW_DIR"
fi

# Check if target already exists
if [ -e "$CARD_TARGET" ]; then
    if [ -L "$CARD_TARGET" ]; then
        CURRENT_TARGET=$(readlink "$CARD_TARGET")
        if [ "$CURRENT_TARGET" = "$CARD_SOURCE" ]; then
            print_success "Card is already activated!"
            echo "  Source: ${CARD_SOURCE}"
            echo "  Target: ${CARD_TARGET}"
            exit 0
        else
            print_warning "Symlink exists but points to different location:"
            echo "  Current: ${CURRENT_TARGET}"
            echo "  Expected: ${CARD_SOURCE}"
            read -p "Replace existing symlink? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_error "Activation cancelled"
                exit 0
            fi
            rm "$CARD_TARGET"
        fi
    else
        print_error "Target exists but is not a symlink: ${CARD_TARGET}"
        print_warning "This might be a HACS-installed card. Remove it manually if you want to replace it."
        exit 1
    fi
fi

# Create symlink
print_info "Activating card: ${CARD_NAME}"
echo "  Source: ${CARD_SOURCE}"
echo "  Target: ${CARD_TARGET}"

if ln -s "$CARD_SOURCE" "$CARD_TARGET"; then
    print_success "Card activated successfully!"
    echo
    print_info "Next steps:"
    echo "  1. Reload the frontend in Home Assistant"
    echo "     (Settings → Developer Tools → Reload Frontend)"
    echo "  2. Or restart Home Assistant: ha restart"
    echo "  3. Add the card to your dashboard using type: custom:${CARD_NAME}"
else
    print_error "Failed to create symlink!"
    exit 1
fi

