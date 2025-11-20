#!/usr/bin/env bash
# ESP-IDF Development Menu (ed)
# Interactive menu for ESP-IDF commands with shortcuts

# Get script directory (resolve symlink if needed)
_ED_SCRIPT="${BASH_SOURCE[0]}"
# Resolve symlink to actual script path
if [ -L "$_ED_SCRIPT" ]; then
    _ED_SCRIPT="$(readlink -f "$_ED_SCRIPT" 2>/dev/null || readlink "$_ED_SCRIPT")"
fi
_ED_DIR="$(cd "$(dirname "$_ED_SCRIPT")" && pwd)"
_ESPIDF_DIR="$(cd "$_ED_DIR/.." && pwd)"

# Colors matching iMenu style
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color / Reset
RED='\033[0;31m'
DIM='\033[2m'
GRAY='\033[0;90m'  # Muted grey for keybindings

# Terminal control functions
_hide_cursor() {
    tput civis >&2 2>/dev/null || printf "\033[?25l" >&2 || true
}

_show_cursor() {
    tput cnorm >&2 2>/dev/null || printf "\033[?25h" >&2 || true
}

_clear_menu() {
    local lines=$1
    for ((i=0; i<lines; i++)); do
        printf "\033[A" >&2 2>/dev/null || tput cuu1 >&2 2>/dev/null || true
        printf "\r" >&2
        tput el >&2 2>/dev/null || printf "\033[K" >&2 2>/dev/null || true
    done
    printf "\r" >&2
}

_read_char() {
    local saved_settings
    saved_settings=$(stty -g 2>/dev/null || echo "")
    stty -echo -icanon -isig 2>/dev/null || true
    IFS= read -rsn1 char 2>/dev/null || char=""
    if [ -n "$saved_settings" ]; then
        stty "$saved_settings" 2>/dev/null || true
    fi
    echo -n "$char"
}

_read_escape() {
    local esc_char
    if IFS= read -rsn1 -t 0.05 esc_char 2>/dev/null; then
        if [[ "$esc_char" == "[" ]]; then
            local next_char
            IFS= read -rsn1 -t 0.05 next_char 2>/dev/null || next_char=""
            echo -n "$next_char"
        else
            echo -n "$esc_char"
        fi
    else
        echo ""
    fi
}

# Select prompt function (iMenu style)
_select_prompt() {
    local message="$1"
    shift
    local choices=("$@")
    
    if [ ${#choices[@]} -eq 0 ]; then
        printf '%bNo choices provided%b\n' "${RED}" "${NC}" >&2
        return 1
    fi
    
    # Display message
    if [ -n "$message" ]; then
        printf '%b%s%b\n' "${BLUE}" "$message" "${NC}" >&2
        printf '\n' >&2
    fi
    
    local num_options=${#choices[@]}
    local current=0
    local selected_idx=$current
    
    _hide_cursor
    
    local menu_lines=$((num_options + 2))  # Options + blank + keybindings
    
    while true; do
        # Display menu options
        for ((i=0; i<num_options; i++)); do
            local prefix="  "
            if [ $i -eq $current ]; then
                prefix="${CYAN}❯${NC} "
            fi
            printf '%b%s\n' "$prefix" "${choices[i]}" >&2
        done
        printf '\n' >&2  # Blank line
        
        # Display keybindings
        printf '%b↑/↓: navigate  Enter/Space: select  ESC: cancel%b\n' "${GRAY}" "${NC}" >&2
        
        # Read input
        local key
        key=$(_read_char)
        
        if [ "$key" = $'\n' ] || [ "$key" = $'\r' ] || [ -z "$key" ]; then
            # Enter pressed
            selected_idx=$current
            break
        fi
        
        case "$key" in
            " ")  # Space selects
                selected_idx=$current
                break
                ;;
            $'\x1b')  # Escape sequence
                local arrow
                arrow=$(_read_escape)
                case "$arrow" in
                    "A")  # Up arrow
                        if [ $current -gt 0 ]; then
                            ((current--))
                        fi
                        ;;
                    "B")  # Down arrow
                        if [ $current -lt $((num_options - 1)) ]; then
                            ((current++))
                        fi
                        ;;
                    *)  # ESC pressed (no arrow)
                        _show_cursor
                        _clear_menu $menu_lines
                        return 1
                        ;;
                esac
                ;;
        esac
        
        _clear_menu $menu_lines
    done
    
    _show_cursor
    
    # Output selected choice
    echo "${choices[$selected_idx]}"
    return 0
}

# Command definitions with shortcuts
declare -A ESPIDF_COMMANDS=(
    ["gi"]="get_idf_custom - Enters the s3 specific venv"
    ["cd"]="change-project - Navigate to project directory"
    ["b"]="idf.py build - Build the current project"
    ["f"]="idf.py flash - Flash to device"
    ["ms"]="idf.py monitor - Monitor serial output"
    ["fm"]="idf.py flash monitor - Flash and monitor"
    ["c"]="idf.py fullclean - Clean build artifacts"
    ["con"]="idf.py menuconfig - Configure project"
    ["st"]="idf.py set-target esp32s3 - Set target to ESP32-S3"
    ["v"]="idf.py --version - Show ESP-IDF version"
    ["new"]="new-project.sh - Create new ESP-IDF project"
    ["dp"]="detect-port.sh - Auto-detect ESP32 board port"
)

# Find ESP-IDF project directory (look for CMakeLists.txt)
_find_project_dir() {
    local current_dir="$PWD"
    
    # Check if we're in a project directory (has CMakeLists.txt)
    if [ -f "$current_dir/CMakeLists.txt" ]; then
        echo "$current_dir"
        return 0
    fi
    
    # Check if we're in a project's main directory
    if [ -f "$current_dir/../CMakeLists.txt" ]; then
        echo "$(cd "$current_dir/.." && pwd)"
        return 0
    fi
    
    # Check if we're in the espidf/projects directory
    if [[ "$current_dir" == *"/espidf/projects"* ]] && [ -d "$current_dir" ]; then
        # If we're in projects/ but not in a specific project, list projects
        return 1
    fi
    
    # Try to find project from current location
    local check_dir="$current_dir"
    while [ "$check_dir" != "/" ]; do
        if [ -f "$check_dir/CMakeLists.txt" ]; then
            echo "$check_dir"
            return 0
        fi
        check_dir="$(dirname "$check_dir")"
    done
    
    return 1
}

# List available projects
_list_projects() {
    local projects_dir="$_ESPIDF_DIR/projects"
    local projects=()
    
    if [ ! -d "$projects_dir" ]; then
        echo "No projects directory found at: $projects_dir" >&2
        return 1
    fi
    
    # Check if glob matches anything
    local has_projects=false
    for dir in "$projects_dir"/*; do
        if [ -d "$dir" ] && [ -f "$dir/CMakeLists.txt" ]; then
            projects+=("$(basename "$dir")")
            has_projects=true
        fi
    done
    
    if [ "$has_projects" = false ] || [ ${#projects[@]} -eq 0 ]; then
        echo "No projects found in $projects_dir" >&2
        return 1
    fi
    
    printf '%s\n' "${projects[@]}" | sort
}

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
            # Source the custom get_idf script (works when ed is a function)
            if [ -f "$_ESPIDF_DIR/_scripts/get_idf_custom.sh" ]; then
                source "$_ESPIDF_DIR/_scripts/get_idf_custom.sh"
            else
                echo "Error: get_idf_custom.sh not found at $_ESPIDF_DIR/_scripts/get_idf_custom.sh" >&2
                return 1
            fi
            ;;
        "cd")
            # Change to project directory
            if [ ! -d "$_ESPIDF_DIR/projects" ]; then
                echo "Error: Projects directory not found at $_ESPIDF_DIR/projects" >&2
                return 1
            fi
            
            local projects
            readarray -t projects < <(_list_projects 2>/dev/null)
            local list_status=$?
            if [ $list_status -ne 0 ] || [ ${#projects[@]} -eq 0 ]; then
                echo "No projects found in $_ESPIDF_DIR/projects" >&2
                return 1
            fi
            
            local selected
            selected=$(_select_prompt "Select project:" "${projects[@]}")
            if [ -n "$selected" ]; then
                local project_dir="$_ESPIDF_DIR/projects/$selected"
                if [ ! -d "$project_dir" ]; then
                    echo "Error: Project directory not found: $project_dir" >&2
                    return 1
                fi
                # Change directory - this only works if script is sourced, not executed
                if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
                    # Script is executed, not sourced - print command to run
                    echo "Run this command to change to project directory:"
                    echo "cd $project_dir"
                    echo "Then run 'ed gi' to activate ESP-IDF environment"
                else
                    # Script is sourced - can actually change directory
                    cd "$project_dir" 2>/dev/null || {
                        echo "Error: Cannot change to $project_dir" >&2
                        return 1
                    }
                    echo "Changed to: $project_dir"
                    echo "Run 'ed gi' to activate ESP-IDF environment"
                fi
            fi
            ;;
        "new")
            # Run new-project script
            "$_ESPIDF_DIR/_scripts/new-project.sh"
            ;;
        "dp")
            # Run detect-port script
            "$_ESPIDF_DIR/_scripts/detect-port.sh"
            ;;
        *)
            # Run idf.py commands (requires get_idf to be run first and project directory)
            if ! command -v idf.py &> /dev/null; then
                echo "⚠️  ESP-IDF environment not activated. Run 'ed gi' first or 'get_idf'" >&2
                return 1
            fi
            
            # Check if we're in a project directory
            local project_dir
            project_dir=$(_find_project_dir)
            if [ $? -ne 0 ] || [ -z "$project_dir" ]; then
                echo "⚠️  Not in an ESP-IDF project directory" >&2
                echo "   Change to project directory first or use 'ed cd' to navigate" >&2
                return 1
            fi
            
            # Change to project directory if needed
            if [ "$project_dir" != "$PWD" ]; then
                cd "$project_dir" || {
                    echo "Error: Cannot change to $project_dir" >&2
                    return 1
                }
            fi
            
            eval "$actual_cmd"
            ;;
    esac
}

# Build menu items
_build_menu_items() {
    # Find longest shortcut length (including brackets)
    local max_bracket_len=0
    for shortcut in "${!ESPIDF_COMMANDS[@]}"; do
        local bracket_str="[$shortcut]"
        local len=${#bracket_str}
        if [ $len -gt $max_bracket_len ]; then
            max_bracket_len=$len
        fi
    done
    
    # Build items with aligned descriptions
    local items=()
    for shortcut in "${!ESPIDF_COMMANDS[@]}"; do
        local desc="${ESPIDF_COMMANDS[$shortcut]}"
        # Pad shortcut bracket to max length + 1 space
        local bracket_str="[$shortcut]"
        local padding_len=$((max_bracket_len + 1 - ${#bracket_str}))
        local padding=$(printf '%*s' $padding_len '')
        items+=("$bracket_str$padding$desc")
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
    selected=$(_select_prompt "ESP-IDF Development Commands" "${menu_items[@]}")
    
    if [ -n "$selected" ]; then
        # Extract shortcut from selection (format: [gi] description)
        local shortcut="${selected#\[}"
        shortcut="${shortcut%%\]*}"
        _execute_command "$shortcut"
    fi
}

_main "$@"

