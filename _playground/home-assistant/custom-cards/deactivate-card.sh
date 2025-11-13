#!/bin/bash

# deactivate-card.sh - Deactivate a custom card in Home Assistant
# Usage: ./deactivate-card.sh <card-name>
# Example: ./deactivate-card.sh example-card

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
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
CARD_TARGET="${HA_WWW_DIR}/${CARD_NAME}"

# Check if card is activated
if [ ! -e "$CARD_TARGET" ]; then
    print_warning "Card is not activated: ${CARD_NAME}"
    exit 0
fi

if [ ! -L "$CARD_TARGET" ]; then
    print_error "Target exists but is not a symlink: ${CARD_TARGET}"
    print_warning "This might be a HACS-installed card. Remove it manually if needed."
    exit 1
fi

# Remove symlink
print_info "Deactivating card: ${CARD_NAME}"
echo "  Target: ${CARD_TARGET}"

if rm "$CARD_TARGET"; then
    print_success "Card deactivated successfully!"
    echo
    print_info "Next steps:"
    echo "  1. Reload the frontend in Home Assistant"
    echo "     (Settings → Developer Tools → Reload Frontend)"
    echo "  2. Or restart Home Assistant: ha restart"
else
    print_error "Failed to remove symlink!"
    exit 1
fi

