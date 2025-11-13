#!/bin/bash

# ha-helper - Home Assistant Development Helper Script
# Streamlines HA configuration management, validation, backups, and container control
# Usage: ha [command] [options]

set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
HA_CONTAINER="homeassistant"
HA_CONFIG_DIR="/home/pi/homeassistant"
HA_BACKUP_DIR="/home/pi/_playground/_ha-backups"
DOCKER_CMD="docker"

# Check if we need sudo for docker
if ! docker ps &> /dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
fi

# Ensure backup directory exists
mkdir -p "$HA_BACKUP_DIR"

# === UTILITY FUNCTIONS ===

print_header() {
    echo -e "${CYAN}🏠 Home Assistant Helper${NC}"
    echo -e "${CYAN}========================${NC}"
    echo
}

# Extract HA_TOKEN from secrets file (plain text, no password needed)
get_token_from_secrets() {
    local secrets_file="${HOME}/.secrets"
    
    if [ ! -f "$secrets_file" ]; then
        return 1
    fi
    
    # Read plain text file and extract HA_TOKEN
    grep "^HA_TOKEN=" "$secrets_file" 2>/dev/null | \
        cut -d'=' -f2- | \
        sed "s/^['\"]//;s/['\"]$//" | \
        head -1
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
    echo -e "${BLUE}ℹ️  $1${NC}"
}

check_container_exists() {
    if ! $DOCKER_CMD ps -a --format '{{.Names}}' | grep -q "^${HA_CONTAINER}$"; then
        print_error "Home Assistant container '${HA_CONTAINER}' not found!"
        echo "Run the bootstrap script first: bootstrap-home-assistant.sh"
        exit 1
    fi
}

check_container_running() {
    if ! $DOCKER_CMD ps --format '{{.Names}}' | grep -q "^${HA_CONTAINER}$"; then
        return 1
    fi
    return 0
}

# === COMMAND FUNCTIONS ===

cmd_status() {
    print_header
    check_container_exists
    
    echo -e "${CYAN}Container Status:${NC}"
    $DOCKER_CMD ps -a --filter "name=${HA_CONTAINER}" --format 'table {{.Names}}\t{{.Status}}\t{{.Size}}'
    echo
    
    if check_container_running; then
        echo -e "${CYAN}Resource Usage:${NC}"
        $DOCKER_CMD stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" "${HA_CONTAINER}"
        echo
        
        echo -e "${CYAN}Access URLs:${NC}"
        echo "  • http://192.168.1.159:8123"
        echo "  • http://MyP.local:8123"
        echo
        
        # Try to get HA version
        HA_VERSION=$($DOCKER_CMD exec "${HA_CONTAINER}" python3 -c "import homeassistant; print(homeassistant.__version__)" 2>/dev/null || echo "unknown")
        echo -e "${CYAN}Home Assistant Version:${NC} ${HA_VERSION}"
    else
        print_warning "Container is not running!"
        echo "Start it with: ha start"
    fi
    
    echo
    echo -e "${CYAN}Config Directory:${NC} ${HA_CONFIG_DIR}"
    echo -e "${CYAN}Backup Directory:${NC} ${HA_BACKUP_DIR}"
}

cmd_validate() {
    print_header
    check_container_exists
    
    if ! check_container_running; then
        print_error "Container must be running to validate config!"
        echo "Start it with: ha start"
        exit 1
    fi
    
    echo "🔍 Validating Home Assistant configuration..."
    echo
    
    if $DOCKER_CMD exec "${HA_CONTAINER}" python3 -m homeassistant --script check_config --config /config; then
        echo
        print_success "Configuration is valid!"
    else
        echo
        print_error "Configuration validation failed!"
        echo "Check the output above for details."
        exit 1
    fi
}

cmd_backup() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        cmd_backup_help
        exit 0
    fi
    
    print_header
    
    BACKUP_NAME="${1:-$(date +%Y-%m-%d-%H-%M-%S)}"
    BACKUP_PATH="${HA_BACKUP_DIR}/${BACKUP_NAME}"
    
    if [ -d "$BACKUP_PATH" ]; then
        print_error "Backup '${BACKUP_NAME}' already exists!"
        exit 1
    fi
    
    echo "💾 Creating backup: ${BACKUP_NAME}"
    
    mkdir -p "$BACKUP_PATH"
    
    # Copy all config files
    cp -r "${HA_CONFIG_DIR}"/* "$BACKUP_PATH/" 2>/dev/null || true
    
    # Create backup metadata
    cat > "${BACKUP_PATH}/_backup_info.txt" <<EOF
Backup Name: ${BACKUP_NAME}
Created: $(date)
Source: ${HA_CONFIG_DIR}
EOF
    
    if check_container_running; then
        HA_VERSION=$($DOCKER_CMD exec "${HA_CONTAINER}" python3 -c "import homeassistant; print(homeassistant.__version__)" 2>/dev/null || echo "unknown")
        echo "HA Version: ${HA_VERSION}" >> "${BACKUP_PATH}/_backup_info.txt"
    fi
    
    print_success "Backup created: ${BACKUP_PATH}"
    
    # Show disk usage
    BACKUP_SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)
    echo "Backup size: ${BACKUP_SIZE}"
}

cmd_restore() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        cmd_restore_help
        exit 0
    fi
    
    print_header
    
    if [ -z "$1" ]; then
        print_error "No backup name specified!"
        echo "Available backups:"
        cmd_list_backups
        exit 1
    fi
    
    BACKUP_NAME="$1"
    BACKUP_PATH="${HA_BACKUP_DIR}/${BACKUP_NAME}"
    
    if [ ! -d "$BACKUP_PATH" ]; then
        print_error "Backup '${BACKUP_NAME}' not found!"
        echo "Available backups:"
        cmd_list_backups
        exit 1
    fi
    
    print_warning "This will overwrite your current configuration!"
    echo "Restoring from: ${BACKUP_PATH}"
    
    if [ -f "${BACKUP_PATH}/_backup_info.txt" ]; then
        echo
        cat "${BACKUP_PATH}/_backup_info.txt"
        echo
    fi
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Restore cancelled"
        exit 0
    fi
    
    # Create auto-backup before restore
    echo "Creating auto-backup before restore..."
    cmd_backup "before-restore-$(date +%Y-%m-%d-%H-%M-%S)"
    
    echo "📦 Restoring configuration..."
    
    # Stop container if running
    if check_container_running; then
        echo "Stopping Home Assistant..."
        $DOCKER_CMD stop "${HA_CONTAINER}" > /dev/null
    fi
    
    # Restore files
    rm -rf "${HA_CONFIG_DIR:?}"/*
    cp -r "${BACKUP_PATH}"/* "${HA_CONFIG_DIR}/" 2>/dev/null || true
    rm -f "${HA_CONFIG_DIR}/_backup_info.txt"
    
    # Start container
    echo "Starting Home Assistant..."
    $DOCKER_CMD start "${HA_CONTAINER}" > /dev/null
    
    print_success "Configuration restored!"
    echo "Waiting for Home Assistant to start..."
    sleep 3
    cmd_logs_tail 20
}

cmd_list_backups() {
    if [ ! -d "$HA_BACKUP_DIR" ] || [ -z "$(ls -A "$HA_BACKUP_DIR")" ]; then
        print_info "No backups found"
        return
    fi
    
    echo -e "${CYAN}Available Backups:${NC}"
    echo
    
    for backup in "$HA_BACKUP_DIR"/*; do
        if [ -d "$backup" ]; then
            BACKUP_NAME=$(basename "$backup")
            BACKUP_SIZE=$(du -sh "$backup" | cut -f1)
            
            if [ -f "${backup}/_backup_info.txt" ]; then
                CREATED=$(grep "^Created:" "${backup}/_backup_info.txt" | cut -d: -f2- | xargs)
                echo -e "  ${GREEN}${BACKUP_NAME}${NC} (${BACKUP_SIZE})"
                echo "    Created: ${CREATED}"
            else
                echo -e "  ${GREEN}${BACKUP_NAME}${NC} (${BACKUP_SIZE})"
            fi
            echo
        fi
    done
}

cmd_restart() {
    print_header
    check_container_exists
    
    # Create auto-backup before restart
    # if [ "$1" != "--no-backup" ]; then
    #     echo "💾 Creating auto-backup before restart..."
    #     cmd_backup "before-restart-$(date +%Y-%m-%d-%H-%M-%S)" > /dev/null
    #     print_success "Backup created"
    #     echo
    # fi
    
    echo "🔄 Restarting Home Assistant..."
    
    if $DOCKER_CMD restart "${HA_CONTAINER}"; then
        print_success "Container restarted"
        echo
        echo "⏱️  Waiting for Home Assistant to start (this takes ~30 seconds)..."
        sleep 5
        echo
        cmd_logs_tail 20
    else
        print_error "Failed to restart container!"
        exit 1
    fi
}

cmd_start() {
    print_header
    check_container_exists
    
    if check_container_running; then
        print_info "Container is already running"
        return
    fi
    
    echo "▶️  Starting Home Assistant..."
    
    if $DOCKER_CMD start "${HA_CONTAINER}"; then
        print_success "Container started"
        echo
        echo "⏱️  Waiting for Home Assistant to initialize..."
        sleep 3
        cmd_status
    else
        print_error "Failed to start container!"
        exit 1
    fi
}

cmd_stop() {
    print_header
    check_container_exists
    
    if ! check_container_running; then
        print_info "Container is not running"
        return
    fi
    
    echo "⏹️  Stopping Home Assistant..."
    
    if $DOCKER_CMD stop "${HA_CONTAINER}"; then
        print_success "Container stopped"
    else
        print_error "Failed to stop container!"
        exit 1
    fi
}

cmd_logs() {
    check_container_exists
    
    echo -e "${CYAN}📋 Home Assistant Logs (Ctrl+C to exit)${NC}"
    echo
    
    $DOCKER_CMD logs -f "${HA_CONTAINER}"
}

cmd_logs_tail() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        cmd_logs_tail_help
        exit 0
    fi
    
    check_container_exists
    
    LINES="${1:-50}"
    
    echo -e "${CYAN}📋 Last ${LINES} log lines:${NC}"
    echo
    
    $DOCKER_CMD logs --tail "$LINES" "${HA_CONTAINER}"
}

cmd_errors() {
    check_container_exists
    
    echo -e "${CYAN}🔍 Filtering for errors and warnings...${NC}"
    echo
    
    $DOCKER_CMD logs "${HA_CONTAINER}" 2>&1 | grep -iE "(error|warning|critical|exception)" --color=always | tail -50
}

cmd_shell() {
    print_header
    check_container_exists
    
    if ! check_container_running; then
        print_error "Container must be running to access shell!"
        echo "Start it with: ha start"
        exit 1
    fi
    
    echo "🐚 Opening shell in Home Assistant container..."
    echo "   (type 'exit' to leave)"
    echo
    
    $DOCKER_CMD exec -it "${HA_CONTAINER}" /bin/bash
}

cmd_edit() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        cmd_edit_help
        exit 0
    fi
    
    FILE="${1:-configuration.yaml}"
    FILEPATH="${HA_CONFIG_DIR}/${FILE}"
    
    # Handle common shortcuts
    case "$FILE" in
        config|configuration)
            FILEPATH="${HA_CONFIG_DIR}/configuration.yaml"
            ;;
        auto|automations)
            FILEPATH="${HA_CONFIG_DIR}/automations.yaml"
            ;;
        script|scripts)
            FILEPATH="${HA_CONFIG_DIR}/scripts.yaml"
            ;;
        secret|secrets)
            FILEPATH="${HA_CONFIG_DIR}/secrets.yaml"
            ;;
        scene|scenes)
            FILEPATH="${HA_CONFIG_DIR}/scenes.yaml"
            ;;
        customize)
            FILEPATH="${HA_CONFIG_DIR}/customize.yaml"
            ;;
        *)
            # Use as-is if it doesn't match shortcuts
            if [ ! -f "$FILEPATH" ]; then
                print_error "File not found: ${FILEPATH}"
                exit 1
            fi
            ;;
    esac
    
    # Try to use cursor/code, fallback to nano
    if command -v cursor &> /dev/null; then
        cursor "$FILEPATH"
    elif command -v code &> /dev/null; then
        code "$FILEPATH"
    else
        nano "$FILEPATH"
    fi
}

cmd_cd() {
    echo "cd ${HA_CONFIG_DIR}"
}

cmd_update() {
    print_header
    check_container_exists
    
    print_warning "This will update Home Assistant to the latest stable version"
    echo
    
    # Show current version
    if check_container_running; then
        CURRENT_VERSION=$($DOCKER_CMD exec "${HA_CONTAINER}" python3 -c "import homeassistant; print(homeassistant.__version__)" 2>/dev/null || echo "unknown")
        echo "Current version: ${CURRENT_VERSION}"
        echo
    fi
    
    read -p "Continue with update? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Update cancelled"
        exit 0
    fi
    
    # Create backup
    echo "💾 Creating backup before update..."
    cmd_backup "before-update-$(date +%Y-%m-%d-%H-%M-%S)" > /dev/null
    print_success "Backup created"
    echo
    
    # Pull new image
    echo "📥 Pulling latest Home Assistant image..."
    $DOCKER_CMD pull ghcr.io/home-assistant/home-assistant:stable
    echo
    
    # Stop and remove old container
    echo "🔄 Stopping current container..."
    $DOCKER_CMD stop "${HA_CONTAINER}"
    echo "🗑️  Removing old container..."
    $DOCKER_CMD rm "${HA_CONTAINER}"
    echo
    
    # Get timezone
    TIMEZONE=$(cat /etc/timezone 2>/dev/null || echo "UTC")
    
    # Create new container with same settings
    echo "🚀 Creating new container..."
    $DOCKER_CMD run -d \
      --name "${HA_CONTAINER}" \
      --privileged \
      --restart=unless-stopped \
      --cap-add=NET_ADMIN \
      --cap-add=NET_RAW \
      -e TZ="$TIMEZONE" \
      -v "${HA_CONFIG_DIR}:/config" \
      -v /run/dbus:/run/dbus:ro \
      --network=host \
      ghcr.io/home-assistant/home-assistant:stable
    
    echo
    print_success "Update complete!"
    echo
    echo "⏱️  Waiting for Home Assistant to start..."
    sleep 5
    
    # Show new version
    if check_container_running; then
        NEW_VERSION=$($DOCKER_CMD exec "${HA_CONTAINER}" python3 -c "import homeassistant; print(homeassistant.__version__)" 2>/dev/null || echo "unknown")
        echo "New version: ${NEW_VERSION}"
        echo
    fi
    
    cmd_logs_tail 20
}

cmd_stats() {
    print_header
    check_container_exists
    
    if ! check_container_running; then
        print_error "Container is not running!"
        exit 1
    fi
    
    echo -e "${CYAN}Resource Usage (live updates, Ctrl+C to exit):${NC}"
    echo
    
    $DOCKER_CMD stats "${HA_CONTAINER}"
}

cmd_reload() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        cmd_reload_help
        exit 0
    fi
    
    print_header
    check_container_exists
    
    if ! check_container_running; then
        print_error "Container must be running!"
        exit 1
    fi
    
    RELOAD_TYPE="${1:-core}"
    
    # Determine the service and domain based on reload type
    case "$RELOAD_TYPE" in
        core|config)
            echo "🔄 Reloading core configuration..."
            SERVICE_DOMAIN="homeassistant"
            SERVICE_NAME="reload_all"
            ;;
        automations|automation|auto)
            echo "🔄 Reloading automations..."
            SERVICE_DOMAIN="automation"
            SERVICE_NAME="reload"
            ;;
        scripts|script)
            echo "🔄 Reloading scripts..."
            SERVICE_DOMAIN="script"
            SERVICE_NAME="reload"
            ;;
        scenes|scene)
            echo "🔄 Reloading scenes..."
            SERVICE_DOMAIN="scene"
            SERVICE_NAME="reload"
            ;;
        themes|theme)
            echo "🔄 Reloading themes..."
            SERVICE_DOMAIN="frontend"
            SERVICE_NAME="reload_themes"
            ;;
        *)
            print_error "Unknown reload type: ${RELOAD_TYPE}"
            echo "Available types: core, automations, scripts, scenes, themes"
            exit 1
            ;;
    esac
    
    # Use Home Assistant REST API to call the service
    # Try to get a long-lived access token
    TOKEN=""
    
    # Priority order:
    # 1. Environment variable (highest priority)
    # 2. Encrypted secrets file (via manage-secrets.sh export)
    # 3. Extract from .storage directory
    
    if [ -n "$HA_TOKEN" ]; then
        TOKEN="$HA_TOKEN"
    # Try to load from encrypted secrets file (non-interactive - uses cached password only)
    elif TOKEN=$(get_token_from_secrets 2>/dev/null); [ -n "$TOKEN" ]; then
        # Token extracted successfully using cached password
        :
    # Then try to extract from .storage directory
    elif [ -d "${HA_CONFIG_DIR}/.storage" ]; then
        # Try to extract token from auth_provider.homeassistant file
        TOKEN=$($DOCKER_CMD exec "${HA_CONTAINER}" python3 -c "
import json
import os
import sys

# Try multiple locations for tokens
token_files = [
    '/config/.storage/auth_provider.homeassistant',
    '/config/.storage/auth'
]

for token_file in token_files:
    if os.path.exists(token_file):
        try:
            with open(token_file, 'r') as f:
                data = json.load(f)
                # Look for tokens in various structures
                if isinstance(data, dict):
                    # Check for tokens in different possible locations
                    if 'data' in data and isinstance(data['data'], dict):
                        # Check for refresh_tokens
                        if 'refresh_tokens' in data['data']:
                            for token_data in data['data']['refresh_tokens']:
                                if 'token' in token_data:
                                    print(token_data['token'])
                                    sys.exit(0)
                    # Check for direct token field
                    if 'token' in data:
                        print(data['token'])
                        sys.exit(0)
        except:
            continue
" 2>/dev/null | head -1)
    fi
    
    # If no token found, try to use the API without authentication
    # (may work for localhost in some configurations)
    API_URL="http://localhost:8123/api/services/${SERVICE_DOMAIN}/${SERVICE_NAME}"
    
    if [ -n "$TOKEN" ]; then
        # Use token for authentication
        RESPONSE=$($DOCKER_CMD exec "${HA_CONTAINER}" curl -s -w "\n%{http_code}" \
            -X POST \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            "${API_URL}" \
            2>&1)
    else
        # Try without authentication (may work for localhost)
        RESPONSE=$($DOCKER_CMD exec "${HA_CONTAINER}" curl -s -w "\n%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            "${API_URL}" \
            2>&1)
    fi
    
    # Extract HTTP status code (last line)
    HTTP_CODE=$(echo "$RESPONSE" | tail -1 | tr -d '\r\n')
    RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')
    
    # Check if the request was successful
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    print_success "Reload complete!"
    else
        print_error "Failed to reload ${RELOAD_TYPE}"
        if [ -n "$RESPONSE_BODY" ]; then
            # Show error message if available
            echo "$RESPONSE_BODY" | head -5
        fi
        if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
            echo
            echo "Authentication required. To fix this:"
            echo "1. Go to Home Assistant UI > Profile > Long-Lived Access Tokens"
            echo "2. Create a new token"
            echo "3. Set it as an environment variable: export HA_TOKEN='your-token'"
            echo "4. Or add it to the script configuration"
            echo
            echo "Alternatively, you can reload via the Home Assistant UI:"
            echo "  Developer Tools > Services > ${SERVICE_DOMAIN}.${SERVICE_NAME}"
        else
            echo "HTTP Status: $HTTP_CODE"
        fi
        exit 1
    fi
}

cmd_list_entities() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        cmd_list_entities_help
        exit 0
    fi
    
    print_header
    check_container_exists
    
    if ! check_container_running; then
        print_error "Container must be running to list entities!"
        echo "Start it with: ha start"
        exit 1
    fi
    
    PATTERN="${1:-}"
    
    if [ -z "$PATTERN" ]; then
        print_info "Listing all entities..."
        echo
    else
        print_info "Listing entities matching pattern: ${PATTERN}"
        echo
    fi
    
    # Use Home Assistant REST API to get live states
    # First try with token, then fallback to state file
    TEMP_SCRIPT="/tmp/ha_list_entities_$$.py"
    cat > "$TEMP_SCRIPT" <<'PYTHONSCRIPT'
import json
import sys
import os
import urllib.request
import urllib.error

pattern = os.environ.get('PATTERN_ENV', '').lower().strip()

# Try to get token from environment or encrypted file
token = os.environ.get('HA_TOKEN', '')
if not token:
    # Try to read from encrypted secrets file
    try:
        import subprocess
        result = subprocess.run(
            ['gpg', '--pinentry-mode', 'loopback', '--quiet', '--decrypt', os.path.expanduser('~/.ha-secrets.encrypted')],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            for line in result.stdout.split('\n'):
                if line.startswith('HA_TOKEN='):
                    token = line.split('=', 1)[1].strip().strip("'\"")
                    break
    except:
        pass

# Try to get states from REST API first (most accurate)
api_url = "http://localhost:8123/api/states"
headers = {'Content-Type': 'application/json'}
if token:
    headers['Authorization'] = f'Bearer {token}'

try:
    req = urllib.request.Request(api_url, headers=headers)
    with urllib.request.urlopen(req, timeout=5) as response:
        if response.status == 200:
            states_data = json.loads(response.read().decode())
            
            entities = []
            for state in states_data:
                entity_id = state.get('entity_id', '')
                state_value = state.get('state', 'unknown')
                
                if not pattern or pattern in entity_id.lower():
                    domain = entity_id.split('.')[0] if '.' in entity_id else 'unknown'
                    entities.append({
                        'entity_id': entity_id,
                        'state': state_value,
                        'domain': domain
                    })
            
            # Sort by entity_id
            entities.sort(key=lambda x: x['entity_id'])
            
            # Display results
            if entities:
                print(f"{'Entity ID':<50} {'Domain':<15} {'State':<20}")
                print("-" * 85)
                for e in entities:
                    state_display = str(e['state'])[:18] if len(str(e['state'])) > 18 else str(e['state'])
                    print(f"{e['entity_id']:<50} {e['domain']:<15} {state_display:<20}")
                print(f"\nTotal: {len(entities)} entities" + (f" matching '{pattern}'" if pattern else ""))
            else:
                if pattern:
                    print(f"No entities found matching pattern: '{pattern}'")
                    print("\nTip: Try 'ha list-entities' to see all entities")
                else:
                    print("No entities found")
            # Successfully used API - exit without fallback message
            sys.exit(0)
except urllib.error.HTTPError as e:
    if e.code == 401:
        # Authentication failed, fall through to state file
        pass
    else:
        print(f"API Error: {e.code}", file=sys.stderr)
except Exception as e:
    # API failed, fall through to state file
    pass

# Fallback: Read from state file
from pathlib import Path
state_file = Path("/config/.storage/core.restore_state")
if not state_file.exists():
    print("Error: Could not access Home Assistant API and state file not found.", file=sys.stderr)
    print("Make sure Home Assistant is running and you have a valid HA_TOKEN set.", file=sys.stderr)
    sys.exit(1)

try:
    with open(state_file, 'r') as f:
        data = json.load(f)
    
    states = []
    if isinstance(data, dict) and 'data' in data:
            data_content = data['data']
            if isinstance(data_content, list):
                states = data_content
    
    entities = []
    for state_data in states:
        if not isinstance(state_data, dict):
            continue
        
        entity_id = None
        state_value = 'unknown'
        
        if 'state' in state_data and isinstance(state_data['state'], dict):
            state_obj = state_data['state']
            entity_id = state_obj.get('entity_id', '')
            state_value = state_obj.get('state', 'unknown')
        elif 'entity_id' in state_data:
            entity_id = state_data.get('entity_id', '')
            state_value = state_data.get('state', 'unknown')
        
        if not entity_id:
            continue
        
        if not pattern or pattern in entity_id.lower():
            domain = entity_id.split('.')[0] if '.' in entity_id else 'unknown'
            entities.append({
                'entity_id': entity_id,
                'state': state_value,
                'domain': domain
            })
    
    # Sort by entity_id
    entities.sort(key=lambda x: x['entity_id'])
    
    # Display results
    if entities:
        print(f"{'Entity ID':<50} {'Domain':<15} {'State':<20}")
        print("-" * 85)
        for e in entities:
            state_display = str(e['state'])[:18] if len(str(e['state'])) > 18 else str(e['state'])
            print(f"{e['entity_id']:<50} {e['domain']:<15} {state_display:<20}")
        print(f"\nTotal: {len(entities)} entities" + (f" matching '{pattern}'" if pattern else ""))
        print("\nNote: Using state file (may show 'unknown' for some entities).")
        print("      Set HA_TOKEN for live state data.")
    else:
        if pattern:
            print(f"No entities found matching pattern: '{pattern}'")
            print("\nTip: Try 'ha list-entities' to see all entities")
        else:
            print("No entities found")
            
except Exception as e:
    import traceback
    print(f"Error retrieving entities: {e}", file=sys.stderr)
    traceback.print_exc(file=sys.stderr)
    sys.exit(1)
PYTHONSCRIPT
    
    # Get token before running Python script (so we can pass it as env var)
    TOKEN_FOR_PYTHON=""
    if [ -n "$HA_TOKEN" ]; then
        TOKEN_FOR_PYTHON="$HA_TOKEN"
    elif TOKEN_FOR_PYTHON=$(get_token_from_secrets 2>/dev/null); [ -n "$TOKEN_FOR_PYTHON" ]; then
        # Token extracted successfully using cached password (non-interactive)
        :
    fi
    
    # Copy script to container and execute
    $DOCKER_CMD cp "$TEMP_SCRIPT" "${HA_CONTAINER}:/tmp/ha_list_entities.py"
    if [ -n "$TOKEN_FOR_PYTHON" ]; then
        $DOCKER_CMD exec -e PATTERN_ENV="$PATTERN" -e HA_TOKEN="$TOKEN_FOR_PYTHON" "${HA_CONTAINER}" python3 -u /tmp/ha_list_entities.py
    else
        $DOCKER_CMD exec -e PATTERN_ENV="$PATTERN" "${HA_CONTAINER}" python3 -u /tmp/ha_list_entities.py
    fi
    EXIT_CODE=$?
    
    # Clean up
    rm -f "$TEMP_SCRIPT"
    $DOCKER_CMD exec "${HA_CONTAINER}" rm -f /tmp/ha_list_entities.py > /dev/null 2>&1
    
    if [ $EXIT_CODE -ne 0 ]; then
        exit $EXIT_CODE
    fi
}

cmd_rename_a1_entities() {
    print_header
    
    # Script is in _playground, config dir is in home
    SCRIPT_PATH="/home/pi/_playground/home-assistant/scripts/rename-a1-entities.sh"
    
    if [ ! -f "$SCRIPT_PATH" ]; then
        print_error "Rename script not found: ${SCRIPT_PATH}"
        exit 1
    fi
    
    print_info "Running A1 entity rename script..."
    echo "This will rename entities from 'a1_SERIAL_*' to 'a1_*'"
    echo
    
    HA_CONFIG_DIR="$HA_CONFIG_DIR" bash "$SCRIPT_PATH"
}

cmd_fix_permissions() {
    print_header
    
    if [ ! -d "$HA_CONFIG_DIR" ]; then
        print_error "Home Assistant config directory not found: ${HA_CONFIG_DIR}"
        exit 1
    fi
    
    print_info "Fixing permissions on Home Assistant directory..."
    echo "This will change ownership of all files to user 'pi'"
    echo
    
    # Count files owned by root
    ROOT_FILES=$(find "$HA_CONFIG_DIR" ! -user pi 2>/dev/null | wc -l)
    
    if [ "$ROOT_FILES" -eq 0 ]; then
        print_success "All files are already owned by user 'pi'"
        return 0
    fi
    
    echo "Found $ROOT_FILES files/directories owned by root"
    echo
    
    # Fix permissions
    if sudo chown -R pi:pi "$HA_CONFIG_DIR"; then
        print_success "Permissions fixed successfully!"
        echo
        echo "All files in ${HA_CONFIG_DIR} are now owned by user 'pi'"
    else
        print_error "Failed to fix permissions"
        exit 1
    fi
    
    echo
    print_info "Note: If the container recreates files, they will be owned by root again."
    echo "      Run this command again if needed."
}

cmd_info() {
    print_header
    
    echo -e "${CYAN}Home Assistant Information${NC}"
    echo
    echo -e "${CYAN}Container:${NC} ${HA_CONTAINER}"
    echo -e "${CYAN}Config Directory:${NC} ${HA_CONFIG_DIR}"
    echo -e "${CYAN}Backup Directory:${NC} ${HA_BACKUP_DIR}"
    echo
    
    if check_container_running; then
        HA_VERSION=$($DOCKER_CMD exec "${HA_CONTAINER}" python3 -c "import homeassistant; print(homeassistant.__version__)" 2>/dev/null || echo "unknown")
        echo -e "${CYAN}Version:${NC} ${HA_VERSION}"
        
        UPTIME=$($DOCKER_CMD inspect -f '{{ .State.StartedAt }}' "${HA_CONTAINER}" 2>/dev/null)
        echo -e "${CYAN}Started:${NC} ${UPTIME}"
        echo
        
        echo -e "${CYAN}URLs:${NC}"
        echo "  • http://192.168.1.159:8123"
        echo "  • http://MyP.local:8123"
    else
        print_warning "Container is not running"
    fi
    
    echo
    echo -e "${CYAN}Quick Commands:${NC}"
    echo "  ha status        - Show detailed status"
    echo "  ha logs          - View logs"
    echo "  ha restart       - Restart with backup"
    echo "  ha validate      - Check configuration"
}

# === SUB-HELP FUNCTIONS ===

cmd_edit_help() {
    cat << 'EOF'
ha edit: Edit Home Assistant configuration files

Usage:
    ha edit [file]
    ha edit --help

Arguments:
    file                        Configuration file to edit (optional)
                                Default: configuration.yaml

Shortcuts:
    config, configuration        Edit configuration.yaml
    auto, automations           Edit automations.yaml
    script, scripts             Edit scripts.yaml
    secret, secrets             Edit secrets.yaml
    scene, scenes               Edit scenes.yaml
    customize                   Edit customize.yaml

Examples:
    ha edit                     Edit configuration.yaml
    ha edit automations         Edit automations.yaml
    ha edit scripts             Edit scripts.yaml
    ha edit custom_file.yaml    Edit a specific file

Notes:
    • Opens files in cursor (if available), otherwise code, otherwise nano
    • Files are edited in: /home/pi/homeassistant/config

EOF
}

cmd_reload_help() {
    cat << 'EOF'
ha reload: Reload Home Assistant configuration without restart

Usage:
    ha reload [type]
    ha reload --help

Arguments:
    type                        Type of configuration to reload (optional)
                                Default: core

Types:
    core, config                Reload core configuration
    automations, automation    Reload automations
    scripts, script            Reload scripts
    scenes, scene              Reload scenes
    themes, theme              Reload themes

Examples:
    ha reload                   Reload core configuration
    ha reload automations      Reload automations
    ha reload scripts           Reload scripts
    ha reload themes            Reload themes

Notes:
    • Reloads configuration without restarting the container
    • Faster than restart but may not catch all configuration errors

EOF
}

cmd_backup_help() {
    cat << 'EOF'
ha backup: Create a backup of Home Assistant configuration

Usage:
    ha backup [name]
    ha backup --help

Arguments:
    name                        Backup name (optional)
                                If not provided, auto-generated with timestamp

Examples:
    ha backup                   Create auto-named backup
    ha backup "before-changes"  Create named backup
    ha backup "2024-01-15"      Create backup with specific name

Notes:
    • Backups are stored in: /home/pi/_playground/_ha-backups
    • Each backup includes all configuration files
    • Auto-backups are created before restart/restore/update operations

EOF
}

cmd_restore_help() {
    cat << 'EOF'
ha restore: Restore Home Assistant configuration from backup

Usage:
    ha restore <name>
    ha restore --help

Arguments:
    name                        Name of backup to restore (required)

Examples:
    ha restore "before-changes" Restore from named backup
    ha restore "2024-01-15"     Restore from specific backup

Notes:
    • Creates an auto-backup before restoring
    • Stops container during restore
    • Use 'ha list-backups' to see available backups
    • Backups are stored in: /home/pi/_playground/_ha-backups

EOF
}

cmd_logs_tail_help() {
    cat << 'EOF'
ha logs-tail: Show last N lines of Home Assistant logs

Usage:
    ha logs-tail [n]
    ha logs-tail --help

Arguments:
    n                           Number of lines to show (optional)
                                Default: 50

Examples:
    ha logs-tail                Show last 50 lines
    ha logs-tail 100            Show last 100 lines
    ha logs-tail 20             Show last 20 lines

Notes:
    • Shows recent log entries without following
    • Use 'ha logs' to follow logs in real-time
    • Use 'ha errors' to show only errors and warnings

EOF
}

cmd_list_entities_help() {
    cat << 'EOF'
ha list-entities: List Home Assistant entities

Usage:
    ha list-entities [pattern]
    ha list-entities --help

Arguments:
    pattern                     Filter entities by pattern (optional)
                                Matches entity_id containing the pattern

Examples:
    ha list-entities            List all entities
    ha list-entities a1         List all a1 entities
    ha list-entities sensor     List all sensor entities
    ha list-entities light      List all light entities

Notes:
    • Pattern matching is case-insensitive
    • Shows entity_id and current state
    • Requires container to be running

EOF
}

# === MAIN HELP ===

cmd_help() {
    cat << 'EOF'
ha: Home Assistant Development Helper

Usage:
    ha [command] [options]
    ha (--help | -h)
    ha <command> --help         Show help for specific command

Container Management:
    status, st                    Show container status and resource usage
    start                         Start the Home Assistant container
    stop                          Stop the Home Assistant container
    restart, r                    Restart container
    update, up                    Update to latest Home Assistant version
    stats, stat                   Show live resource usage statistics
    shell, sh, bash               Open shell inside container

Configuration Management:
    validate, check, val           Validate configuration files
    edit [file], e [file]         Edit configuration file (use --help for details)
                      Shortcuts: config, automations, scripts, secrets, scenes
    reload [type], rel [type]     Reload config without restart (use --help for details)
                      Types: core, automations, scripts, scenes, themes
    cd                            Print cd command for config directory

Backup & Restore:
    backup [name], bak [name]     Create backup (use --help for details)
    restore <name>, res <name>    Restore from backup (use --help for details)
    list-backups, list, lb        List all available backups

Logs & Debugging:
    logs, log, l                  Tail logs in real-time (Ctrl+C to exit)
    logs-tail [n], tail, lt [n]   Show last N lines of logs (use --help for details)
                                  Default: 50
    errors, err, e                Show only errors and warnings from logs

Information:
    list-entities [pattern]       List all entities (use --help for details)
    rename-a1-entities            Rename A1 entities to remove serial numbers
    fix-permissions, fix-perms    Fix file ownership (change root-owned files to pi)
    info, i                       Show HA version and system info
    help, h, --help, -h           Show this help message

Examples:
    ha status                     Check if everything is running
    ha validate                   Check config before restart
    ha backup "before-changes"    Create named backup
    ha restart                    Restart container
    ha edit automations           Edit automations.yaml
    ha edit --help                Show help for edit command
    ha reload automations         Reload automations without restart
    ha logs-tail 100              Show last 100 log lines
    ha errors                     Show recent errors
    ha list-entities a1           List all a1 entities
    ha fix-permissions            Fix file ownership issues

Notes:
    • Backups are stored in: /home/pi/_playground/_ha-backups
    • Use 'ha cd' with command substitution: $(ha cd)
  • Auto-backups are created before restart/restore/update operations
    • Use 'ha <command> --help' for detailed help on specific commands

EOF
}

# === MAIN ===

# Check if command provided
if [ $# -eq 0 ]; then
    cmd_help
    exit 0
fi

# Handle --help and -h at top level
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    cmd_help
    exit 0
fi

COMMAND="$1"
shift

case "$COMMAND" in
    status|st)
        cmd_status "$@"
        ;;
    validate|check|val)
        cmd_validate "$@"
        ;;
    backup|bak)
        cmd_backup "$@"
        ;;
    restore|res)
        cmd_restore "$@"
        ;;
    list-backups|list|lb)
        cmd_list_backups "$@"
        ;;
    restart|r)
        cmd_restart "$@"
        ;;
    start)
        cmd_start "$@"
        ;;
    stop)
        cmd_stop "$@"
        ;;
    logs|log|l)
        cmd_logs "$@"
        ;;
    logs-tail|tail|lt)
        cmd_logs_tail "$@"
        ;;
    errors|err|e)
        cmd_errors "$@"
        ;;
    shell|sh|bash)
        cmd_shell "$@"
        ;;
    edit|e)
        cmd_edit "$@"
        ;;
    cd)
        cmd_cd "$@"
        ;;
    update|upgrade|up)
        cmd_update "$@"
        ;;
    stats|stat)
        cmd_stats "$@"
        ;;
    reload|rel)
        cmd_reload "$@"
        ;;
    list-entities|entities|ent|le)
        cmd_list_entities "$@"
        ;;
    rename-a1|rename-a1-entities)
        cmd_rename_a1_entities "$@"
        ;;
    fix-permissions|fix-perms|fp)
        cmd_fix_permissions "$@"
        ;;
    info|i)
        cmd_info "$@"
        ;;
    help|h|--help|-h)
        cmd_help "$@"
        ;;
    *)
        print_error "Unknown command: ${COMMAND}"
        echo
        echo "Run 'ha help' to see available commands"
        exit 1
        ;;
esac

