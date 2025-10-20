#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Show usage
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] DEVICE

Generate fstab entries for USB drives with auto-mount and cleanup.

OPTIONS:
    -m, --mountpoint PATH    Mount point (default: /media/pi/LABEL)
    -t, --type TYPE         Filesystem type (auto-detected if not specified)
    -l, --label LABEL       Force label (auto-detected if not specified)
    -a, --automount         Enable systemd automount with idle timeout (default: on)
    -i, --idle-timeout SEC  Idle timeout in seconds (default: 60)
    -n, --no-automount      Disable automount (mount at boot only)
    -h, --help              Show this help

EXAMPLES:
    # Auto-detect everything for /dev/sda1
    $(basename "$0") /dev/sda1

    # Custom mount point
    $(basename "$0") -m /media/pi/backup /dev/sdb1

    # Disable automount
    $(basename "$0") -n /dev/sdc1

EOF
    exit 0
}

# Detect if device exists
check_device() {
    local device=$1
    if [[ ! -b "$device" ]]; then
        print_color "$RED" "Error: Device $device does not exist or is not a block device"
        exit 1
    fi
}

# Get device info
get_device_info() {
    local device=$1
    
    # Get PARTUUID
    PARTUUID=$(blkid -s PARTUUID -o value "$device" || echo "")
    
    # Get UUID
    UUID=$(blkid -s UUID -o value "$device" || echo "")
    
    # Get filesystem type
    FSTYPE=$(blkid -s TYPE -o value "$device" || echo "ext4")
    
    # Get label
    LABEL=$(blkid -s LABEL -o value "$device" || echo "")
    
    if [[ -z "$PARTUUID" && -z "$UUID" ]]; then
        print_color "$RED" "Error: Could not determine PARTUUID or UUID for $device"
        print_color "$YELLOW" "Is the device formatted? Try: sudo mkfs.ext4 -L mylabel $device"
        exit 1
    fi
}

# Generate fstab entry
generate_entry() {
    local identifier="$1"
    local mountpoint="$2"
    local fstype="$3"
    local use_automount="$4"
    local idle_timeout="$5"
    
    local opts="defaults,nofail"
    if [[ "$use_automount" == "true" ]]; then
        opts="${opts},x-systemd.automount,x-systemd.idle-timeout=${idle_timeout}s"
    fi
    
    # Align columns nicely (35 chars for identifier, 30 for mountpoint)
    printf "%-35s %-30s %-6s %-50s 0  2\n" \
        "$identifier" \
        "$mountpoint" \
        "$fstype" \
        "$opts"
}

# Main script
main() {
    local device=""
    local mountpoint=""
    local fstype=""
    local label=""
    local use_automount="true"
    local idle_timeout="60"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mountpoint)
                mountpoint="$2"
                shift 2
                ;;
            -t|--type)
                fstype="$2"
                shift 2
                ;;
            -l|--label)
                label="$2"
                shift 2
                ;;
            -a|--automount)
                use_automount="true"
                shift
                ;;
            -i|--idle-timeout)
                idle_timeout="$2"
                shift 2
                ;;
            -n|--no-automount)
                use_automount="false"
                shift
                ;;
            -h|--help)
                usage
                ;;
            /dev/*)
                device="$1"
                shift
                ;;
            *)
                print_color "$RED" "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Check if device specified
    if [[ -z "$device" ]]; then
        print_color "$RED" "Error: No device specified"
        echo ""
        print_color "$YELLOW" "Available devices:"
        lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT | grep -E "(NAME|sd|nvme)"
        echo ""
        usage
    fi
    
    # Check device exists
    check_device "$device"
    
    # Get device info
    print_color "$BLUE" "Detecting device info for $device..."
    get_device_info "$device"
    
    # Override with user-specified values
    [[ -n "$fstype" ]] && FSTYPE="$fstype"
    [[ -n "$label" ]] && LABEL="$label"
    
    # Determine mount point
    if [[ -z "$mountpoint" ]]; then
        if [[ -n "$LABEL" ]]; then
            mountpoint="/media/pi/$LABEL"
        else
            # Use last 8 chars of UUID
            local short_id="${UUID: -8}"
            mountpoint="/media/pi/drive-$short_id"
        fi
    fi
    
    # Show detected info
    echo ""
    print_color "$GREEN" "Device Information:"
    echo "  Device:      $device"
    echo "  PARTUUID:    ${PARTUUID:-N/A}"
    echo "  UUID:        ${UUID:-N/A}"
    echo "  Filesystem:  $FSTYPE"
    echo "  Label:       ${LABEL:-None}"
    echo "  Mount point: $mountpoint"
    echo "  Auto-mount:  $use_automount"
    if [[ "$use_automount" == "true" ]]; then
        echo "  Idle timeout: ${idle_timeout}s"
    fi
    echo ""
    
    # Prefer PARTUUID over UUID
    local identifier
    if [[ -n "$PARTUUID" ]]; then
        identifier="PARTUUID=$PARTUUID"
    else
        identifier="UUID=$UUID"
    fi
    
    # Generate entry
    print_color "$GREEN" "Generated fstab entry:"
    print_color "$YELLOW" "# Add this to /etc/fstab:"
    echo ""
    generate_entry "$identifier" "$mountpoint" "$FSTYPE" "$use_automount" "$idle_timeout"
    echo ""
    
    # Offer to add it
    read -p "Add this entry to /etc/fstab? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Create mountpoint
        if [[ ! -d "$mountpoint" ]]; then
            print_color "$BLUE" "Creating mount point: $mountpoint"
            sudo mkdir -p "$mountpoint"
        fi
        
        # Add to fstab
        print_color "$BLUE" "Adding entry to /etc/fstab..."
        {
            echo ""
            echo "# $LABEL - $(date)"
            generate_entry "$identifier" "$mountpoint" "$FSTYPE" "$use_automount" "$idle_timeout"
        } | sudo tee -a /etc/fstab > /dev/null
        
        # Reload systemd
        print_color "$BLUE" "Reloading systemd..."
        sudo systemctl daemon-reload
        
        print_color "$GREEN" "✓ Entry added successfully!"
        echo ""
        print_color "$YELLOW" "To mount now: sudo mount $mountpoint"
        print_color "$YELLOW" "Or just access it: ls $mountpoint"
    else
        print_color "$YELLOW" "Entry not added. Copy the line above manually if needed."
    fi
}

main "$@"


