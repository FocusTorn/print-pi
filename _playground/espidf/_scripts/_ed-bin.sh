#!/usr/bin/env bash
# ESP-IDF Development Menu (ed)
# Interactive menu for ESP-IDF commands with shortcuts

# Get script directory
_ED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ESPIDF_DIR="$(cd "$_ED_DIR/.." && pwd)"

# Source iMenu
if [ -f "$HOME/_playground/_dev/packages/_utilities/iMenu/iMenu.sh" ]; then
    source "$HOME/_playground/_dev/packages/_utilities/iMenu/iMenu.sh"
else
    echo "Error: iMenu not found" >&2
    exit 1
fi

# Command definitions with shortcuts
declare -A ESPIDF_COMMANDS=(
    ["gi"]="get_idf_custom - Enters the s3 specific venv"
    ["gb"]="idf.py build - Build the current project"
    ["gf"]="idf.py flash - Flash to device"
    ["gm"]="idf.py monitor - Monitor serial output"
    ["gfm"]="idf.py flash monitor - Flash and monitor"
    ["gc"]="idf.py fullclean - Clean build artifacts"
    ["gmc"]="idf.py menuconfig - Configure project"
    ["gst"]="idf.py set-target esp32s3 - Set target to ESP32-S3"
    ["gv"]="idf.py --version - Show ESP-IDF version"
    ["gnew"]="new-project.sh - Create new ESP-IDF project"
    ["gport"]="detect-port.sh - Auto-detect ESP32 board port"
)

# Function to execute command
_execute_command() {
    local shortcut="$1"
    local cmd="${ESPIDF_COMMANDS[$shortcut]}"
    
    if [ -z "$cmd" ]; then
        echo "Error: Unknown shortcut '$shortcut'" >&2
        return 1
    fi
    
    # Extract command from description
    local actual_cmd="${cmd%% -*}"
    
    # Handle special cases
    case "$shortcut" in
        "gi")
            # Source the custom get_idf script
            if [ -f "$_ESPIDF_DIR/_scripts/get_idf_custom.sh" ]; then
                source "$_ESPIDF_DIR/_scripts/get_idf_custom.sh"
            else
                echo "Error: get_idf_custom.sh not found" >&2
                return 1
            fi
            ;;
        "gnew")
            # Run new-project script
            "$_ESPIDF_DIR/_scripts/new-project.sh"
            ;;
        "gport")
            # Run detect-port script
            "$_ESPIDF_DIR/_scripts/detect-port.sh"
            ;;
        *)
            # Run idf.py commands (requires get_idf to be run first)
            if ! command -v idf.py &> /dev/null; then
                echo "⚠️  ESP-IDF environment not activated. Run 'ed gi' first or 'get_idf'"
                return 1
            fi
            eval "$actual_cmd"
            ;;
    esac
}

# Build menu items
_build_menu_items() {
    local items=()
    for shortcut in "${!ESPIDF_COMMANDS[@]}"; do
        local desc="${ESPIDF_COMMANDS[$shortcut]}"
        items+=("[$shortcut] $desc")
    done
    # Sort by shortcut
    IFS=$'\n' sorted_items=($(sort <<<"${items[*]}"))
    unset IFS
    printf '%s\n' "${sorted_items[@]}"
}

# Main function
_main() {
    # If shortcut provided as argument, execute directly
    if [ $# -gt 0 ]; then
        _execute_command "$1"
        return $?
    fi
    
    # Otherwise show menu
    local menu_items
    readarray -t menu_items < <(_build_menu_items)
    
    local selected
    selected=$(prompt_select "espidf_menu" "ESP-IDF Development Commands" "${menu_items[@]}")
    
    if [ -n "$selected" ]; then
        # Extract shortcut from selection (format: [gi] description)
        local shortcut="${selected#\[}"
        shortcut="${shortcut%%\]*}"
        _execute_command "$shortcut"
    fi
}

_main "$@"

