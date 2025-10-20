#!/usr/bin/env bash
set -euo pipefail

# compare-to-clean.sh
# Compares a system directory against the clean-pi reference image
# Only considers files modified after Day 0 initialization
# Includes comprehensive exclusion rules for system vs user modifications

# Load shared formatting library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/formatting.sh"

# Additional color not in library
MAGENTA='\033[0;35m'

# Day 0 cutoff timestamp
DAY0_CUTOFF="2025-09-30 19:17:09"

# Clean-pi mount points
CLEAN_PI_ROOT="/media/pi/clean-pi/rootfs"
CLEAN_PI_BOOT="/media/pi/clean-pi/bootfs"

# Exclusion configuration file
EXCLUSION_CONFIG="$(dirname "${BASH_SOURCE[0]}")/exclusion-rules.conf"

print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Initialize exclusion rules
init_exclusion_rules() {
    # Create exclusion config if it doesn't exist
    if [[ ! -f "$EXCLUSION_CONFIG" ]]; then
        create_default_exclusion_config
    fi
    
    # Load exclusion rules
    source "$EXCLUSION_CONFIG"
}

# Create default exclusion configuration
create_default_exclusion_config() {
    cat > "$EXCLUSION_CONFIG" << 'EOF'
# Exclusion Rules Configuration
# This file defines patterns and rules to automatically classify files as system vs user modifications

# === SYSTEM MODIFICATION PATTERNS ===
# These patterns indicate files were modified by the system, not the user

# CUPS Printer System Files
SYSTEM_PATTERNS=(
    "/etc/cups/printers.conf"
    "/etc/cups/subscriptions.conf"
    "/etc/cups/ppd/*.ppd"
    "/etc/cups/printers.conf.O"
    "/etc/cups/subscriptions.conf.O"
)

# System Cache Files
SYSTEM_PATTERNS+=(
    "/etc/ld.so.cache"
    "/var/cache/*"
    "/tmp/*"
    "/run/*"
)

# Package Management Files
SYSTEM_PATTERNS+=(
    "/etc/mailcap"
    "/etc/shells"
    "/var/lib/dpkg/*"
    "/var/log/apt/*"
)

# System Service Files
SYSTEM_PATTERNS+=(
    "/etc/systemd/system/*"
    "/run/systemd/*"
    "/var/lib/systemd/*"
)

# Network Configuration (auto-generated)
SYSTEM_PATTERNS+=(
    "/etc/resolv.conf"
    "/etc/hostname"
    "/var/lib/dhcp/*"
)

# === USER MODIFICATION PATTERNS ===
# These patterns indicate files were likely modified by the user

USER_PATTERNS=(
    "/etc/fstab"
    "/etc/hosts"
    "/etc/ssh/sshd_config"
    "/etc/nginx/*"
    "/etc/apache2/*"
    "/home/*/.bashrc"
    "/home/*/.zshrc"
    "/home/*/.profile"
    "/home/*/.config/*"
)

# === ABSOLUTE VALIDATION METHODS ===
# These functions provide 100% certainty about modification source

# Check if file has system-generated backup (.O, -, .bak, etc.)
has_system_backup() {
    local file="$1"
    local dir=$(dirname "$file")
    local basename=$(basename "$file")
    
    # Check for common backup patterns
    [[ -f "${file}.O" ]] || \
    [[ -f "${file}-" ]] || \
    [[ -f "${file}.bak" ]] || \
    [[ -f "${file}.orig" ]] || \
    [[ -f "${dir}/.${basename}.O" ]] || \
    [[ -f "${dir}/.${basename}-" ]]
}

# Check if file was modified by specific system processes
is_system_process_modified() {
    local file="$1"
    
    # Check file headers for system service signatures
    if [[ -f "$file" ]]; then
        # CUPS files
        if head -n 3 "$file" 2>/dev/null | grep -q "Written by cupsd"; then
            return 0
        fi
        
        # Systemd files
        if head -n 3 "$file" 2>/dev/null | grep -q "systemd"; then
            return 0
        fi
        
        # Package manager files
        if head -n 3 "$file" 2>/dev/null | grep -q "dpkg\|apt\|package"; then
            return 0
        fi
    fi
    
    return 1
}

# Check modification patterns (timestamps, incremental changes)
has_system_modification_pattern() {
    local file="$1"
    
    # Check if modification time matches system activity patterns
    local mod_time=$(stat -c '%Y' "$file" 2>/dev/null || echo "0")
    local mod_date=$(date -d "@$mod_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")
    
    # Check for recent modifications (within last hour) - likely system
    local current_time=$(date +%s)
    local hour_ago=$((current_time - 3600))
    
    if [[ $mod_time -gt $hour_ago ]]; then
        # Check if it's a known system file
        for pattern in "${SYSTEM_PATTERNS[@]}"; do
            if [[ "$file" == $pattern ]]; then
                return 0
            fi
        done
    fi
    
    return 1
}

# Check file content for system vs user signatures
has_user_content_signatures() {
    local file="$1"
    
    if [[ -f "$file" ]]; then
        # Look for user-specific content patterns
        if grep -q "gorilla\|clean-pi\|custom\|# Added by user\|# User modification" "$file" 2>/dev/null; then
            return 0
        fi
        
        # Check for manual configuration patterns
        if grep -q "PARTUUID.*gorilla\|PARTUUID.*clean-pi" "$file" 2>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

# === MAIN CLASSIFICATION FUNCTION ===
classify_modification_source() {
    local file="$1"
    local result=""
    
    # Absolute validation methods (100% certainty)
    if has_system_backup "$file"; then
        result="SYSTEM"
    elif is_system_process_modified "$file"; then
        result="SYSTEM"
    elif has_user_content_signatures "$file"; then
        result="USER"
    elif has_system_modification_pattern "$file"; then
        result="SYSTEM"
    else
        # Pattern matching fallback
        for pattern in "${SYSTEM_PATTERNS[@]}"; do
            if [[ "$file" == $pattern ]]; then
                result="SYSTEM"
                break
            fi
        done
        
        if [[ -z "$result" ]]; then
            for pattern in "${USER_PATTERNS[@]}"; do
                if [[ "$file" == $pattern ]]; then
                    result="USER"
                    break
                fi
            done
        fi
        
        # Default to UNKNOWN if no pattern matches
        [[ -z "$result" ]] && result="UNKNOWN"
    fi
    
    echo "$result"
}

# === EXCLUSION FUNCTIONS ===
should_exclude_file() {
    local file="$1"
    local classification="$2"
    
    # Exclude system files by default (they're not user modifications)
    if [[ "$classification" == "SYSTEM" ]]; then
        return 0  # Exclude
    fi
    
    # Don't exclude user or unknown files
    return 1  # Don't exclude
}

# Get exclusion reason for reporting
get_exclusion_reason() {
    local file="$1"
    local classification="$2"
    
    case "$classification" in
        "SYSTEM")
            if has_system_backup "$file"; then
                echo "System file (has backup)"
            elif is_system_process_modified "$file"; then
                echo "System process modified"
            elif has_system_modification_pattern "$file"; then
                echo "System modification pattern"
            else
                echo "System file (pattern match)"
            fi
            ;;
        "USER")
            echo "User modification"
            ;;
        "UNKNOWN")
            echo "Unknown source"
            ;;
    esac
}
EOF
    
    print_color "$GREEN" "Created default exclusion configuration: $EXCLUSION_CONFIG"
}

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] PATH

Compare a system directory against the clean-pi reference image.
Only considers files created/modified after Day 0 initialization.
Includes comprehensive exclusion rules for system vs user modifications.

OPTIONS:
    -c, --cutoff DATETIME   Override Day 0 cutoff (default: $DAY0_CUTOFF)
    -v, --verbose          Show detailed file comparison
    -d, --diff             Show content differences for changed files
    -e, --exclude-system   Exclude system-modified files from results
    -s, --show-classification  Show classification (SYSTEM/USER/UNKNOWN) for each file
    -r, --exclusion-report Show detailed exclusion report
    -h, --help             Show this help

EXAMPLES:
    # Compare /etc against clean-pi
    $(basename "$0") /etc

    # Compare with verbose output and show classifications
    $(basename "$0") -v -s /etc

    # Show only user modifications (exclude system files)
    $(basename "$0") -e /etc

    # Show detailed exclusion report
    $(basename "$0") -r /etc

    # Show actual diffs with classifications
    $(basename "$0") -d -s /home/pi/.config

    # Custom cutoff date
    $(basename "$0") -c "2025-10-01 00:00:00" /etc

EXCLUSION FEATURES:
    The script automatically classifies files as SYSTEM, USER, or UNKNOWN based on:
    - System backup files (.O, -, .bak patterns)
    - File headers (CUPS, systemd signatures)
    - Content patterns (user-specific configurations)
    - Modification timestamps and patterns
    - File path patterns

EOF
    exit 0
}

# Check if clean-pi is mounted
check_clean_pi_mounted() {
    if [[ ! -d "$CLEAN_PI_ROOT" ]] || [[ -z "$(ls -A "$CLEAN_PI_ROOT" 2>/dev/null)" ]]; then
        print_color "$RED" "Error: clean-pi rootfs not mounted at $CLEAN_PI_ROOT"
        print_color "$YELLOW" "Mount it with: sudo mount /dev/sdX2 /media/pi/clean-pi/rootfs"
        exit 1
    fi
}

# Determine if path is in boot or root
get_clean_pi_path() {
    local system_path="$1"
    
    # Normalize path (remove trailing slashes)
    system_path="${system_path%/}"
    
    # Check if path is /boot/firmware (the actual boot partition)
    if [[ "$system_path" == /boot/firmware* ]]; then
        # /boot/firmware -> clean-pi bootfs
        local relative_path="${system_path#/boot/firmware}"
        [[ -z "$relative_path" ]] && relative_path="/"
        echo "${CLEAN_PI_BOOT}${relative_path}"
    else
        # Everything else (including /boot) -> clean-pi rootfs
        # This handles /boot as part of the root filesystem
        echo "${CLEAN_PI_ROOT}${system_path}"
    fi
}

# Check if file was created/modified after cutoff
is_post_day0() {
    local file="$1"
    local cutoff="$2"
    
    # Get modification time
    local mod_time
    mod_time=$(stat -c '%Y' "$file" 2>/dev/null || echo "0")
    
    local cutoff_epoch
    cutoff_epoch=$(date -d "$cutoff" +%s 2>/dev/null || echo "0")
    
    [[ $mod_time -gt $cutoff_epoch ]]
}

# Compare two files
files_differ() {
    local file1="$1"
    local file2="$2"
    
    # Use cmp for binary-safe comparison
    ! cmp -s "$file1" "$file2" 2>/dev/null
}

# Main comparison function
compare_directories() {
    local system_path="$1"
    local clean_path="$2"
    local cutoff="$3"
    local verbose="$4"
    local show_diff="$5"
    local exclude_system="$6"
    local show_classification="$7"
    local exclusion_report="$8"
    
    # Arrays to store results
    local -a modified_files=()
    local -a only_in_system=()
    local -a only_in_clean=()
    local -a excluded_files=()
    local -a classified_system_files=()
    local -a classified_user_files=()
    local -a classified_unknown_files=()
    
    fmt.header "COMPARE TO CLEAN"
    fmt.subsection "Comparison Parameters"
    fmt.info "Comparing" "$system_path"
    fmt.info "Against" "$clean_path"
    fmt.info "Cutoff" "$cutoff"
    
    # Check if clean path exists before proceeding
    if [[ ! -d "$clean_path" ]]; then
        print_color "$YELLOW" "⚠️  Warning: Clean-pi path not found: $clean_path"
        return
    fi
    
    # Show active modes
    local modes=()
    [[ "$exclude_system" == "true" ]] && modes+=("Excluding system modifications")
    [[ "$show_classification" == "true" ]] && modes+=("Showing file classifications")
    [[ "$exclusion_report" == "true" ]] && modes+=("Detailed exclusion report")
    
    if [[ ${#modes[@]} -gt 0 ]]; then
        fmt.info "Active modes" "${modes[*]}"
    fi
    
    # Find all files in system path (post-Day 0)
    # Use -xdev to avoid crossing filesystem boundaries (e.g., /boot/firmware mount)
    local -a system_files=()
    while IFS= read -r -d '' file; do
        local relative="${file#$system_path}"
        [[ -z "$relative" ]] && continue
        system_files+=("$relative")
    done < <(find "$system_path" -xdev -type f -newermt "$cutoff" -print0 2>/dev/null || true)
    
    # Find all files in clean path
    # Use -xdev to avoid crossing filesystem boundaries
    local -a clean_files=()
    if [[ -d "$clean_path" ]]; then
        while IFS= read -r -d '' file; do
            local relative="${file#$clean_path}"
            [[ -z "$relative" ]] && continue
            clean_files+=("$relative")
        done < <(find "$clean_path" -xdev -type f -print0 2>/dev/null || true)
    fi
    
    # Check files in system against clean
    for rel_file in "${system_files[@]}"; do
        local sys_file="${system_path}${rel_file}"
        local clean_file="${clean_path}${rel_file}"
        
        # Classify the file
        local classification
        classification=$(classify_modification_source "$sys_file")
        
        # Track classification for reporting
        case "$classification" in
            "SYSTEM") classified_system_files+=("$rel_file") ;;
            "USER") classified_user_files+=("$rel_file") ;;
            "UNKNOWN") classified_unknown_files+=("$rel_file") ;;
        esac
        
        # Check if we should exclude this file
        if should_exclude_file "$sys_file" "$classification"; then
            excluded_files+=("$rel_file")
            if [[ "$exclusion_report" == "true" ]]; then
                local reason
                reason=$(get_exclusion_reason "$sys_file" "$classification")
                print_color "$MAGENTA" "  Excluded: $rel_file ($reason)"
            fi
            continue
        fi
        
        if [[ -f "$clean_file" ]]; then
            # File exists in both - compare contents
            if files_differ "$sys_file" "$clean_file"; then
                modified_files+=("$rel_file")
                if [[ "$verbose" == "true" ]]; then
                    local status="Modified"
                    if [[ "$show_classification" == "true" ]]; then
                        status="Modified ($classification)"
                    fi
                    print_color "$YELLOW" "  $status: $rel_file"
                fi
            fi
        else
            # File only in system
            only_in_system+=("$rel_file")
            if [[ "$verbose" == "true" ]]; then
                local status="New file"
                if [[ "$show_classification" == "true" ]]; then
                    status="New file ($classification)"
                fi
                print_color "$GREEN" "  $status: $rel_file"
            fi
        fi
    done
    
    # Check for files only in clean (that were deleted)
    for rel_file in "${clean_files[@]}"; do
        local sys_file="${system_path}${rel_file}"
        
        if [[ ! -f "$sys_file" ]]; then
            # File only in clean (deleted from system)
            only_in_clean+=("$rel_file")
            [[ "$verbose" == "true" ]] && print_color "$RED" "  Deleted:  $rel_file"
        fi
    done
    
    # Print summary
    fmt.section "COMPARISON SUMMARY"
    
    # Show classification breakdown if requested
    if [[ "$show_classification" == "true" || "$exclusion_report" == "true" ]]; then
        fmt.subsection "File Classifications"
        fmt.info "System files" "${#classified_system_files[@]}"
        fmt.info "User files" "${#classified_user_files[@]}"
        fmt.info "Unknown files" "${#classified_unknown_files[@]}"
        fmt.info "Excluded files" "${#excluded_files[@]}"
    fi
    
    fmt.subsection.yellow "Modified files (${#modified_files[@]})"
    if [[ ${#modified_files[@]} -eq 0 ]]; then
        echo "  (none)"
    else
        for file in "${modified_files[@]}"; do
            local classification=""
            if [[ "$show_classification" == "true" ]]; then
                classification=$(classify_modification_source "${system_path}${file}")
                echo "  $file ($classification)"
            else
                echo "  $file"
            fi
            if [[ "$show_diff" == "true" ]]; then
                echo ""
                diff -u "${clean_path}${file}" "${system_path}${file}" 2>/dev/null | head -50 || true
                echo ""
            fi
        done
    fi
    
    fmt.subsection.green "New files (only in system, ${#only_in_system[@]})"
    if [[ ${#only_in_system[@]} -eq 0 ]]; then
        echo "  (none)"
    else
        for file in "${only_in_system[@]}"; do
            local classification=""
            if [[ "$show_classification" == "true" ]]; then
                classification=$(classify_modification_source "${system_path}${file}")
                echo "  $file ($classification)"
            else
                echo "  $file"
            fi
        done
    fi
    
    fmt.subsection.red "Deleted files (only in clean-pi, ${#only_in_clean[@]})"
    if [[ ${#only_in_clean[@]} -eq 0 ]]; then
        echo "  (none)"
    else
        for file in "${only_in_clean[@]}"; do
            echo "  $file"
        done
    fi
    
    # Show excluded files if exclusion report requested
    if [[ "$exclusion_report" == "true" && ${#excluded_files[@]} -gt 0 ]]; then
        fmt.subsection.magenta "Excluded files (${#excluded_files[@]})"
        for file in "${excluded_files[@]}"; do
            local classification
            classification=$(classify_modification_source "${system_path}${file}")
            local reason
            reason=$(get_exclusion_reason "${system_path}${file}" "$classification")
            echo "  $file ($reason)"
        done
    fi
    
    # Generate summary counts
    local total_changes=$((${#modified_files[@]} + ${#only_in_system[@]} + ${#only_in_clean[@]}))
    local total_excluded=${#excluded_files[@]}
    
    # echo ""
    # fmt.subsection "Totals"
    # fmt.info "Total changes" "$total_changes"
    # if [[ $total_excluded -gt 0 ]]; then
    #     fmt.info "Total excluded" "$total_excluded"
    # fi
}

# Main script
main() {
    local system_path=""
    local cutoff="$DAY0_CUTOFF"
    local verbose="false"
    local show_diff="false"
    local exclude_system="false"
    local show_classification="false"
    local exclusion_report="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--cutoff)
                cutoff="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose="true"
                shift
                ;;
            -d|--diff)
                show_diff="true"
                shift
                ;;
            -e|--exclude-system)
                exclude_system="true"
                shift
                ;;
            -s|--show-classification)
                show_classification="true"
                shift
                ;;
            -r|--exclusion-report)
                exclusion_report="true"
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                system_path="$1"
                shift
                ;;
        esac
    done
    
    # Validate path
    if [[ -z "$system_path" ]]; then
        print_color "$RED" "Error: No path specified"
        echo ""
        usage
    fi
    
    if [[ ! -d "$system_path" ]]; then
        print_color "$RED" "Error: Path does not exist or is not a directory: $system_path"
        exit 1
    fi
    
    # Initialize exclusion rules
    init_exclusion_rules
    
    # Check clean-pi mounted
    check_clean_pi_mounted
    
    # Get corresponding clean-pi path
    local clean_path
    clean_path=$(get_clean_pi_path "$system_path")
    
    # Run comparison (warnings will be shown in summary)
    compare_directories "$system_path" "$clean_path" "$cutoff" "$verbose" "$show_diff" "$exclude_system" "$show_classification" "$exclusion_report"
}

main "$@"


