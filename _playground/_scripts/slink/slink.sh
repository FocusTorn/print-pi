#!/bin/zsh

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

# Symlink database file
SYMLINK_DB="/home/pi/.symlink-db"

# Database helper functions - REWRITTEN WITHOUT COMMAND SUBSTITUTION
_symlink_db_init() {
    if [[ ! -f "$SYMLINK_DB" ]]; then
        touch "$SYMLINK_DB"
    fi
}

_symlink_db_add() {
    local srcPath="$1"
    local destPath="$2"
    # Use zsh's built-in date formatting instead of command substitution
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    _symlink_db_init
    echo "$timestamp|$srcPath|$destPath" >> "$SYMLINK_DB"
}

_symlink_db_remove() {
    local path="$1"
    
    _symlink_db_init
    
    # Use zsh parameter expansion instead of sed for escaping
    local escaped_path="${path//[][\.*^$()+?{|]/\\}"
    
    # Use zsh built-ins to filter the database
    local temp_file="${SYMLINK_DB}.tmp"
    > "$temp_file"  # Clear temp file
    
    while IFS='|' read -r timestamp src dest; do
        # Check if either source or destination matches the path
        if [[ "$src" != "$path" && "$dest" != "$path" ]]; then
            echo "$timestamp|$src|$dest" >> "$temp_file"
        fi
    done < "$SYMLINK_DB"
    
    mv "$temp_file" "$SYMLINK_DB"
}

_symlink_db_find() {
    local path="$1"
    
    _symlink_db_init
    
    # Use zsh parameter expansion instead of sed for escaping
    local escaped_path="${path//[][\.*^$()+?{|]/\\}"
    
    # Use zsh built-ins to search the database
    while IFS='|' read -r timestamp src dest; do
        if [[ "$src" == "$path" || "$dest" == "$path" ]]; then
            echo "$timestamp|$src|$dest"
        fi
    done < "$SYMLINK_DB"
}

show_help() {
    print -l \
        "slink - Symlink Manager with Database Tracking" \
        "" \
        "USAGE:" \
        "    slink <target> <link>                Create a symlink" \
        "    slink -r|--remove <path>             Remove a symlink" \
        "    slink --list                         List all tracked symlinks" \
        "    slink -h|--help                      Show this help message" \
        "" \
        "DESCRIPTION:" \
        "    slink is a wrapper around 'ln -sf' that tracks symlinks in a database" \
        "    (~/.symlink-db) for easy management and removal. Auto-elevates with" \
        "    sudo only when necessary." \
        "" \
        "OPTIONS:" \
        "    -r, --remove <path>" \
        "        Remove a symlink by target or link path. If the symlink is tracked" \
        "        in the database, it will be removed from both the filesystem and" \
        "        the database. Untracked symlinks can also be removed if the path" \
        "        points to an existing symlink." \
        "" \
        "    --list" \
        "        Display all symlinks currently tracked in the database, showing:" \
        "        - Timestamp of creation" \
        "        - Target path (real file/directory)" \
        "        - Link path (the symlink)" \
        "" \
        "    -h, --help" \
        "        Display this help message and exit." \
        "" \
        "ARGUMENTS:" \
        "    <target>" \
        "        The REAL file or directory (what the symlink will point TO)." \
        "        This is the actual file/directory that must exist." \
        "        Can be relative or absolute path." \
        "" \
        "    <link>" \
        "        Where to CREATE the symlink (the link itself)." \
        "        This is the new path that will point to <target>." \
        "        Can be:" \
        "        - A file path (creates symlink with specified name)" \
        "        - A directory path (creates symlink inside with target's basename)" \
        "" \
        "EXAMPLES:" \
        "    # Create a symlink" \
        "    slink /home/pi/_playground/script.sh /usr/local/bin/script" \
        "          ────────────────────────────    ──────────────────────" \
        "                  TARGET (real file)         LINK (symlink)" \
        "" \
        "    # Create symlink in a directory (auto-names)" \
        "    slink /home/pi/_playground/script.sh /usr/local/bin/" \
        "" \
        "    # List all tracked symlinks" \
        "    slink --list" \
        "" \
        "    # Remove a symlink (by link path)" \
        "    slink -r /usr/local/bin/script" \
        "" \
        "    # Remove a symlink (by target path)" \
        "    slink -r /home/pi/_playground/script.sh" \
        "" \
        "DATABASE:" \
        "    Location: ~/.symlink-db" \
        "    Format: timestamp|target|link" \
        "" \
        "    Each tracked symlink is stored with creation timestamp for reference." \
        "    The database allows removal of symlinks even if you only know the" \
        "    target or link path." \
        "" \
        "NOTES:" \
        "    - Auto-elevates with sudo only when necessary (checks write permissions)" \
        "    - Prompts before overwriting existing files or symlinks" \
        "    - If link is a directory, basename of target is used" \
        "    - Tracks symlinks for easy removal later" \
        "" \
        "REMEMBER:" \
        "    TARGET = real file/directory (what you're linking TO)" \
        "    LINK   = the symlink itself (what you're creating)" \
        "" \
        "EXIT STATUS:" \
        "    0   Success" \
        "    1   Error (missing arguments, failed operation, etc.)" \
        "" \
        "SEE ALSO:" \
        "    ln(1), readlink(1), unlink(1)"
}

slink() { #>
    local remove_flag=false
    local path=""
    
    # Check for help flag
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        show_help
        return 0
    fi
    
    # Check for remove flag
    if [[ "$1" == "-r" || "$1" == "--remove" ]]; then
        remove_flag=true
        path="$2"
    else
        path="$1"
    fi
    
    # If no path provided, show usage
    if [[ -z "$path" ]]; then
        echo "Usage:"
        echo "  slink <target> <link>            # Create symlink"
        echo "  slink -r <path>                  # Remove symlink (by target or link)"
        echo "  slink --list                     # List tracked symlinks"
        echo "  slink -h|--help                  # Show detailed help"
        echo ""
        echo "Remember: TARGET = real file, LINK = symlink"
        return 1
    fi
    
    # Handle list command
    if [[ "$path" == "--list" ]]; then
        echo "=== TRACKED SYMLINKS ==="
        if [[ -f "$SYMLINK_DB" && -s "$SYMLINK_DB" ]]; then
            while IFS='|' read -r timestamp target link; do
                echo "$timestamp: $link → $target"
                echo "              (link)   (target)"
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
            # Use zsh array splitting instead of cut
            local parts=(${(s:|:)db_entry})
            local srcPath="$parts[2]"
            local destPath="$parts[3]"
            
            # Determine which path is the actual symlink (destination)
            local symlink_path=""
            if [[ -L "$destPath" ]]; then
                symlink_path="$destPath"
            elif [[ -L "$srcPath" ]]; then
                symlink_path="$srcPath"
            else
                print_warning "Found database entry but symlink not found: " "$path"
                return 1
            fi
            
            # Check if we need sudo to remove
            local symlink_dir="${symlink_path:h}"
            local use_sudo=false
            
            if [[ ! -w "$symlink_dir" ]]; then
                use_sudo=true
                print_status "Elevated privileges required to remove: " "$symlink_path"
            fi
            
            # Remove the symlink
            local unlink_result=0
            if [[ "$use_sudo" == true ]]; then
                sudo /usr/bin/unlink "$symlink_path" 2>/dev/null || unlink_result=$?
            else
                /usr/bin/unlink "$symlink_path" 2>/dev/null || unlink_result=$?
            fi
            
            if [[ $unlink_result -eq 0 ]]; then
                _symlink_db_remove "$path"
                print_success "Symlink removed and database updated: " "$symlink_path"
            else
                print_error "Failed to remove symlink: " "$symlink_path"
                return 1
            fi
        else
            # Not in database, try to remove anyway
            if [[ -L "$path" ]]; then
                local path_dir="${path:h}"
                local use_sudo=false
                
                if [[ ! -w "$path_dir" ]]; then
                    use_sudo=true
                    print_status "Elevated privileges required to remove: " "$path"
                fi
                
                local unlink_result=0
                if [[ "$use_sudo" == true ]]; then
                    sudo /usr/bin/unlink "$path" 2>/dev/null || unlink_result=$?
                else
                    /usr/bin/unlink "$path" 2>/dev/null || unlink_result=$?
                fi
                
                if [[ $unlink_result -eq 0 ]]; then
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
    local srcPath="$1"  # target
    local destPath="$2" # link
    
    if [[ -z "$destPath" ]]; then
        print_error "Missing link path for symlink creation"
        echo "Usage: slink <target> <link>"
        return 1
    fi
    
    # If link path is an existing directory, append the target filename
    if [[ -d "$destPath" && ! -L "$destPath" ]]; then
        local srcBasename="${srcPath:t}"  # zsh way to get basename
        destPath="${destPath%/}/$srcBasename"
        print_status "Link path is a directory, creating link at: " "$destPath"
    fi
    
    # Check if link path exists (file or symlink)
    if [[ -e "$destPath" || -L "$destPath" ]]; then
        print_warning "Link path already exists: " "$destPath"
        
        # Show what currently exists
        if [[ -L "$destPath" ]]; then
            local currentTarget=$(readlink "$destPath")
            echo "  Currently: symlink → $currentTarget"
        elif [[ -f "$destPath" ]]; then
            echo "  Currently: regular file"
        elif [[ -d "$destPath" ]]; then
            echo "  Currently: directory"
        fi
        
        echo "  New link will point to: $srcPath (target)"
        echo ""
        read -q "REPLY?Overwrite? (y/N): "
        echo ""
        
        if [[ "$REPLY" != "y" ]]; then
            print_status "Operation cancelled"
            return 0
        fi
    fi
    
    # Determine if we need sudo
    local use_sudo=false
    local dest_dir="${destPath:h}"  # Get parent directory
    
    # Check if we can write to the destination directory
    if [[ ! -w "$dest_dir" ]]; then
        use_sudo=true
    fi
    
    # Create the symlink with or without sudo
    if [[ "$use_sudo" == true ]]; then
        print_status "Elevated privileges required to create link at: " "$destPath"
        sudo /usr/bin/ln -sf "$srcPath" "$destPath"
    else
        /usr/bin/ln -sf "$srcPath" "$destPath"
    fi
    
    if [[ -L "$destPath" ]]; then
        if [[ -r "$destPath" && -w "$destPath" ]]; then
            _symlink_db_add "$srcPath" "$destPath"
            print_success "Symlink created and tracked: " "$destPath → $srcPath"
            echo "              (link)   (target)"
        else
            print_error "Symlink exists but is not writable: " "$destPath"
        fi
    else
        print_error "Symlink was not created: " "$destPath"
    fi
} #<

# If script is executed directly (not sourced), run the slink function
# Check if running directly (zsh way)
if [[ "${ZSH_EVAL_CONTEXT}" == "toplevel" ]] || [[ "${(%):-%x}" == "${0}" ]]; then
    slink "$@"
fi