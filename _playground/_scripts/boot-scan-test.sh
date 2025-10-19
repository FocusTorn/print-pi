#!/bin/bash
#
# Boot Scanner - Debug Version
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${CYAN}Boot Scanner - Debug Mode${NC}\n"

# Check debsums
if ! command -v debsums &> /dev/null; then
    echo -e "${YELLOW}Installing debsums...${NC}"
    sudo apt-get update -qq && sudo apt-get install -y debsums
fi

# Debug: Check md5sums format
echo -e "${CYAN}Checking md5sums file format...${NC}"
sample_file=$(ls /var/lib/dpkg/info/*.md5sums 2>/dev/null | head -1)
if [ -n "$sample_file" ]; then
    echo -e "${YELLOW}Sample from: $sample_file${NC}"
    head -3 "$sample_file"
    echo ""
fi

# Try different patterns
echo -e "${CYAN}Testing grep patterns for boot files...${NC}"
echo ""

echo -e "${YELLOW}Pattern 1: '^[a-f0-9].*boot/'${NC}"
count1=$(grep -h "^[a-f0-9].*boot/" /var/lib/dpkg/info/*.md5sums 2>/dev/null | wc -l || echo "0")
echo -e "  Found: ${BLUE}$count1${NC} files"

echo -e "${YELLOW}Pattern 2: 'boot/'${NC}"
count2=$(grep -h "boot/" /var/lib/dpkg/info/*.md5sums 2>/dev/null | wc -l || echo "0")
echo -e "  Found: ${BLUE}$count2${NC} files"

echo -e "${YELLOW}Pattern 3: '^\S\+\s\+boot/'${NC}"
count3=$(grep -h "^\S\+\s\+boot/" /var/lib/dpkg/info/*.md5sums 2>/dev/null | wc -l || echo "0")
echo -e "  Found: ${BLUE}$count3${NC} files"

echo ""
echo -e "${CYAN}Using best pattern (should be count2 or count3)${NC}"

boot_files=$count2
echo -e "${GREEN}✓${NC} Found ${BLUE}$boot_files${NC} files in /boot"
echo ""

if [ $boot_files -eq 0 ]; then
    echo -e "${YELLOW}⚠ No boot files found. This might mean:${NC}"
    echo -e "  • Boot files aren't tracked by packages"
    echo -e "  • Files are in /boot/firmware instead"
    echo ""
    
    echo -e "${CYAN}Checking for 'firmware' instead...${NC}"
    firmware_count=$(grep -h "firmware/" /var/lib/dpkg/info/*.md5sums 2>/dev/null | wc -l || echo "0")
    echo -e "  Found: ${BLUE}$firmware_count${NC} firmware files"
    
    if [ $firmware_count -gt 0 ]; then
        echo -e "${GREEN}✓${NC} Using /boot/firmware path instead"
        boot_files=$firmware_count
        BOOT_PATH="/boot/firmware"
    fi
fi

echo ""
echo -e "${CYAN}Now scanning for modified files...${NC}"

RESULTS=$(mktemp)
trap "rm -f $RESULTS" EXIT

# Scan
sudo debsums -c 2>/dev/null | grep -E "^/boot" > "$RESULTS" &
bg_pid=$!

while ps -p $bg_pid > /dev/null 2>&1; do
    count=$(wc -l < "$RESULTS" 2>/dev/null || echo "0")
    printf "\r${CYAN}⟳${NC} Scanning /boot... ${YELLOW}%d${NC} modified found" "$count"
    sleep 0.5
done
wait $bg_pid

count=$(wc -l < "$RESULTS" 2>/dev/null || echo "0")
printf "\r${GREEN}✓${NC} Checked ${BLUE}%d${NC} /boot files - ${YELLOW}%d${NC} modified          \n" "$boot_files" "$count"
echo ""

if [ -s "$RESULTS" ]; then
    echo -e "${BOLD}${RED}Modified Boot Files:${NC}"
    cat "$RESULTS" | while read -r file; do
        pkg=$(dpkg -S "$file" 2>/dev/null | cut -d: -f1 || echo "unknown")
        echo -e "  ${RED}✗${NC} $file ${YELLOW}($pkg)${NC}"
    done
else
    echo -e "${GREEN}✓ No modified boot files!${NC}"
fi

echo ""
echo -e "${BOLD}${GREEN}Done!${NC}"

