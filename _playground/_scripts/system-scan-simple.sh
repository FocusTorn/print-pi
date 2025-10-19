#!/bin/bash
#
# System File Scanner - Simple & Fast
# Just runs debsums with a nice spinner
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

# Parse flags
CONFIG_ONLY=false
OUTPUT_FILE=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config-only) CONFIG_ONLY=true; shift ;;
        -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
        -v|--verbose) VERBOSE=true; shift ;;
        *) shift ;;
    esac
done

# Spinner function
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local temp
    
    while ps -p $pid > /dev/null 2>&1; do
        temp=${spinstr#?}
        printf "\r${CYAN}%c${NC} Scanning..." "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r"
}

echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║           SYSTEM FILE SCANNER - Simple & Fast                 ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check debsums
if ! command -v debsums &> /dev/null; then
    echo -e "${YELLOW}Installing debsums...${NC}"
    sudo apt-get update -qq && sudo apt-get install -y debsums
fi

# Count packages
total_packages=$(ls -1 /var/lib/dpkg/info/*.md5sums 2>/dev/null | wc -l)
echo -e "${GREEN}✓${NC} Found ${BLUE}$total_packages${NC} packages with checksums"
echo ""

# Temp file
RESULTS=$(mktemp)
trap "rm -f $RESULTS" EXIT

# Run scan
if [ "$CONFIG_ONLY" = true ]; then
    echo -e "${BOLD}${CYAN}▶ Scanning /etc and /boot only...${NC}"
    echo ""
    
    # Count files per directory
    echo -e "${CYAN}Counting files...${NC}"
    etc_files=$(sudo find /var/lib/dpkg/info -name "*.md5sums" -exec grep -c "^\S\+\s\+etc/" {} + 2>/dev/null | awk '{s+=$1} END {print s}')
    boot_files=$(sudo find /var/lib/dpkg/info -name "*.md5sums" -exec grep -c "^\S\+\s\+boot/" {} + 2>/dev/null | awk '{s+=$1} END {print s}')
    total_files=$((etc_files + boot_files))
    
    echo -e "${GREEN}✓${NC} Found ${BLUE}$etc_files${NC} files in /etc"
    echo -e "${GREEN}✓${NC} Found ${BLUE}$boot_files${NC} files in /boot"
    echo -e "${GREEN}✓${NC} Total: ${BLUE}$total_files${NC} config files to check"
    echo ""
    
    # Run single scan with live counter
    echo -e "${CYAN}Checking files (this may take 1-2 minutes)...${NC}"
    sudo debsums -c 2>/dev/null | grep -E "^(/etc|/boot)" > "$RESULTS" &
    bg_pid=$!
    
    # Show live count
    while ps -p $bg_pid > /dev/null 2>&1; do
        count=$(wc -l < "$RESULTS" 2>/dev/null || echo "0")
        etc_count=$(grep -c "^/etc" "$RESULTS" 2>/dev/null || echo "0")
        boot_count=$(grep -c "^/boot" "$RESULTS" 2>/dev/null || echo "0")
        printf "\r${CYAN}⟳${NC} Scanning... ${YELLOW}%d${NC} modified found (${BLUE}%d${NC} /etc, ${BLUE}%d${NC} /boot)" "$count" "$etc_count" "$boot_count"
        sleep 0.5
    done
    wait $bg_pid
    
    # Final summary with totals
    count=$(wc -l < "$RESULTS" 2>/dev/null || echo "0")
    etc_count=$(grep -c "^/etc" "$RESULTS" 2>/dev/null || echo "0")
    boot_count=$(grep -c "^/boot" "$RESULTS" 2>/dev/null || echo "0")
    printf "\r${GREEN}✓${NC} Checked ${BLUE}%d${NC} /etc + ${BLUE}%d${NC} /boot files - ${YELLOW}%d${NC} modified (${BLUE}%d${NC} /etc, ${BLUE}%d${NC} /boot)          \n" "$etc_files" "$boot_files" "$count" "$etc_count" "$boot_count"
    echo ""
else
    echo -e "${BOLD}${CYAN}▶ Full system scan...${NC}"
    echo ""
    echo -e "${CYAN}Checking ${BLUE}$total_packages${NC} packages (this may take 3-5 minutes)...${NC}"
    
    # Run with progress counter
    sudo debsums -c 2>/dev/null > "$RESULTS" &
    bg_pid=$!
    
    # Show live count
    while ps -p $bg_pid > /dev/null 2>&1; do
        count=$(wc -l < "$RESULTS" 2>/dev/null || echo "0")
        printf "\r${CYAN}⟳${NC} Scanning... ${YELLOW}%d${NC} modified files found so far" "$count"
        sleep 0.5
    done
    wait $bg_pid
    
    count=$(wc -l < "$RESULTS" 2>/dev/null || echo "0")
    printf "\r${GREEN}✓${NC} Scan complete! ${YELLOW}%d${NC} modified files found          \n" "$count"
fi

echo ""

# Display results
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}RESULTS${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -s "$RESULTS" ]; then
    # Categorize (Note: /bin and /sbin are symlinks to /usr/bin and /usr/sbin, so we skip them)
    declare -A categories=(
        ["/etc"]="Configuration Files"
        ["/boot"]="Boot Configuration"
        ["/usr/bin"]="User Binaries"
        ["/usr/sbin"]="System Binaries"
        ["/usr/lib"]="User Libraries"
        ["/lib"]="System Libraries"
    )
    
    for path in "${!categories[@]}"; do
        matches=$(grep "^$path" "$RESULTS" 2>/dev/null | sort -u || true)
        if [ -n "$matches" ]; then
            count=$(echo "$matches" | wc -l)
            echo -e "${BOLD}${CYAN}▶ ${categories[$path]} (${count} files)${NC}"
            
            echo "$matches" | head -20 | while read -r file; do
                pkg=$(dpkg -S "$file" 2>/dev/null | cut -d: -f1 || echo "unknown")
                echo -e "${RED}  ✗${NC} $file ${YELLOW}($pkg)${NC}"
                
                if [ "$VERBOSE" = true ] && [ -f "$file" ]; then
                    mtime=$(stat -c "%y" "$file" 2>/dev/null | cut -d. -f1)
                    echo -e "      ${YELLOW}Modified:${NC} $mtime"
                fi
            done
            
            if [ $count -gt 20 ]; then
                echo -e "${YELLOW}      ... and $((count - 20)) more${NC}"
            fi
            echo ""
        fi
    done
    
    # Other files (excluding symlinked dirs like /bin -> /usr/bin)
    other=$(grep -vE "^/etc|^/boot|^/usr|^/lib" "$RESULTS" 2>/dev/null | sort -u || true)
    if [ -n "$other" ]; then
        count=$(echo "$other" | wc -l)
        echo -e "${BOLD}${CYAN}▶ Other Files (${count})${NC}"
        echo "$other" | head -10 | while read -r file; do
            pkg=$(dpkg -S "$file" 2>/dev/null | cut -d: -f1 || echo "unknown")
            echo -e "${RED}  ✗${NC} $file ${YELLOW}($pkg)${NC}"
        done
        [ $count -gt 10 ] && echo -e "${YELLOW}      ... and $((count - 10)) more${NC}"
        echo ""
    fi
else
    echo -e "${GREEN}✓ No modified system files detected!${NC}"
    echo ""
fi

# Summary
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${YELLOW}SUMMARY${NC}"
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

total=$(wc -l < "$RESULTS" 2>/dev/null || echo "0")
etc=$(grep -c "^/etc" "$RESULTS" 2>/dev/null || echo "0")
boot=$(grep -c "^/boot" "$RESULTS" 2>/dev/null || echo "0")

echo -e "${CYAN}Total Modified:${NC} ${YELLOW}$total${NC} files"
echo -e "${CYAN}/etc Modified:${NC} ${YELLOW}$etc${NC} files"
echo -e "${CYAN}/boot Modified:${NC} ${YELLOW}$boot${NC} files"
echo ""

# Save if requested
if [ -n "$OUTPUT_FILE" ]; then
    cp "$RESULTS" "$OUTPUT_FILE"
    echo -e "${GREEN}✓ Saved to: ${YELLOW}$OUTPUT_FILE${NC}"
    echo ""
fi

echo -e "${BOLD}${GREEN}✅ Done!${NC}"

