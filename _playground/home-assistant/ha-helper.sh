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
    if [ "$1" != "--no-backup" ]; then
        echo "💾 Creating auto-backup before restart..."
        cmd_backup "before-restart-$(date +%Y-%m-%d-%H-%M-%S)" > /dev/null
        print_success "Backup created"
        echo
    fi
    
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
      -e TZ="$TIMEZONE" \
      -v "${HA_CONFIG_DIR}:/config" \
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
    print_header
    check_container_exists
    
    if ! check_container_running; then
        print_error "Container must be running!"
        exit 1
    fi
    
    RELOAD_TYPE="${1:-core}"
    
    case "$RELOAD_TYPE" in
        core|config)
            echo "🔄 Reloading core configuration..."
            $DOCKER_CMD exec "${HA_CONTAINER}" ha core reload
            ;;
        automations|automation|auto)
            echo "🔄 Reloading automations..."
            $DOCKER_CMD exec "${HA_CONTAINER}" ha automation reload
            ;;
        scripts|script)
            echo "🔄 Reloading scripts..."
            $DOCKER_CMD exec "${HA_CONTAINER}" ha script reload
            ;;
        scenes|scene)
            echo "🔄 Reloading scenes..."
            $DOCKER_CMD exec "${HA_CONTAINER}" ha scene reload
            ;;
        themes|theme)
            echo "🔄 Reloading themes..."
            $DOCKER_CMD exec "${HA_CONTAINER}" ha frontend reload
            ;;
        *)
            print_error "Unknown reload type: ${RELOAD_TYPE}"
            echo "Available types: core, automations, scripts, scenes, themes"
            exit 1
            ;;
    esac
    
    print_success "Reload complete!"
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

cmd_help() {
    print_header
    
    cat << EOF
${CYAN}Usage:${NC} ha [command] [options]

${CYAN}Container Management:${NC}
  status              Show container status and resource usage
  start               Start the Home Assistant container
  stop                Stop the Home Assistant container
  restart             Restart container (creates auto-backup)
  update              Update to latest Home Assistant version
  stats               Show live resource usage statistics
  shell               Open shell inside container

${CYAN}Configuration Management:${NC}
  validate            Validate configuration files
  edit [file]         Edit configuration file (shortcuts available)
                      Shortcuts: config, automations, scripts, secrets, scenes
  reload [type]       Reload config without restart
                      Types: core, automations, scripts, scenes, themes
  cd                  Print cd command for config directory

${CYAN}Backup & Restore:${NC}
  backup [name]       Create backup (auto-named if not specified)
  restore <name>      Restore from backup (creates auto-backup first)
  list-backups        List all available backups

${CYAN}Logs & Debugging:${NC}
  logs                Tail logs in real-time (Ctrl+C to exit)
  logs-tail [n]       Show last N lines of logs (default: 50)
  errors              Show only errors and warnings from logs

${CYAN}Information:${NC}
  info                Show HA version and system info
  help                Show this help message

${CYAN}Examples:${NC}
  ha status                    # Check if everything is running
  ha validate                  # Check config before restart
  ha backup "before-changes"   # Create named backup
  ha restart                   # Safe restart with auto-backup
  ha edit automations          # Edit automations.yaml
  ha reload automations        # Reload automations without restart
  ha logs-tail 100             # Show last 100 log lines
  ha errors                    # Show recent errors

${CYAN}Notes:${NC}
  • Auto-backups are created before restart/restore/update operations
  • Backups are stored in: ${HA_BACKUP_DIR}
  • Use 'ha cd' with command substitution: \$(ha cd)

EOF
}

# === MAIN ===

# Check if command provided
if [ $# -eq 0 ]; then
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

