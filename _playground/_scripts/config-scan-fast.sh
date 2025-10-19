#!/bin/bash
#
# Fast Config Scanner - Only check packages with /etc and /boot files
#

set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Parse flags
VERBOSE=false
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=true; shift ;;
        -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║           Fast Config File Scanner (/etc + /boot)             ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check debsums
if ! command -v debsums &> /dev/null; then
    echo -e "${YELLOW}Installing debsums...${NC}"
    sudo apt-get update -qq && sudo apt-get install -y debsums
fi

# Find packages with config files
echo -e "${CYAN}Finding packages with config files...${NC}"

PACKAGES=$(mktemp)
trap "rm -f $PACKAGES" EXIT

# Find packages containing /etc or /boot files
for md5file in /var/lib/dpkg/info/*.md5sums; do
    if grep -qE "(etc/|boot/)" "$md5file" 2>/dev/null; then
        pkg=$(basename "$md5file" .md5sums)
        echo "$pkg" >> "$PACKAGES"
    fi
done

pkg_count=$(wc -l < "$PACKAGES" 2>/dev/null || echo "0")
etc_files=$(grep -h "etc/" /var/lib/dpkg/info/*.md5sums 2>/dev/null | wc -l || echo "0")
boot_files=$(grep -h "boot/" /var/lib/dpkg/info/*.md5sums 2>/dev/null | wc -l || echo "0")
total_files=$((etc_files + boot_files))

echo -e "${GREEN}✓${NC} Found ${BLUE}$etc_files${NC} files in /etc"
echo -e "${GREEN}✓${NC} Found ${BLUE}$boot_files${NC} files in /boot"
echo -e "${GREEN}✓${NC} Total: ${BLUE}$total_files${NC} config files in ${BLUE}$pkg_count${NC} packages"
echo ""

if [ $pkg_count -eq 0 ]; then
    echo -e "${YELLOW}No packages contain config files!${NC}"
    exit 0
fi

# Check packages
RESULTS=$(mktemp)
trap "rm -f $PACKAGES $RESULTS" EXIT

echo -e "${CYAN}Checking ${BLUE}$pkg_count${NC} packages...${NC}"
echo ""

checked=0
total=$pkg_count
start_time=$SECONDS

while read pkg; do
    ((checked++))
    
    # Check this package and filter for /etc and /boot
    sudo debsums -c "$pkg" 2>/dev/null | grep -E "^(/etc|/boot)" >> "$RESULTS" || true
    
    # Show progress
    percent=$((checked * 100 / total))
    modified=$(wc -l < "$RESULTS" 2>/dev/null || echo "0")
    etc_mod=$(grep -c "^/etc" "$RESULTS" 2>/dev/null || echo "0")
    boot_mod=$(grep -c "^/boot" "$RESULTS" 2>/dev/null || echo "0")
    elapsed=$((SECONDS - start_time))
    
    printf "\r${CYAN}[%3d%%]${NC} ${BLUE}%4d${NC}/${BLUE}%-4d${NC} pkgs | ${YELLOW}%d${NC} modified (${BLUE}%d${NC} /etc, ${BLUE}%d${NC} /boot) | ${CYAN}%ds${NC}" \
        "$percent" "$checked" "$total" "$modified" "$etc_mod" "$boot_mod" "$elapsed"
done < "$PACKAGES"

echo ""
echo ""

# Results
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}RESULTS${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

modified_count=$(wc -l < "$RESULTS" 2>/dev/null || echo "0")

if [ $modified_count -gt 0 ]; then
    # Group by directory
    etc_results=$(grep "^/etc" "$RESULTS" 2>/dev/null | sort || true)
    boot_results=$(grep "^/boot" "$RESULTS" 2>/dev/null | sort || true)
    
    if [ -n "$etc_results" ]; then
        etc_count=$(echo "$etc_results" | wc -l)
        echo -e "${BOLD}${CYAN}▶ /etc Files (${etc_count} modified)${NC}"
        echo "$etc_results" | while read -r file; do
            pkg=$(dpkg -S "$file" 2>/dev/null | cut -d: -f1 || echo "unknown")
            echo -e "  ${RED}✗${NC} $file ${YELLOW}($pkg)${NC}"
            
            if [ "$VERBOSE" = true ] && [ -f "$file" ]; then
                mtime=$(stat -c "%y" "$file" 2>/dev/null | cut -d. -f1)
                size=$(stat -c "%s" "$file" 2>/dev/null)
                echo -e "      ${YELLOW}Modified:${NC} $mtime  ${YELLOW}Size:${NC} $size bytes"
            fi
        done
        echo ""
    fi
    
    if [ -n "$boot_results" ]; then
        boot_count=$(echo "$boot_results" | wc -l)
        echo -e "${BOLD}${CYAN}▶ /boot Files (${boot_count} modified)${NC}"
        echo "$boot_results" | while read -r file; do
            pkg=$(dpkg -S "$file" 2>/dev/null | cut -d: -f1 || echo "unknown")
            echo -e "  ${RED}✗${NC} $file ${YELLOW}($pkg)${NC}"
            
            if [ "$VERBOSE" = true ] && [ -f "$file" ]; then
                mtime=$(stat -c "%y" "$file" 2>/dev/null | cut -d. -f1)
                echo -e "      ${YELLOW}Modified:${NC} $mtime"
            fi
        done
        echo ""
    fi
else
    echo -e "${GREEN}✓ All ${BLUE}$total_files${NC} config files match their checksums!${NC}"
    echo ""
fi

# Summary
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${YELLOW}SUMMARY${NC}"
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

etc_mod=$(grep -c "^/etc" "$RESULTS" 2>/dev/null || echo "0")
boot_mod=$(grep -c "^/boot" "$RESULTS" 2>/dev/null || echo "0")

echo -e "${CYAN}Total Config Files:${NC} ${BLUE}$total_files${NC} (${BLUE}$etc_files${NC} /etc + ${BLUE}$boot_files${NC} /boot)"
echo -e "${CYAN}Packages Checked:${NC} ${BLUE}$pkg_count${NC}"
echo -e "${CYAN}Modified Files:${NC} ${YELLOW}$modified_count${NC} (${BLUE}$etc_mod${NC} /etc, ${BLUE}$boot_mod${NC} /boot)"
echo -e "${CYAN}Scan Time:${NC} ${BLUE}$(($SECONDS))s${NC}"
echo ""

# Save if requested
if [ -n "$OUTPUT_FILE" ]; then
    {
        echo "Modified Config Files Report"
        echo "Generated: $(date)"
        echo "========================================"
        echo ""
        cat "$RESULTS"
    } > "$OUTPUT_FILE"
    echo -e "${GREEN}✓ Saved to: ${YELLOW}$OUTPUT_FILE${NC}"
    echo ""
fi

echo -e "${BOLD}${GREEN}✅ Done!${NC}"

