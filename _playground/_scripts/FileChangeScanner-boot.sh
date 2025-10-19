#!/bin/bash
#
# Fast Boot Scanner - Only check packages with boot files
#

set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${CYAN}Fast Boot Scanner${NC}\n"

# Check debsums
if ! command -v debsums &> /dev/null; then
    echo -e "${YELLOW}Installing debsums...${NC}"
    sudo apt-get update -qq && sudo apt-get install -y debsums
fi

# Find packages that contain boot files
echo -e "${CYAN}Finding packages with boot files...${NC}"

BOOT_PACKAGES=$(mktemp)
trap "rm -f $BOOT_PACKAGES" EXIT

# Search md5sums for boot files and extract package names
for md5file in /var/lib/dpkg/info/*.md5sums; do
    if grep -q "boot/" "$md5file" 2>/dev/null; then
        pkg=$(basename "$md5file" .md5sums)
        echo "$pkg" >> "$BOOT_PACKAGES"
    fi
done

pkg_count=$(wc -l < "$BOOT_PACKAGES" 2>/dev/null || echo "0")
boot_files=$(grep -h "boot/" /var/lib/dpkg/info/*.md5sums 2>/dev/null | wc -l || echo "0")

echo -e "${GREEN}✓${NC} Found ${BLUE}$boot_files${NC} boot files in ${BLUE}$pkg_count${NC} packages"
echo ""

if [ $pkg_count -eq 0 ]; then
    echo -e "${YELLOW}No packages contain boot files!${NC}"
    exit 0
fi

# Show which packages we'll check
echo -e "${CYAN}Packages to check:${NC}"
cat "$BOOT_PACKAGES" | while read pkg; do
    echo "  • $pkg"
done
echo ""

# Now check only those packages
RESULTS=$(mktemp)
trap "rm -f $BOOT_PACKAGES $RESULTS" EXIT

echo -e "${CYAN}Checking ${BLUE}$pkg_count${NC} packages for modifications...${NC}"

checked=0
total=$pkg_count

while read pkg; do
    ((checked++))
    
    # Check this package
    sudo debsums -c "$pkg" 2>/dev/null | grep "^/boot" >> "$RESULTS" || true
    
    # Show progress
    percent=$((checked * 100 / total))
    modified=$(wc -l < "$RESULTS" 2>/dev/null || echo "0")
    printf "\r${CYAN}[%3d%%]${NC} ${BLUE}%d${NC}/${BLUE}%d${NC} packages - ${YELLOW}%d${NC} modified files found" "$percent" "$checked" "$total" "$modified"
done < "$BOOT_PACKAGES"

echo ""
echo ""

# Show results
modified_count=$(wc -l < "$RESULTS" 2>/dev/null || echo "0")

if [ $modified_count -gt 0 ]; then
    echo -e "${BOLD}${RED}Modified Boot Files:${NC}"
    cat "$RESULTS" | while read -r file; do
        pkg=$(dpkg -S "$file" 2>/dev/null | cut -d: -f1 || echo "unknown")
        mtime=$(stat -c "%y" "$file" 2>/dev/null | cut -d. -f1 || echo "unknown")
        echo -e "  ${RED}✗${NC} $file"
        echo -e "      ${YELLOW}Package:${NC} $pkg"
        echo -e "      ${YELLOW}Modified:${NC} $mtime"
    done
else
    echo -e "${GREEN}✓ All ${BLUE}$boot_files${NC} boot files match their checksums!${NC}"
fi

echo ""
echo -e "${BOLD}${GREEN}Done! Checked ${BLUE}$pkg_count${NC} packages in $(($SECONDS))s${NC}"

