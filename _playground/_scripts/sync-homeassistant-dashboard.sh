#!/bin/bash
# Home Assistant Dashboard Sync Script
# Syncs between YAML source file and JSON dashboard storage
# Supports bidirectional sync: YAML → JSON and JSON → YAML

set -e

# Configuration
YAML_SOURCE="/home/pi/_playground/home-assistant/dashboard-a1-sections.yaml"
JSON_STORAGE="/home/pi/homeassistant/.storage/lovelace.dashboard_printerific"
DASHBOARD_TITLE="A1 3D Printer"
DASHBOARD_PATH="a1-3d-printer"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Home Assistant Dashboard Sync${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo
}

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
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Check if files exist
if [ ! -f "$YAML_SOURCE" ]; then
    print_error "YAML source file not found: $YAML_SOURCE"
    exit 1
fi

if [ ! -f "$JSON_STORAGE" ]; then
    print_error "JSON storage file not found: $JSON_STORAGE"
    exit 1
fi

# Auto-elevate to sudo if not root (for writing to JSON storage)
if [ "$EUID" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

print_header

# Function to convert YAML to JSON (basic structure)
yaml_to_json() {
    local yaml_file="$1"
    local temp_json=$(mktemp)
    
    # Check if PyYAML is available
    if ! python3 -c "import yaml" 2>/dev/null; then
        print_error "PyYAML not installed. Install with: sudo apt install python3-yaml"
        exit 1
    fi
    
    # Use Python to convert YAML to JSON
    python3 << PYTHON_SCRIPT
import yaml
import json
import sys

try:
    with open("$yaml_file", 'r') as f:
        yaml_data = yaml.safe_load(f)
    
    # Wrap in Home Assistant dashboard structure
    dashboard_json = {
        "version": 1,
        "key": "printerific",
        "data": {
            "config": yaml_data,
            "title": "$DASHBOARD_TITLE",
            "url_path": "$DASHBOARD_PATH"
        }
    }
    
    with open("$temp_json", 'w') as f:
        json.dump(dashboard_json, f, indent=2)
    
    print("$temp_json")
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT
}

# Function to extract YAML from JSON
json_to_yaml() {
    local json_file="$1"
    local temp_yaml=$(mktemp)
    
    # Check if PyYAML is available
    if ! python3 -c "import yaml" 2>/dev/null; then
        print_error "PyYAML not installed. Install with: sudo apt install python3-yaml"
        exit 1
    fi
    
    # Use Python to extract YAML from JSON
    python3 << PYTHON_SCRIPT
import yaml
import json
import sys

try:
    with open("$json_file", 'r') as f:
        json_data = json.load(f)
    
    # Extract the views/config from JSON structure
    config = json_data.get('data', {}).get('config', {})
    
    with open("$temp_yaml", 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
    
    print("$temp_yaml")
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT
}

# Function to check if files are in sync
check_sync_status() {
    print_info "Checking sync status..."
    
    # Get modification times
    YAML_MTIME=$(stat -c %Y "$YAML_SOURCE" 2>/dev/null || echo "0")
    JSON_MTIME=$(stat -c %Y "$JSON_STORAGE" 2>/dev/null || echo "0")
    
    if [ "$YAML_MTIME" -gt "$JSON_MTIME" ]; then
        echo "yaml_newer"
    elif [ "$JSON_MTIME" -gt "$YAML_MTIME" ]; then
        echo "json_newer"
    else
        echo "synced"
    fi
}

# Main menu
show_menu() {
    echo "Sync Options:"
    echo "  1) YAML → JSON (push YAML changes to Home Assistant)"
    echo "  2) JSON → YAML (pull UI changes back to YAML)"
    echo "  3) Check sync status"
    echo "  4) Show differences"
    echo "  5) Exit"
    echo
    read -p "Select option [1-5]: " choice
    echo "$choice"
}

# Main logic
SYNC_STATUS=$(check_sync_status)

case "$SYNC_STATUS" in
    yaml_newer)
        print_warning "YAML file is newer than JSON (YAML has changes not in HA)"
        ;;
    json_newer)
        print_warning "JSON file is newer than YAML (UI has changes not in YAML)"
        ;;
    synced)
        print_success "Files appear to be in sync"
        ;;
esac

# Show menu and get choice
CHOICE=$(show_menu)

case "$CHOICE" in
    1)
        print_info "Syncing YAML → JSON (pushing YAML to Home Assistant)..."
        TEMP_JSON=$(yaml_to_json "$YAML_SOURCE")
        
        # Backup current JSON
        cp "$JSON_STORAGE" "${JSON_STORAGE}.backup.$(date +%Y%m%d_%H%M%S)"
        print_info "Backed up current JSON to ${JSON_STORAGE}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Copy new JSON
        cp "$TEMP_JSON" "$JSON_STORAGE"
        rm -f "$TEMP_JSON"
        
        print_success "YAML → JSON sync complete!"
        print_info "Restart Home Assistant or reload dashboard to see changes"
        ;;
        
    2)
        print_info "Syncing JSON → YAML (pulling UI changes to YAML source)..."
        TEMP_YAML=$(json_to_yaml "$JSON_STORAGE")
        
        # Backup current YAML
        cp "$YAML_SOURCE" "${YAML_SOURCE}.backup.$(date +%Y%m%d_%H%M%S)"
        print_info "Backed up current YAML to ${YAML_SOURCE}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Copy new YAML
        cp "$TEMP_YAML" "$YAML_SOURCE"
        # Fix ownership if run as root
        chown $(stat -c '%U:%G' "$YAML_SOURCE" 2>/dev/null || echo "pi:pi") "$YAML_SOURCE" 2>/dev/null || true
        rm -f "$TEMP_YAML"
        
        print_success "JSON → YAML sync complete!"
        print_info "YAML source file updated with UI changes"
        ;;
        
    3)
        print_info "Sync Status:"
        echo "  YAML file: $YAML_SOURCE"
        echo "    Modified: $(stat -c '%y' "$YAML_SOURCE" 2>/dev/null || echo 'N/A')"
        echo "  JSON file: $JSON_STORAGE"
        echo "    Modified: $(stat -c '%y' "$JSON_STORAGE" 2>/dev/null || echo 'N/A')"
        echo
        case "$SYNC_STATUS" in
            yaml_newer)
                print_warning "YAML is newer - use option 1 to push changes"
                ;;
            json_newer)
                print_warning "JSON is newer - use option 2 to pull changes"
                ;;
            synced)
                print_success "Files are in sync"
                ;;
        esac
        ;;
        
    4)
        print_info "Showing differences (YAML structure vs JSON structure)..."
        print_warning "Note: This is a structural comparison, not exact content"
        echo
        print_info "YAML views count: $(python3 -c "import yaml; f=open('$YAML_SOURCE'); d=yaml.safe_load(f); print(len(d.get('views', [])))" 2>/dev/null || echo 'N/A')"
        print_info "JSON views count: $(python3 -c "import json; f=open('$JSON_STORAGE'); d=json.load(f); print(len(d.get('data', {}).get('config', {}).get('views', [])))" 2>/dev/null || echo 'N/A')"
        ;;
        
    5)
        print_info "Exiting..."
        exit 0
        ;;
        
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

echo
print_info "Sync complete!"

