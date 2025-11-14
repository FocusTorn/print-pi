#!/bin/bash

# manage-secrets.sh - Secrets management utility
# Stores secrets in plain text (with secure permissions) and creates encrypted backups

set -e

# Source iMenu for interactive prompts
source "/home/pi/_playground/_dev/packages/_utilities/iMenu/iMenu.sh"

# Generic secrets file (not HA-specific)
SECRETS_FILE="${HOME}/.secrets"
SECRETS_BACKUP_DIR="${HOME}/.secrets-backups"
SECRETS_ENCRYPTED_BACKUP="${SECRETS_BACKUP_DIR}/secrets-$(date +%Y%m%d-%H%M%S).encrypted"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { #>
    echo -e "${CYAN}ℹ️  $1${NC}"
} #<
print_success() { #>
    echo -e "${GREEN}✅ $1${NC}"
} #<
print_error() { #>
    echo -e "${RED}❌ $1${NC}"
} #<
print_warning() { #>
    echo -e "${YELLOW}⚠️  $1${NC}"
} #<

check_gpg() { #>
    if ! command -v gpg &> /dev/null; then
        print_error "GPG is not installed. Install it with: sudo apt install gnupg"
        exit 1
    fi
} #<

init_secrets() { #>
    # Check if .secrets exists as a directory (from old version) and remove it
    if [ -d "$SECRETS_FILE" ]; then
        print_warning "Found existing directory: $SECRETS_FILE"
        print_info "This appears to be from an older version."
        
        # Check if we can write to it (if not, will need sudo)
        if [ ! -w "$SECRETS_FILE" ]; then
            print_info "Directory requires sudo to remove. Using sudo..."
            USE_SUDO="sudo"
        else
            USE_SUDO=""
        fi
        
        # Try to remove files inside first
        if [ -n "$(ls -A "$SECRETS_FILE" 2>/dev/null)" ]; then
            print_info "Removing contents..."
            $USE_SUDO chmod -R u+w "$SECRETS_FILE" 2>/dev/null
            $USE_SUDO rm -rf "${SECRETS_FILE:?}"/* "${SECRETS_FILE:?}"/.* 2>/dev/null
        fi
        
        # Now remove the directory itself
        print_info "Removing directory..."
        $USE_SUDO rmdir "$SECRETS_FILE" 2>/dev/null || {
            print_error "Could not remove directory: $SECRETS_FILE"
            print_info "Please manually remove it with: sudo rm -rf $SECRETS_FILE"
            exit 1
        }
    fi
    
    if [ -f "$SECRETS_FILE" ]; then
        print_warning "Secrets file already exists: $SECRETS_FILE"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Cancelled"
            return
        fi
        rm -f "$SECRETS_FILE"
    fi
    
    print_info "Creating new secrets file..."
    print_info "Enter your secrets (one per line, format: KEY=value)"
    print_info "Press Ctrl+D when done, or type 'END' on a new line"
    echo
    
    # Create temporary file in /tmp (not in home directory)
    TEMP_FILE=$(mktemp /tmp/secrets.XXXXXX)
    
    cat > "$TEMP_FILE" << 'EOF'
# Secrets Configuration File
# Format: KEY=value (one per line)
# Lines starting with # are comments

# Home Assistant Long-Lived Access Token
# Get this from: HA UI > Profile > Long-Lived Access Tokens
# HA_TOKEN=your-token-here

# Add other secrets below:
# API_KEY=your-api-key
# PASSWORD=your-password
# SERVICE_TOKEN=your-service-token
EOF
    
    # Let user edit it
    ${EDITOR:-nano} "$TEMP_FILE"
    
    # Move to final location with secure permissions
    mv "$TEMP_FILE" "$SECRETS_FILE" || {
        print_error "Failed to create secrets file. Check permissions."
        rm -f "$TEMP_FILE"
        exit 1
    }
    chmod 600 "$SECRETS_FILE"
    
    print_success "Secrets file created: $SECRETS_FILE"
    print_info "File permissions set to 600 (read/write for owner only)"
    print_info "Use 'backup' command to create encrypted backups"
} #<

edit_secrets() { #>
    if [ ! -f "$SECRETS_FILE" ]; then
        print_error "Secrets file not found: $SECRETS_FILE"
        print_info "Run '$0 init' to create it"
        exit 1
    fi
    
    # Edit the plain text file directly
    ${EDITOR:-nano} "$SECRETS_FILE"
    
    # Ensure secure permissions
    chmod 600 "$SECRETS_FILE"
    
    print_success "Secrets updated"
    print_info "Use 'backup' command to create encrypted backup"
} #<

view_secrets() { #>
    if [ ! -f "$SECRETS_FILE" ]; then
        print_error "Secrets file not found: $SECRETS_FILE"
        exit 1
    fi
    
    # Display the plain text file
    cat "$SECRETS_FILE"
} #<

# List encrypted backups
list_backups() { #>
    if [ ! -d "$SECRETS_BACKUP_DIR" ] || [ -z "$(ls -A "$SECRETS_BACKUP_DIR" 2>/dev/null)" ]; then
        print_info "No encrypted backups found in: $SECRETS_BACKUP_DIR"
        return
    fi
    
    echo -e "${CYAN}Encrypted Backups:${NC}"
    echo
    
    for backup in "$SECRETS_BACKUP_DIR"/*.encrypted; do
        if [ -f "$backup" ]; then
            BACKUP_NAME=$(basename "$backup")
            BACKUP_SIZE=$(du -sh "$backup" | cut -f1)
            BACKUP_DATE=$(stat -c %y "$backup" 2>/dev/null | cut -d' ' -f1)
            echo -e "  ${GREEN}${BACKUP_NAME}${NC} (${BACKUP_SIZE}) - ${BACKUP_DATE}"
        fi
    done
    echo
} #<

export_secrets() { #>
    if [ ! -f "$SECRETS_FILE" ]; then
        print_error "Secrets file not found: $SECRETS_FILE"
        exit 1
    fi
    
    # Read plain text file and export variables
    grep -v '^#' "$SECRETS_FILE" | \
        grep -v '^$' | \
        while IFS='=' read -r key value; do
            # Remove quotes if present
            value=$(echo "$value" | sed "s/^['\"]//;s/['\"]$//")
            export "$key=$value"
        done
} #<

backup_secrets() { #>
    check_gpg
    
    if [ ! -f "$SECRETS_FILE" ]; then
        print_error "Secrets file not found: $SECRETS_FILE"
        exit 1
    fi
    
    mkdir -p "$SECRETS_BACKUP_DIR"
    
    # Create encrypted backup
    print_info "Creating encrypted backup..."
    
    # Try cached password first, then prompt
    PASSWORD="${HA_SECRETS_PASSWORD:-}"
    if [ -z "$PASSWORD" ]; then
        # Check if interactive
        if [ -t 0 ] && [ -t 1 ]; then
            PASSWORD=$(iprompt_run "password_result" "password" "ℹ️  Enter password to encrypt backup:")
        else
            print_error "Password required for backup. Set HA_SECRETS_PASSWORD or run interactively."
            exit 1
        fi
        
        if [ -z "$PASSWORD" ]; then
            print_error "Password is required"
            exit 1
        fi
        # Cache password for session
        export HA_SECRETS_PASSWORD="$PASSWORD"
    else
        print_info "Using cached password from session"
    fi
    
    # Encrypt the secrets file
    BACKUP_FILE="${SECRETS_BACKUP_DIR}/secrets-$(date +%Y%m%d-%H%M%S).encrypted"
    echo -n "$PASSWORD" | gpg --batch --yes --passphrase-fd 0 --pinentry-mode loopback \
        --symmetric --cipher-algo AES256 --compress-algo 1 \
        --output "$BACKUP_FILE" "$SECRETS_FILE"
    
    print_success "Encrypted backup created: $BACKUP_FILE"
    print_info "You can copy this to:"
    print_info "  - USB drive"
    print_info "  - Cloud storage (Dropbox, Google Drive, etc.)"
    print_info "  - Another computer"
    print_info "  - Password manager (as a secure note)"
} #<

restore_secrets() { #>
    check_gpg
    
    if [ $# -eq 0 ]; then
        print_error "Usage: $0 restore <backup-file>"
        exit 1
    fi
    
    BACKUP_FILE="$1"
    
    if [ ! -f "$BACKUP_FILE" ]; then
        print_error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi
    
    print_warning "This will overwrite your current secrets file!"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cancelled"
        return
    fi
    
    # Decrypt backup file
    print_info "Decrypting backup..."
    
    # Try cached password first, then prompt
    PASSWORD="${HA_SECRETS_PASSWORD:-}"
    if [ -z "$PASSWORD" ]; then
        # Check if interactive
        if [ -t 0 ] && [ -t 1 ]; then
            PASSWORD=$(iprompt_run "password_result" "password" "ℹ️  Enter password to decrypt backup:")
        else
            print_error "Password required for restore. Set HA_SECRETS_PASSWORD or run interactively."
            exit 1
        fi
        
        if [ -z "$PASSWORD" ]; then
            print_error "Password is required"
            exit 1
        fi
        # Cache password for session
        export HA_SECRETS_PASSWORD="$PASSWORD"
    else
        print_info "Using cached password from session"
    fi
    
    # Decrypt to temporary file first
    TEMP_FILE=$(mktemp)
    echo -n "$PASSWORD" | gpg --batch --yes --passphrase-fd 0 --pinentry-mode loopback \
        --quiet --decrypt "$BACKUP_FILE" > "$TEMP_FILE" 2>/dev/null || {
        print_error "Failed to decrypt. Wrong password?"
        rm -f "$TEMP_FILE"
        exit 1
    }
    
    # Move to final location with secure permissions
    mv "$TEMP_FILE" "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
    
    print_success "Secrets restored from: $BACKUP_FILE"
} #<

show_help() { #>
    cat << EOF
${CYAN}Secrets Management Utility${NC}

Usage: $0 <command> [options]

Commands:
    init              Create a new plain text secrets file
    edit              Edit existing secrets (plain text file)
    view              View secrets (plain text file)
    export            Export secrets as environment variables
    backup            Create an encrypted backup of secrets
    restore <file>    Restore secrets from an encrypted backup
    help              Show this help message

Examples:
    $0 init                    # Create new secrets file
    $0 edit                    # Edit secrets
    $0 view                    # View secrets (to verify)
    $0 backup                  # Create encrypted backup
    $0 restore ~/backup.encrypted  # Restore from encrypted backup

Integration with ha-helper.sh:
    Add this to your ~/.bashrc or ~/.zshrc:
        source <($HOME/_playground/_scripts/manage-secrets.sh export)
    
    Or manually load before using ha commands:
        eval "\$($HOME/_playground/_scripts/manage-secrets.sh export)"
        ha reload core

Security Notes:
    • Secrets file is stored in plain text with secure permissions (600)
    • Only backups are encrypted with GPG (AES256)
    • Never commit the secrets file to Git (add to .gitignore)
    • Store encrypted backups in multiple locations (3-2-1 rule)
    • Use a strong password for encrypted backups
    • Consider using a password manager for the backup encryption password

EOF
} #<

# Main command handler
if [ $# -eq 0 ]; then
    # No command provided - show interactive menu
    COMMAND_OPTIONS=(
        "Initialize secrets file"
        "Edit secrets"
        "View secrets"
        "Export secrets to environment"
        "Create encrypted backup"
        "List encrypted backups"
        "Restore secrets from backup"
        "Show help"
    )
    
    IMENU_HINT="Use ↑↓ to navigate, Enter to select"
    choice_idx=$(imenu_select "action" "What would you like to do?" \
        "${COMMAND_OPTIONS[@]}")
    
    case "$choice_idx" in
        0)
            init_secrets
            ;;
        1)
            edit_secrets
            ;;
        2)
            view_secrets
            ;;
        3)
            export_secrets
            ;;
        4)
            backup_secrets
            ;;
        5)
            list_backups
            ;;
        6)
            print_info "Enter path to backup file:"
            backup_path=$(imenu_text "backup_path" "Backup file path:")
            if [ -n "$backup_path" ]; then
                restore_secrets "$backup_path"
            else
                print_error "No backup path provided"
                exit 1
            fi
            ;;
        7)
            show_help
            ;;
        *)
            print_error "Invalid selection"
            exit 1
            ;;
    esac
else
    # Command provided - use traditional command-line interface
    case "$1" in
        init)
            init_secrets
            ;;
        edit)
            edit_secrets
            ;;
        view)
            view_secrets
            ;;
        export)
            export_secrets
            ;;
        backup)
            backup_secrets
            ;;
        list-backups|list)
            list_backups
            ;;
        restore)
            restore_secrets "$2"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            echo
            show_help
            exit 1
            ;;
    esac
fi

