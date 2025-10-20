

# must use full resultions, EG sed would need to be usr/bin/sed


#-->> Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

#--<<
#-->> Print colored output
print_status() {
    echo -e "${BLUE}[INFO] $1${NC} $2"
}

print_success() {
    echo -e "${GREEN}✔ $1${NC} $2"
}

print_warning() {
    echo -e "${YELLOW}❕ $1${NC} $2"
}

print_error() {
    echo -e "${RED}✘ $1${NC} $2"
}

#----<<

srm() { #>
    /usr/bin/sudo rm -rf "$@" 2>/dev/null
} #<

manual_symlinks_ish() { #>
    echo "=== MANUALLY CREATED SYMLINKS ==="
    find /home/pi -type l -not -path "*/.cursor*" -not -path "*/.oh-my-zsh*" -not -path "*/.cursor-server*" -not -path "*/.local*" -not -path "*/.vscode*" -not -path "*/.git*" -not -path "*/node_modules*" 2>/dev/null
} #<



# SLINK =======================================================================>> 

# Symlink database file
SYMLINK_DB="/home/pi/.symlink-db"

# Database helper functions
_symlink_db_init() { #>
    if [[ ! -f "$SYMLINK_DB" ]]; then
        /usr/bin/touch "$SYMLINK_DB"
    fi
} #<

_symlink_db_add() { #>
    local srcPath="$1"
    local destPath="$2"
    local timestamp=$(/usr/bin/date '+%Y-%m-%d %H:%M:%S')
    
    _symlink_db_init
    echo "$timestamp|$srcPath|$destPath" >> "$SYMLINK_DB"
} #<

_symlink_db_remove() { #>
    local path="$1"
    
    _symlink_db_init
    # Escape special characters in path for grep
    local escaped_path=$(printf '%s\n' "$path" | sed 's/[[\.*^$()+?{|]/\\&/g')
    # Remove all entries that match either source or destination
    grep -v "|$escaped_path|" "$SYMLINK_DB" | grep -v "|.*|$escaped_path$" > "${SYMLINK_DB}.tmp" && mv "${SYMLINK_DB}.tmp" "$SYMLINK_DB"
} #<

_symlink_db_find() { #>
    local path="$1"
    
    _symlink_db_init
    # Escape special characters in path for grep
    
    local escaped_path=$(printf '%s\n' "$path" | sed 's/[[\.*^$()+?{|]/\\&/g')
    # local escaped_path=$(printf '%s\n' "$path" | /usr/bin/sed 's/[[\.*^$()+?{|]/\\&/g')
    
    grep -E "\|$escaped_path\||\|.*\|$escaped_path$" "$SYMLINK_DB" 2>/dev/null
} #<

slink() { #>
    local remove_flag=false
    local path=""
    
    # Check for remove flag
    if [[ "$1" == "-r" || "$1" == "--remove" ]]; then
        remove_flag=true
        path="$2"
        echo "Arg: 2, Path: $2"
    else
        path="$1"
        echo "Arg: 1, Path: $1"
    fi
    
    # If no path provided, show usage
    if [[ -z "$path" ]]; then
        echo "Usage:"
        echo "  slink <source> <destination>     # Create symlink"
        echo "  slink -r <path>                  # Remove symlink (by source or destination)"
        echo "  slink --list                     # List tracked symlinks"
        return 1
    fi
    
    # Handle list command
    if [[ "$path" == "--list" ]]; then
        echo "=== TRACKED SYMLINKS ==="
        if [[ -f "$SYMLINK_DB" && -s "$SYMLINK_DB" ]]; then
            while IFS='|' read -r timestamp src dest; do
                echo "$timestamp: $src --> $dest"
            done < "$SYMLINK_DB"
        else
            echo "No tracked symlinks found."
        fi
        return 0
    fi
    
    # Handle removal
    if [[ "$remove_flag" == true ]]; then
        # Find the symlink in our database
        local db_entry=$(_symlink_db_find "$path")
        
        if [[ -n "$db_entry" ]]; then
            # Extract source and destination from database entry
            local srcPath=$(echo "$db_entry" | /cut -d'|' -f2)
            local destPath=$(echo "$db_entry" | /cut -d'|' -f3)
            
            # Determine which path is the actual symlink (destination)
            local symlink_path=""
            if [[ -L "$destPath" ]]; then
                symlink_path="$destPath"
                print_info "" "Using destPath"
            elif [[ -L "$srcPath" ]]; then
                symlink_path="$srcPath"
                print_info "" "Using srcPath"
            else
                print_warning "Found database entry but symlink not found: " "$path"
                return 1
            fi
            
            # Remove the symlink
            if /usr/bin/sudo unlink "$symlink_path" 2>/dev/null; then
                _symlink_db_remove "$path"
                print_success "Symlink removed and database updated: " "$symlink_path"
            else
                print_error "Failed to remove symlink: " "$symlink_path"
                return 1
            fi
        else
            # Not in database, try to remove anyway
            if [[ -L "$path" ]]; then
                if /usr/bin/sudo unlink "$path" 2>/dev/null; then
                    print_success "Symlink removed (not tracked): " "$path"
                else
                    print_error "Failed to remove symlink: " "$path"
                    return 1
                fi
            else
                print_warning "Path is not a symlink: " "$path"
                return 1
            fi
        fi
        return 0
    fi
    
    # Handle creation (original functionality)
    local srcPath="$1"
    local destPath="$2"
    
    if [[ -z "$destPath" ]]; then
        print_error "Missing destination path for symlink creation"
        return 1
    fi
    
    # Create the symlink
    /usr/bin/sudo ln -sf "$srcPath" "$destPath"
    
    if [[ -L "$destPath" ]]; then
        if [[ -r "$destPath" && -w "$destPath" ]]; then
            _symlink_db_add "$srcPath" "$destPath"
            print_success "Symlink created and tracked: " "$srcPath --> $destPath"
        else
            print_error "Symlink exists but is not writable: " "$srcPath --> $destPath"
        fi
    else
        print_error "Symlink was not created: " "$srcPath --> $destPath"
    fi
} #<

#=================================================================================================<<




# ┌────────────────────────────────────────────────────────────────────────────┐
# │                                  REMOVED                                   │
# └────────────────────────────────────────────────────────────────────────────┘

# slink() { #>
#     local srcPath="$1"
#     local destPath="$2"
    
#     # srm "$destPath"
    
#     /usr/bin/sudo ln -sf "$srcPath" "$destPath"
    
#     echo
    
#     if [[ -L "$destPath" ]]; then
#         if [[ -r "$destPath" && -w "$destPath" ]]; then
#             print_success "Symlink is working and writable: " "$srcPath --> $destPath "
#         else
#             print_error "Symlink exists but is not writable: " "$srcPath --> $destPath "
#         fi
#     else
#         print_error "Symlink was not created: " "$srcPath --> $destPath"
#     fi
# } #<



# rslink() { #>
#     local path="$1"
    
#     # Check if it's a symlink BEFORE removing it
#     if [[ -L "$path" ]]; then
        
#         # srm "$path"
#         # sudo rm -rf "$path" 2>/dev/null
        
#         # Try to remove the symlink and capture any errors
#         if ! /usr/bin/sudo unlink "$path" 2>&1; then
#             echo "unlink failed for '$path'"
#         else
#             echo "unlink succeeded for '$path'"
#         fi
        
#         # Debug: Show file existence check
#         echo "Checking if '$path' still exists:"
#         if [[ -e "$path" ]]; then
#             echo "File still exists"
#         else
#             echo "File does not exist"
#         fi
        
#         # Check if it was successfully removed using shell built-in
#         if [[ -e "$path" ]]; then
#             print_error "Symlink removal failed: " "$path"
#         else
#             print_success "Symlink successfully removed: " "$path"
#         fi
#     else
#         if [[ -e "$path" ]]; then
#             print_warning "Path exists but is not a symlink: " "$path"
#         else
#             print_warning "Path does not exist: " "$path"
#         fi
#     fi
# } #<
