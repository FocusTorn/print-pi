#!/bin/bash
#
# System Information Gatherer
# Collects comprehensive details about the Raspberry Pi OS installation
# Output can be used to generate system.mdc documentation
#

set -e

# Load shared formatting library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/formatting.sh"

# Header
fmt.header "SYSTEM INFORMATION GATHERER v1.0"

# ============================================================================
fmt.section "1. SYSTEM IDENTITY"
# ============================================================================

fmt.subsection "Operating System"
fmt.info "OS Name" "$(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
fmt.info "OS ID" "$(cat /etc/os-release | grep -w ID | cut -d= -f2 | tr -d '"')"
fmt.info "OS Version" "$(cat /etc/os-release | grep VERSION_ID | cut -d= -f2 | tr -d '"')"
fmt.info "Kernel Version" "$(uname -r)"
fmt.info "Architecture" "$(uname -m)"
fmt.info "Hostname" "$(hostname)"
fmt.info "FQDN" "$(hostname -f 2>/dev/null || echo 'Not configured')"

fmt.subsection "Boot Configuration"
if [ -f /boot/firmware/config.txt ]; then
    fmt.info "Boot Config" "/boot/firmware/config.txt"
elif [ -f /boot/config.txt ]; then
    fmt.info "Boot Config" "/boot/config.txt"
fi
fmt.info "Cmdline" "$(cat /proc/cmdline | cut -c1-60)..."

# ============================================================================
fmt.section "2. HARDWARE DETAILS"
# ============================================================================

fmt.subsection "Raspberry Pi Model"
if [ -f /proc/device-tree/model ]; then
    fmt.info "Model" "$(cat /proc/device-tree/model | tr -d '\0')"
fi
fmt.info "Serial Number" "$(cat /proc/cpuinfo | grep Serial | cut -d ':' -f 2 | xargs)"
fmt.info "Revision" "$(cat /proc/cpuinfo | grep Revision | cut -d ':' -f 2 | xargs)"

fmt.subsection "CPU Information"
fmt.info "CPU Model" "$(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)"
fmt.info "CPU Cores" "$(nproc)"
fmt.info "CPU Architecture" "$(lscpu | grep 'Architecture' | cut -d':' -f2 | xargs)"
fmt.info "CPU MHz" "$(lscpu | grep 'CPU max MHz' | cut -d':' -f2 | xargs || echo 'N/A')"
fmt.info "CPU Temperature" "$(vcgencmd measure_temp 2>/dev/null || echo 'N/A')"

fmt.subsection "Memory Information"
fmt.info "Total RAM" "$(free -h | grep Mem | awk '{print $2}')"
fmt.info "Used RAM" "$(free -h | grep Mem | awk '{print $3}')"
fmt.info "Free RAM" "$(free -h | grep Mem | awk '{print $4}')"
fmt.info "Swap Total" "$(free -h | grep Swap | awk '{print $2}')"

fmt.subsection "GPU Information"
fmt.info "GPU Memory" "$(vcgencmd get_mem gpu 2>/dev/null || echo 'N/A')"
fmt.info "ARM Memory" "$(vcgencmd get_mem arm 2>/dev/null || echo 'N/A')"

# ============================================================================
fmt.section "3. STORAGE & FILESYSTEM"
# ============================================================================

fmt.subsection "Disk Usage"
df -h | grep -E '^/dev|^Filesystem' | while read line; do
    echo -e "${BLUE}│${NC}  $line"
done

fmt.subsection "Root Filesystem"
fmt.info "Root FS Type" "$(findmnt -n -o FSTYPE /)"
fmt.info "Root FS Size" "$(df -h / | tail -1 | awk '{print $2}')"
fmt.info "Root FS Used" "$(df -h / | tail -1 | awk '{print $3}')"
fmt.info "Root FS Available" "$(df -h / | tail -1 | awk '{print $4}')"
fmt.info "Root FS Use%" "$(df -h / | tail -1 | awk '{print $5}')"

fmt.subsection "Mount Points"
findmnt -t ext4,vfat,tmpfs,overlay | head -20 | while read line; do
    echo -e "${BLUE}│${NC}  $line"
done

# ============================================================================
fmt.section "4. DIRECTORY STRUCTURE"
# ============================================================================

fmt.subsection "User Directories"
for dir in /home/pi/_playground /home/pi/_scripts /home/pi/Downloads; do
    if [ -d "$dir" ]; then
        size=$(du -sh "$dir" 2>/dev/null | cut -f1)
        fmt.info "$(basename $dir)" "$dir ($size)"
    fi
done

fmt.subsection "Important Paths"
for path in /home/pi /usr/local/bin /opt /etc/systemd/system; do
    if [ -d "$path" ]; then
        fmt.info "$path" "$(ls -la $path | head -3 | tail -1 | awk '{print $1, $3, $4}')"
    fi
done

# ============================================================================
fmt.section "5. NETWORK CONFIGURATION"
# ============================================================================

fmt.subsection "Network Interfaces"
ip -br addr show | while read line; do
    echo -e "${BLUE}│${NC}  $line"
done

fmt.subsection "Active Connections"
fmt.info "WiFi Status" "$(iwgetid -r 2>/dev/null || echo 'Not connected')"
fmt.info "Default Gateway" "$(ip route | grep default | awk '{print $3}')"
fmt.info "DNS Servers" "$(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ', ' | sed 's/,$//')"

fmt.subsection "Hostname Resolution"
fmt.info "Hostname" "$(hostname)"
fmt.info "Avahi Hostname" "$(hostname).local"

# ============================================================================
fmt.section "6. DEVELOPMENT ENVIRONMENT"
# ============================================================================

fmt.subsection "Programming Languages"
fmt.check_cmd "python3"
fmt.check_cmd "python2"
fmt.check_cmd "node"
fmt.check_cmd "npm"
fmt.check_cmd "rustc"
fmt.check_cmd "cargo"
fmt.check_cmd "gcc"
fmt.check_cmd "make"

fmt.subsection "Shell & Tools"
fmt.info "Default Shell" "$SHELL"
fmt.check_cmd "bash"
fmt.check_cmd "zsh"
fmt.check_cmd "git"
fmt.check_cmd "curl"
fmt.check_cmd "wget"

fmt.subsection "Package Managers"
fmt.check_cmd "apt"
fmt.check_cmd "pip3" "--version"
fmt.check_cmd "cargo"
fmt.check_cmd "npm"

# ============================================================================
fmt.section "7. INSTALLED SERVICES"
# ============================================================================

fmt.subsection "Systemd Services (Custom)"
systemctl list-units --type=service --state=active --no-pager | grep -E 'klipper|moonraker|overlay|3dp' | while read line; do
    echo -e "${BLUE}│${NC}  $line"
done
[[ $? -ne 0 ]] && echo -e "${BLUE}│${NC}  None found"

fmt.subsection "Running Services (Key)"
for service in ssh klipper moonraker nginx; do
    if systemctl is-active --quiet $service 2>/dev/null; then
        echo -e "${BLUE}│${NC}  ${GREEN}✓${NC} $service: ${YELLOW}Active${NC}"
    else
        echo -e "${BLUE}│${NC}  ${RED}✗${NC} $service: ${YELLOW}Inactive or Not Installed${NC}"
    fi
done

# ============================================================================
fmt.section "8. OVERLAY & REDIRECTION SYSTEM"
# ============================================================================

fmt.subsection "File Overlay Manager"
if [ -f /home/pi/.user-scripts/redirector/file-overlay-manager.sh ]; then
    fmt.info "Overlay Manager" "Installed ✓"
    fmt.info "Location" "/home/pi/.user-scripts/redirector/file-overlay-manager.sh"
    
    if [ -f /home/pi/.user-scripts/redirector/overlay-config.conf ]; then
        fmt.info "Config File" "/home/pi/.user-scripts/redirector/overlay-config.conf"
        overlay_count=$(grep -c "^/home" /home/pi/.user-scripts/redirector/overlay-config.conf 2>/dev/null || echo "0")
        fmt.info "Configured Overlays" "$overlay_count"
    fi
else
    fmt.info "Overlay Manager" "Not found"
fi

fmt.subsection "System File Tracker"
if [ -f /home/pi/.user-scripts/system-tracker ]; then
    fmt.info "System Tracker" "Installed ✓"
    fmt.info "Location" "/home/pi/.user-scripts/system-tracker"
    
    if [ -f /home/pi/3dp-mods/.system-track-list ]; then
        tracked_count=$(wc -l < /home/pi/3dp-mods/.system-track-list 2>/dev/null || echo "0")
        fmt.info "Tracked Files" "$tracked_count"
    fi
else
    fmt.info "System Tracker" "Not found"
fi

fmt.subsection "Active Bind Mounts"
mount | grep -E 'bind|overlay' | head -10 | while read line; do
    echo -e "${BLUE}│${NC}  $line"
done
[[ $? -ne 0 ]] && echo -e "${BLUE}│${NC}  None found"

# ============================================================================
fmt.section "9. 3D PRINTING SETUP"
# ============================================================================

fmt.subsection "Klipper Installation"
if [ -d /home/pi/klipper ]; then
    fmt.info "Klipper Directory" "/home/pi/klipper"
    if [ -f /home/pi/klipper/.git/HEAD ]; then
        klipper_commit=$(cd /home/pi/klipper && git rev-parse --short HEAD 2>/dev/null || echo "Unknown")
        fmt.info "Klipper Version" "$klipper_commit"
    fi
fi

fmt.subsection "Printer Configuration"
if [ -d /home/pi/printer_data ]; then
    fmt.info "Printer Data" "/home/pi/printer_data"
    if [ -f /home/pi/printer_data/config/printer.cfg ]; then
        fmt.info "printer.cfg" "Found ✓"
    fi
fi

fmt.subsection "Modifications Directory"
if [ -d /home/pi/playground ]; then
    mod_size=$(du -sh /home/pi/3dp-mods 2>/dev/null | cut -f1)
    fmt.info "3DP Mods Directory" "/home/pi/3dp-mods ($mod_size)"
    
    if [ -d /home/pi/3dp-mods/.git ]; then
        fmt.info "Git Repository" "Initialized ✓"
        git_remote=$(cd /home/pi/3dp-mods && git remote get-url origin 2>/dev/null || echo "No remote")
        fmt.info "Git Remote" "$git_remote"
    fi
fi

# ============================================================================
fmt.section "10. USER ENVIRONMENT"
# ============================================================================

fmt.subsection "Current User"
fmt.info "Username" "$USER"
fmt.info "User ID" "$(id -u)"
fmt.info "Group ID" "$(id -g)"
fmt.info "Groups" "$(groups | tr ' ' ', ')"
fmt.info "Home Directory" "$HOME"

fmt.subsection "Environment Variables (Key)"
fmt.info "PATH" "${PATH:0:80}..."
fmt.info "EDITOR" "${EDITOR:-Not set}"
fmt.info "SHELL" "$SHELL"
fmt.info "TERM" "$TERM"
fmt.info "PWD" "$PWD"

fmt.subsection "Shell Configuration Files"
for rc in ~/.bashrc ~/.zshrc ~/.profile ~/.bash_profile; do
    if [ -f "$rc" ]; then
        size=$(du -h "$rc" | cut -f1)
        fmt.info "$(basename $rc)" "$rc ($size)"
    fi
done

# ============================================================================
fmt.section "11. SYSTEM PERFORMANCE"
# ============================================================================

fmt.subsection "Load Average"
fmt.info "1 min / 5 min / 15 min" "$(uptime | awk -F'load average:' '{print $2}')"

fmt.subsection "Uptime"
fmt.info "System Uptime" "$(uptime -p)"
fmt.info "Boot Time" "$(who -b | awk '{print $3, $4}')"

fmt.subsection "Process Count"
fmt.info "Total Processes" "$(ps aux | wc -l)"
fmt.info "Running Processes" "$(ps aux | grep -c ' R ')"

# ============================================================================
fmt.section "12. INSTALLED PACKAGES (SAMPLE)"
# ============================================================================

fmt.subsection "Debian Packages (Key Tools)"
dpkg -l | grep -E 'git|python3|gcc|make|cmake|nginx|vim' | awk -v blue="${BLUE}" -v nc="${NC}" '{print blue "│" nc "  " $2 " - " $3}' | head -20

fmt.subsection "Python Packages (Global)"
pip3 list 2>/dev/null | tail -n +3 | awk -v blue="${BLUE}" -v nc="${NC}" '{print blue "│" nc "  " $1 " - " $2}' | head -20 || echo -e "${BLUE}│${NC}  Unable to list pip packages"

# ============================================================================
fmt.section "13. GIT CONFIGURATION"
# ============================================================================

fmt.subsection "Git Identity"
fmt.info "User Name" "$(git config --global user.name || echo 'Not configured')"
fmt.info "User Email" "$(git config --global user.email || echo 'Not configured')"

fmt.subsection "Git Repositories"

# Smart scan: exclude problematic/slow paths
found_repos=0
while IFS= read -r -d '' git_dir; do
    repo_dir=$(dirname "$git_dir")
    if [ -f "$repo_dir/.git/HEAD" ]; then
        (
            # Run in subshell to isolate any errors from set -e
            cd "$repo_dir" || exit 0
            branch=$(git branch --show-current 2>/dev/null || echo "detached HEAD")
            status=$(git status --porcelain 2>/dev/null | wc -l)
            remote=$(git remote get-url origin 2>/dev/null || echo "no remote")
            echo -e "${BLUE}│${NC}  ${GREEN}✓${NC} $repo_dir"
            echo -e "${BLUE}│${NC}     ${YELLOW}Branch:${NC} $branch  ${YELLOW}Changes:${NC} $status  ${YELLOW}Remote:${NC} ${remote:0:60}"
        )
        ((found_repos++)) || true
    fi
done < <(find /home /opt /usr/local -type d -name .git \
    -print0 2>/dev/null)

if [ $found_repos -eq 0 ]; then
    echo -e "${BLUE}│${NC}  ${YELLOW}No git repositories found${NC}"
fi

# ============================================================================
fmt.section "14. SECURITY & ACCESS"
# ============================================================================

fmt.subsection "SSH Configuration"
if [ -f /etc/ssh/sshd_config ]; then
    fmt.info "SSH Config" "/etc/ssh/sshd_config"
    ssh_port=$(grep -E "^Port " /etc/ssh/sshd_config | awk '{print $2}' || echo "22 (default)")
    fmt.info "SSH Port" "$ssh_port"
fi

fmt.subsection "Firewall Status"
if command -v ufw &> /dev/null; then
    ufw_status=$(sudo ufw status 2>/dev/null | head -1 || echo "Unknown")
    fmt.info "UFW Status" "$ufw_status"
else
    fmt.info "UFW" "Not installed"
fi

fmt.subsection "Sudo Access"
if sudo -n true 2>/dev/null; then
    fmt.info "Passwordless Sudo" "Enabled"
else
    fmt.info "Passwordless Sudo" "Disabled"
fi

# ============================================================================
fmt.section "15. CUSTOM SCRIPTS & TOOLS"
# ============================================================================

fmt.subsection "User Scripts"
if [ -d /home/pi/_playground/_scripts ]; then
    find /home/pi/_playground/_scripts -maxdepth 2 -type f -executable | while read script; do
        echo -e "${BLUE}│${NC}  ${GREEN}✓${NC} $(basename $script): ${YELLOW}$script${NC}"
    done
fi

fmt.subsection "Global Commands"
for cmd in overlay system-track chamon system-monitor; do
    fmt.check_cmd "$cmd"
done

# # ============================================================================
# section "16. MODIFIED SYSTEM FILES"
# # ============================================================================

# subsection "Package File Integrity Check"
# echo -e "${CYAN}Checking for modified system files (this may take a moment)...${NC}"

# # Check if debsums is installed
# if command -v debsums &> /dev/null; then
#     # Quick check for modified config files
#     modified_etc=$(sudo debsums -c 2>/dev/null | grep "^/etc" | wc -l || echo "0")
#     modified_boot=$(sudo debsums -c 2>/dev/null | grep "^/boot" | wc -l || echo "0")
#     modified_total=$(sudo debsums -c 2>/dev/null | wc -l || echo "0")
    
#     fmt.info "Modified /etc files" "$modified_etc"
#     fmt.info "Modified /boot files" "$modified_boot"
#     fmt.info "Total modified files" "$modified_total"
    
#     if [ $modified_total -gt 0 ]; then
#         echo ""
#         echo -e "${YELLOW}  ⚠ System files have been modified from package defaults${NC}"
#         echo -e "${YELLOW}  Run: /home/pi/_playground/_scripts/detect-modified-system-files.sh${NC}"
#         echo -e "${YELLOW}  For detailed analysis and recommendations${NC}"
#     else
#         echo ""
#         echo -e "${GREEN}  ✓ All system files match package checksums${NC}"
#     fi
# else
#     fmt.info "debsums" "Not installed (run 'sudo apt install debsums' for file verification)"
# fi

# subsection "Known System Customizations"
# if [ -f /home/pi/3dp-mods/.system-track-list ]; then
#     tracked_files=$(wc -l < /home/pi/3dp-mods/.system-track-list)
#     fmt.info "Tracked System Files" "$tracked_files files in system-tracker"
    
#     echo ""
#     echo -e "${CYAN}  Files being tracked:${NC}"
#     head -10 /home/pi/3dp-mods/.system-track-list | while read -r file; do
#         echo "    • $file"
#     done
    
#     if [ $tracked_files -gt 10 ]; then
#         echo "    ... and $((tracked_files - 10)) more"
#     fi
# else
#     fmt.info "System Tracker" "No tracked files"
# fi

# ============================================================================
fmt.section "17. SUMMARY"
# ============================================================================

echo ""
echo -e "${BOLD}${GREEN}System Information Collection Complete!${NC}"
echo ""
echo -e "${CYAN}Key Statistics:${NC}"
echo -e "  • OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
echo -e "  • Kernel: $(uname -r)"
echo -e "  • Hardware: $(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo 'Unknown')"
echo -e "  • RAM: $(free -h | grep Mem | awk '{print $2}')"
echo -e "  • Disk: $(df -h / | tail -1 | awk '{print $2 " total, " $4 " available"}')"
echo -e "  • Uptime: $(uptime -p)"
echo ""
echo -e "${YELLOW}This data can be used to create your system.mdc documentation file.${NC}"
echo ""

# Optional: Save to file
OUTPUT_FILE="/home/pi/_playground/_scripts/system-info-$(date +%Y%m%d-%H%M%S).txt"
echo -e "${CYAN}💾 Save this output to a file? (y/N):${NC} "

