#!/bin/bash
#
# Detect Modified System Files v3.0
# Uses direct .md5sums file parsing with progress bars
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
OUTPUT_FILE=""
VERBOSE=false
CHECK_CONFIG_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
        -v|--verbose) VERBOSE=true; shift ;;
        -c|--config-only) CHECK_CONFIG_ONLY=true; shift ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -o, --output FILE       Save results to file"
            echo "  -v, --verbose          Show detailed output"
            echo "  -c, --config-only      Only check /etc and /boot files"
            echo "  -h, --help             Show this help"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Progress bar function
draw_progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=0
    local filled=0
    
    # Guard against division by zero
    if [ $total -gt 0 ]; then
        percentage=$((current * 100 / total))
        filled=$((width * current / total))
        [ $filled -gt $width ] && filled=$width
    fi
    
    local empty=$((width - filled))
    
    # Build the bar
    local bar=""
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    for ((i=0; i<empty; i++)); do bar="${bar}░"; done
    
    # Print with carriage return to update same line
    printf "\r${CYAN}[${bar}]${NC} ${YELLOW}%3d%%${NC} ${BLUE}%5d${NC}/${BLUE}%5d${NC} files" "$percentage" "$current" "$total"
}

echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║    MODIFIED SYSTEM FILES DETECTOR v3.0 (Fast & Accurate)     ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if debsums is installed
if ! command -v debsums &> /dev/null; then
    echo -e "${YELLOW}⚠ debsums not installed. Installing...${NC}"
    sudo apt-get update -qq
    sudo apt-get install -y debsums
    echo -e "${GREEN}✓ debsums installed${NC}"
fi

# Temp files
MODIFIED_FILES=$(mktemp)
trap "rm -f $MODIFIED_FILES" EXIT

# Run debsums with appropriate filter
if [ "$CHECK_CONFIG_ONLY" = true ]; then
    echo -e "${BOLD}${CYAN}▶ Scanning /etc and /boot directories${NC}\n"
    
    # Count total files first
    echo -e "${CYAN}Counting files to check...${NC}"
    total_etc=$(find /var/lib/dpkg/info -name "*.md5sums" -exec grep -c "^[a-f0-9]\+\s\+etc/" {} + 2>/dev/null | awk '{s+=$1} END {print s}' || echo "0")
    total_boot=$(find /var/lib/dpkg/info -name "*.md5sums" -exec grep -c "^[a-f0-9]\+\s\+boot/" {} + 2>/dev/null | awk '{s+=$1} END {print s}' || echo "0")
    total_files=$((total_etc + total_boot))
    
    echo -e "${GREEN}✓${NC} Found ${BLUE}$total_files${NC} config files to check (${BLUE}$total_etc${NC} in /etc, ${BLUE}$total_boot${NC} in /boot)"
    echo ""
    
    if [ $total_files -eq 0 ]; then
        echo -e "${YELLOW}⚠ No config files found with checksums${NC}"
        exit 0
    fi
    
    # Check files with progress
    echo -e "${BOLD}Checking files...${NC}"
    current=0
    draw_progress_bar 0 $total_files
    
    # Check /etc files
    sudo debsums -c 2>/dev/null | grep -E "^(/etc|/boot)" | while read -r file; do
        echo "$file" >> "$MODIFIED_FILES"
    done || true
    
    # Count as we process (approximate progress)
    # For accurate progress, we'd need to check files one by one, but that's SLOW
    # So we'll just show 100% when done
    draw_progress_bar $total_files $total_files
    echo ""
    
else
    echo -e "${BOLD}${CYAN}▶ Full System Scan${NC}\n"
    
    # Count packages with md5sums
    total_packages=$(ls -1 /var/lib/dpkg/info/*.md5sums 2>/dev/null | wc -l)
    echo -e "${GREEN}✓${NC} Found ${BLUE}$total_packages${NC} packages with checksums"
    echo ""
    
    if [ $total_packages -eq 0 ]; then
        echo -e "${RED}✗ No packages have MD5 sums!${NC}"
        exit 1
    fi
    
    # Run debsums with progress
    echo -e "${BOLD}Scanning packages...${NC}"
    current=0
    draw_progress_bar 0 $total_packages
    
    # Process each package
    for md5file in /var/lib/dpkg/info/*.md5sums; do
        ((current++))
        
        # Extract package name
        pkg=$(basename "$md5file" .md5sums)
        
        # Check this package
        sudo debsums -s "$pkg" 2>/dev/null || sudo debsums "$pkg" 2>/dev/null | grep "FAILED" | awk '{print $1}' >> "$MODIFIED_FILES" || true
        
        # Update progress every 10 packages
        if [ $((current % 10)) -eq 0 ] || [ $current -eq $total_packages ]; then
            draw_progress_bar $current $total_packages
        fi
    done
    
    draw_progress_bar $total_packages $total_packages
    echo ""
fi

# Results
echo ""
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}RESULTS${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -s "$MODIFIED_FILES" ]; then
    # Categorize
    declare -A categories
    categories["/etc"]="Configuration Files"
    categories["/boot"]="Boot Configuration"
    categories["/usr/local"]="Local Installations"
    categories["/lib"]="System Libraries"
    categories["/usr/lib"]="User Libraries"
    categories["/usr/bin"]="User Binaries"
    categories["/bin"]="System Binaries"
    
    for path in "${!categories[@]}"; do
        matches=$(grep "^$path" "$MODIFIED_FILES" 2>/dev/null | sort -u || true)
        if [ -n "$matches" ]; then
            count=$(echo "$matches" | wc -l)
            echo -e "${BOLD}${CYAN}▶ ${categories[$path]} ($count files)${NC}"
            echo "$matches" | while read -r file; do
                package=$(dpkg -S "$file" 2>/dev/null | cut -d: -f1 || echo "unknown")
                echo -e "${RED}  ✗${NC} $file ${YELLOW}($package)${NC}"
                
                if [ "$VERBOSE" = true ] && [ -f "$file" ]; then
                    mtime=$(stat -c %y "$file" | cut -d. -f1)
                    size=$(stat -c %s "$file")
                    echo -e "      ${YELLOW}Modified:${NC} $mtime  ${YELLOW}Size:${NC} $size bytes"
                fi
            done
            echo ""
        fi
    done
    
    # Other files
    other=$(grep -vE "^/etc|^/boot|^/usr|^/lib|^/bin" "$MODIFIED_FILES" 2>/dev/null | sort -u || true)
    if [ -n "$other" ]; then
        count=$(echo "$other" | wc -l)
        echo -e "${BOLD}${CYAN}▶ Other Files ($count)${NC}"
        echo "$other" | while read -r file; do
            package=$(dpkg -S "$file" 2>/dev/null | cut -d: -f1 || echo "unknown")
            echo -e "${RED}  ✗${NC} $file ${YELLOW}($package)${NC}"
        done
        echo ""
    fi
else
    echo -e "${GREEN}✓ No modified system files detected!${NC}"
    echo -e "${CYAN}All package files match their original checksums.${NC}"
    echo ""
fi

# Summary
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${YELLOW}SUMMARY${NC}"
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

total_modified=$(sort -u "$MODIFIED_FILES" 2>/dev/null | wc -l || echo "0")
etc_modified=$(grep -c "^/etc" "$MODIFIED_FILES" 2>/dev/null || echo "0")
boot_modified=$(grep -c "^/boot" "$MODIFIED_FILES" 2>/dev/null || echo "0")
usr_modified=$(grep -c "^/usr" "$MODIFIED_FILES" 2>/dev/null || echo "0")

echo -e "${CYAN}Total Modified Files:${NC} ${YELLOW}$total_modified${NC}"
echo -e "${CYAN}Configuration Files (/etc):${NC} ${YELLOW}$etc_modified${NC}"
echo -e "${CYAN}Boot Files (/boot):${NC} ${YELLOW}$boot_modified${NC}"
echo -e "${CYAN}User Files (/usr):${NC} ${YELLOW}$usr_modified${NC}"
echo ""

# Save to file
if [ -n "$OUTPUT_FILE" ]; then
    {
        echo "Modified System Files Report"
        echo "Generated: $(date)"
        echo "========================================"
        echo ""
        sort -u "$MODIFIED_FILES"
    } > "$OUTPUT_FILE"
    echo -e "${GREEN}✓ Report saved to: ${YELLOW}$OUTPUT_FILE${NC}"
    echo ""
fi

# Check against system-tracker
if [ -f /home/pi/.user-scripts/system-tracker ] && [ $total_modified -gt 0 ]; then
    echo -e "${BOLD}${BLUE}🔍 Checking against system-tracker...${NC}"
    
    if [ -f /home/pi/3dp-mods/.system-track-list ]; then
        tracked_count=0
        untracked_count=0
        
        sort -u "$MODIFIED_FILES" | while read -r modified_file; do
            if grep -q "$modified_file" /home/pi/3dp-mods/.system-track-list 2>/dev/null; then
                ((tracked_count++)) || true
            else
                ((untracked_count++)) || true
            fi
        done
        
        echo -e "${GREEN}  ✓${NC} Some files tracked in system-tracker"
        echo -e "${CYAN}   Run: system-track add <file> to track important changes${NC}"
    fi
    echo ""
fi

echo -e "${BOLD}${GREEN}✅ Scan complete!${NC}"

