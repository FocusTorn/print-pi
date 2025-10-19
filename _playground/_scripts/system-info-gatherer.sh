#!/bin/bash
#
# System Information Gatherer
# Collects comprehensive details about the Raspberry Pi OS installation
# Output can be used to generate system.mdc documentation
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Output formatting
section() {
    echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}▶ $1${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

subsection() {
    echo -e "\n${BOLD}${BLUE}┌─ $1${NC}"
}

info() {
    echo -e "${GREEN}  ✓${NC} $1: ${YELLOW}$2${NC}"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}  ✓${NC} $1: ${YELLOW}$(command -v "$1")${NC}"
    else
        echo -e "${RED}  ✗${NC} $1: ${YELLOW}Not installed${NC}"
    fi
}

get_version() {
    local cmd="$1"
    local flag="${2:---version}"
    if command -v "$cmd" &> /dev/null; then
        local version=$($cmd $flag 2>&1 | head -n1)
        echo -e "${GREEN}  ✓${NC} $cmd: ${YELLOW}$version${NC}"
    else
        echo -e "${RED}  ✗${NC} $cmd: ${YELLOW}Not installed${NC}"
    fi
}

# Header
echo -e "${BOLD}${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║          SYSTEM INFORMATION GATHERER v1.0                    ║
║          Raspberry Pi Environment Documentation              ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}Gathering system information... This may take a moment.${NC}\n"

# ============================================================================
section "1. SYSTEM IDENTITY"
# ============================================================================

subsection "Operating System"
info "OS Name" "$(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
info "OS ID" "$(cat /etc/os-release | grep -w ID | cut -d= -f2 | tr -d '"')"
info "OS Version" "$(cat /etc/os-release | grep VERSION_ID | cut -d= -f2 | tr -d '"')"
info "Kernel Version" "$(uname -r)"
info "Architecture" "$(uname -m)"
info "Hostname" "$(hostname)"
info "FQDN" "$(hostname -f 2>/dev/null || echo 'Not configured')"

subsection "Boot Configuration"
if [ -f /boot/firmware/config.txt ]; then
    info "Boot Config" "/boot/firmware/config.txt"
elif [ -f /boot/config.txt ]; then
    info "Boot Config" "/boot/config.txt"
fi
info "Cmdline" "$(cat /proc/cmdline | cut -c1-60)..."

# ============================================================================
section "2. HARDWARE DETAILS"
# ============================================================================

subsection "Raspberry Pi Model"
if [ -f /proc/device-tree/model ]; then
    info "Model" "$(cat /proc/device-tree/model | tr -d '\0')"
fi
info "Serial Number" "$(cat /proc/cpuinfo | grep Serial | cut -d ':' -f 2 | xargs)"
info "Revision" "$(cat /proc/cpuinfo | grep Revision | cut -d ':' -f 2 | xargs)"

subsection "CPU Information"
info "CPU Model" "$(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)"
info "CPU Cores" "$(nproc)"
info "CPU Architecture" "$(lscpu | grep 'Architecture' | cut -d':' -f2 | xargs)"
info "CPU MHz" "$(lscpu | grep 'CPU max MHz' | cut -d':' -f2 | xargs || echo 'N/A')"
info "CPU Temperature" "$(vcgencmd measure_temp 2>/dev/null || echo 'N/A')"

subsection "Memory Information"
info "Total RAM" "$(free -h | grep Mem | awk '{print $2}')"
info "Used RAM" "$(free -h | grep Mem | awk '{print $3}')"
info "Free RAM" "$(free -h | grep Mem | awk '{print $4}')"
info "Swap Total" "$(free -h | grep Swap | awk '{print $2}')"

subsection "GPU Information"
info "GPU Memory" "$(vcgencmd get_mem gpu 2>/dev/null || echo 'N/A')"
info "ARM Memory" "$(vcgencmd get_mem arm 2>/dev/null || echo 'N/A')"

# ============================================================================
section "3. STORAGE & FILESYSTEM"
# ============================================================================

subsection "Disk Usage"
df -h | grep -E '^/dev|^Filesystem' | while read line; do
    echo "  $line"
done

subsection "Root Filesystem"
info "Root FS Type" "$(findmnt -n -o FSTYPE /)"
info "Root FS Size" "$(df -h / | tail -1 | awk '{print $2}')"
info "Root FS Used" "$(df -h / | tail -1 | awk '{print $3}')"
info "Root FS Available" "$(df -h / | tail -1 | awk '{print $4}')"
info "Root FS Use%" "$(df -h / | tail -1 | awk '{print $5}')"

subsection "Mount Points"
findmnt -t ext4,vfat,tmpfs,overlay | head -20

# ============================================================================
section "4. DIRECTORY STRUCTURE"
# ============================================================================

subsection "User Directories"
for dir in /home/pi/_playground /home/pi/3dp-mods /home/pi/.user-scripts /home/pi/Downloads; do
    if [ -d "$dir" ]; then
        size=$(du -sh "$dir" 2>/dev/null | cut -f1)
        info "$(basename $dir)" "$dir ($size)"
    fi
done

subsection "Important Paths"
for path in /home/pi /usr/local/bin /opt /etc/systemd/system; do
    if [ -d "$path" ]; then
        info "$path" "$(ls -la $path | head -3 | tail -1 | awk '{print $1, $3, $4}')"
    fi
done

# ============================================================================
section "5. NETWORK CONFIGURATION"
# ============================================================================

subsection "Network Interfaces"
ip -br addr show | while read line; do
    echo "  $line"
done

subsection "Active Connections"
info "WiFi Status" "$(iwgetid -r 2>/dev/null || echo 'Not connected')"
info "Default Gateway" "$(ip route | grep default | awk '{print $3}')"
info "DNS Servers" "$(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ', ' | sed 's/,$//')"

subsection "Hostname Resolution"
info "Hostname" "$(hostname)"
info "Avahi Hostname" "$(hostname).local"

# ============================================================================
section "6. DEVELOPMENT ENVIRONMENT"
# ============================================================================

subsection "Programming Languages"
get_version "python3"
get_version "python2"
get_version "node"
get_version "npm"
get_version "rustc"
get_version "cargo"
get_version "gcc"
get_version "make"

subsection "Shell & Tools"
info "Default Shell" "$SHELL"
get_version "bash"
get_version "zsh"
get_version "git"
get_version "curl"
get_version "wget"

subsection "Package Managers"
get_version "apt"
get_version "pip3" "--version"
get_version "cargo"
get_version "npm"

# ============================================================================
section "7. INSTALLED SERVICES"
# ============================================================================

subsection "Systemd Services (Custom)"
echo "  Active custom services:"
systemctl list-units --type=service --state=active --no-pager | grep -E 'klipper|moonraker|overlay|3dp' || echo "  None found"

subsection "Running Services (Key)"
for service in ssh klipper moonraker nginx; do
    if systemctl is-active --quiet $service 2>/dev/null; then
        echo -e "${GREEN}  ✓${NC} $service: ${YELLOW}Active${NC}"
    else
        echo -e "${RED}  ✗${NC} $service: ${YELLOW}Inactive or Not Installed${NC}"
    fi
done

# ============================================================================
section "8. OVERLAY & REDIRECTION SYSTEM"
# ============================================================================

subsection "File Overlay Manager"
if [ -f /home/pi/.user-scripts/redirector/file-overlay-manager.sh ]; then
    info "Overlay Manager" "Installed ✓"
    info "Location" "/home/pi/.user-scripts/redirector/file-overlay-manager.sh"
    
    if [ -f /home/pi/.user-scripts/redirector/overlay-config.conf ]; then
        info "Config File" "/home/pi/.user-scripts/redirector/overlay-config.conf"
        overlay_count=$(grep -c "^/home" /home/pi/.user-scripts/redirector/overlay-config.conf 2>/dev/null || echo "0")
        info "Configured Overlays" "$overlay_count"
    fi
else
    info "Overlay Manager" "Not found"
fi

subsection "System File Tracker"
if [ -f /home/pi/.user-scripts/system-tracker ]; then
    info "System Tracker" "Installed ✓"
    info "Location" "/home/pi/.user-scripts/system-tracker"
    
    if [ -f /home/pi/3dp-mods/.system-track-list ]; then
        tracked_count=$(wc -l < /home/pi/3dp-mods/.system-track-list 2>/dev/null || echo "0")
        info "Tracked Files" "$tracked_count"
    fi
else
    info "System Tracker" "Not found"
fi

subsection "Active Bind Mounts"
mount | grep -E 'bind|overlay' | head -10 || echo "  None found"

# ============================================================================
section "9. 3D PRINTING SETUP"
# ============================================================================

subsection "Klipper Installation"
if [ -d /home/pi/klipper ]; then
    info "Klipper Directory" "/home/pi/klipper"
    if [ -f /home/pi/klipper/.git/HEAD ]; then
        klipper_commit=$(cd /home/pi/klipper && git rev-parse --short HEAD 2>/dev/null || echo "Unknown")
        info "Klipper Version" "$klipper_commit"
    fi
fi

subsection "Printer Configuration"
if [ -d /home/pi/printer_data ]; then
    info "Printer Data" "/home/pi/printer_data"
    if [ -f /home/pi/printer_data/config/printer.cfg ]; then
        info "printer.cfg" "Found ✓"
    fi
fi

subsection "Modifications Directory"
if [ -d /home/pi/3dp-mods ]; then
    mod_size=$(du -sh /home/pi/3dp-mods 2>/dev/null | cut -f1)
    info "3DP Mods Directory" "/home/pi/3dp-mods ($mod_size)"
    
    if [ -d /home/pi/3dp-mods/.git ]; then
        info "Git Repository" "Initialized ✓"
        git_remote=$(cd /home/pi/3dp-mods && git remote get-url origin 2>/dev/null || echo "No remote")
        info "Git Remote" "$git_remote"
    fi
fi

# ============================================================================
section "10. USER ENVIRONMENT"
# ============================================================================

subsection "Current User"
info "Username" "$USER"
info "User ID" "$(id -u)"
info "Group ID" "$(id -g)"
info "Groups" "$(groups | tr ' ' ', ')"
info "Home Directory" "$HOME"

subsection "Environment Variables (Key)"
info "PATH" "${PATH:0:80}..."
info "EDITOR" "${EDITOR:-Not set}"
info "SHELL" "$SHELL"
info "TERM" "$TERM"
info "PWD" "$PWD"

subsection "Shell Configuration Files"
for rc in ~/.bashrc ~/.zshrc ~/.profile ~/.bash_profile; do
    if [ -f "$rc" ]; then
        size=$(du -h "$rc" | cut -f1)
        info "$(basename $rc)" "$rc ($size)"
    fi
done

# ============================================================================
section "11. SYSTEM PERFORMANCE"
# ============================================================================

subsection "Load Average"
info "1 min / 5 min / 15 min" "$(uptime | awk -F'load average:' '{print $2}')"

subsection "Uptime"
info "System Uptime" "$(uptime -p)"
info "Boot Time" "$(who -b | awk '{print $3, $4}')"

subsection "Process Count"
info "Total Processes" "$(ps aux | wc -l)"
info "Running Processes" "$(ps aux | grep -c ' R ')"

# ============================================================================
section "12. INSTALLED PACKAGES (SAMPLE)"
# ============================================================================

subsection "Debian Packages (Key Tools)"
dpkg -l | grep -E 'git|python3|gcc|make|cmake|nginx|vim' | awk '{print "  " $2 " - " $3}' | head -20

subsection "Python Packages (Global)"
pip3 list 2>/dev/null | head -15 || echo "  Unable to list pip packages"

# ============================================================================
section "13. GIT CONFIGURATION"
# ============================================================================

subsection "Git Identity"
info "User Name" "$(git config --global user.name || echo 'Not configured')"
info "User Email" "$(git config --global user.email || echo 'Not configured')"

subsection "Git Repositories"
for dir in /home/pi/3dp-mods /home/pi/_playground /home/pi/klipper; do
    if [ -d "$dir/.git" ]; then
        cd "$dir"
        branch=$(git branch --show-current 2>/dev/null || echo "detached HEAD")
        status=$(git status --porcelain | wc -l)
        echo -e "${GREEN}  ✓${NC} $(basename $dir): ${YELLOW}$branch${NC} (${status} changes)"
    fi
done

# ============================================================================
section "14. SECURITY & ACCESS"
# ============================================================================

subsection "SSH Configuration"
if [ -f /etc/ssh/sshd_config ]; then
    info "SSH Config" "/etc/ssh/sshd_config"
    ssh_port=$(grep -E "^Port " /etc/ssh/sshd_config | awk '{print $2}' || echo "22 (default)")
    info "SSH Port" "$ssh_port"
fi

subsection "Firewall Status"
if command -v ufw &> /dev/null; then
    ufw_status=$(sudo ufw status 2>/dev/null | head -1 || echo "Unknown")
    info "UFW Status" "$ufw_status"
else
    info "UFW" "Not installed"
fi

subsection "Sudo Access"
if sudo -n true 2>/dev/null; then
    info "Passwordless Sudo" "Enabled"
else
    info "Passwordless Sudo" "Disabled"
fi

# ============================================================================
section "15. CUSTOM SCRIPTS & TOOLS"
# ============================================================================

subsection "User Scripts"
if [ -d /home/pi/.user-scripts ]; then
    find /home/pi/.user-scripts -maxdepth 2 -type f -executable | while read script; do
        echo -e "${GREEN}  ✓${NC} $(basename $script): ${YELLOW}$script${NC}"
    done
fi

subsection "Global Commands"
for cmd in overlay system-track chamon system-monitor; do
    check_command "$cmd"
done

# ============================================================================
section "16. MODIFIED SYSTEM FILES"
# ============================================================================

subsection "Package File Integrity Check"
echo -e "${CYAN}Checking for modified system files (this may take a moment)...${NC}"

# Check if debsums is installed
if command -v debsums &> /dev/null; then
    # Quick check for modified config files
    modified_etc=$(sudo debsums -c 2>/dev/null | grep "^/etc" | wc -l || echo "0")
    modified_boot=$(sudo debsums -c 2>/dev/null | grep "^/boot" | wc -l || echo "0")
    modified_total=$(sudo debsums -c 2>/dev/null | wc -l || echo "0")
    
    info "Modified /etc files" "$modified_etc"
    info "Modified /boot files" "$modified_boot"
    info "Total modified files" "$modified_total"
    
    if [ $modified_total -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}  ⚠ System files have been modified from package defaults${NC}"
        echo -e "${YELLOW}  Run: /home/pi/_playground/_scripts/detect-modified-system-files.sh${NC}"
        echo -e "${YELLOW}  For detailed analysis and recommendations${NC}"
    else
        echo ""
        echo -e "${GREEN}  ✓ All system files match package checksums${NC}"
    fi
else
    info "debsums" "Not installed (run 'sudo apt install debsums' for file verification)"
fi

subsection "Known System Customizations"
if [ -f /home/pi/3dp-mods/.system-track-list ]; then
    tracked_files=$(wc -l < /home/pi/3dp-mods/.system-track-list)
    info "Tracked System Files" "$tracked_files files in system-tracker"
    
    echo ""
    echo -e "${CYAN}  Files being tracked:${NC}"
    head -10 /home/pi/3dp-mods/.system-track-list | while read -r file; do
        echo "    • $file"
    done
    
    if [ $tracked_files -gt 10 ]; then
        echo "    ... and $((tracked_files - 10)) more"
    fi
else
    info "System Tracker" "No tracked files"
fi

# ============================================================================
section "17. SUMMARY"
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

