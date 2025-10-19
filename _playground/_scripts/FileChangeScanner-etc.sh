#!/bin/bash
#
# FileChangeScanner-etc - Only scan /etc files
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
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Scans /etc files for modifications from package defaults"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Show detailed file info"
            echo "  -o, --output     Save results to file"
            echo "  -h, --help       Show this help"
            exit 0
            ;;
        *) shift ;;
    esac
done

echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║           FileChangeScanner - /etc Directory                  ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check debsums
if ! command -v debsums &> /dev/null; then
    echo -e "${YELLOW}Installing debsums...${NC}"
    sudo apt-get update -qq && sudo apt-get install -y debsums
fi

# Find packages with /etc files
echo -e "${CYAN}Finding packages with /etc files...${NC}"

PACKAGES=$(mktemp)
RESULTS=$(mktemp)
trap "rm -f $PACKAGES $RESULTS" EXIT

# Find packages containing /etc files
for md5file in /var/lib/dpkg/info/*.md5sums; do
    if grep -q "etc/" "$md5file" 2>/dev/null; then
        pkg=$(basename "$md5file" .md5sums)
        echo "$pkg" >> "$PACKAGES"
    fi
done

pkg_count=$(wc -l < "$PACKAGES" 2>/dev/null || echo "0")
etc_files=$(grep -h "etc/" /var/lib/dpkg/info/*.md5sums 2>/dev/null | wc -l || echo "0")

echo -e "${GREEN}✓${NC} Found ${BLUE}$etc_files${NC} files in /etc across ${BLUE}$pkg_count${NC} packages"
echo ""

if [ $pkg_count -eq 0 ]; then
    echo -e "${YELLOW}No packages contain /etc files!${NC}"
    exit 0
fi

# Check packages
echo -e "${CYAN}Checking ${BLUE}$pkg_count${NC} packages...${NC}"
echo ""

checked=0
total=$pkg_count
start_time=$SECONDS

while read pkg; do
    ((checked++))
    
    # Check this package and filter for /etc only
    sudo debsums -c "$pkg" 2>/dev/null | grep "^/etc" >> "$RESULTS" || true
    
    # Show progress
    percent=$((checked * 100 / total))
    modified=$(wc -l < "$RESULTS" 2>/dev/null || echo "0")
    elapsed=$((SECONDS - start_time))
    
    # Calculate estimated time remaining
    if [ $checked -gt 0 ]; then
        rate=$((elapsed / checked))
        remaining=$((rate * (total - checked)))
        eta="${remaining}s"
    else
        eta="calculating..."
    fi
    
    printf "\r${CYAN}[%3d%%]${NC} ${BLUE}%4d${NC}/${BLUE}%-4d${NC} packages | ${YELLOW}%d${NC} modified | ${CYAN}%ds${NC} elapsed | ETA: ${CYAN}%s${NC}   " \
        "$percent" "$checked" "$total" "$modified" "$elapsed" "$eta"
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
    # Group by subdirectory
    declare -A etc_dirs
    
    # Categorize by /etc subdirectory
    while read -r file; do
        subdir=$(echo "$file" | cut -d/ -f1-3)  # Get /etc/subdir
        if [ -z "${etc_dirs[$subdir]}" ]; then
            etc_dirs[$subdir]="$file"
        else
            etc_dirs[$subdir]="${etc_dirs[$subdir]}"$'\n'"$file"
        fi
    done < "$RESULTS"
    
    # Display by category
    for subdir in "${!etc_dirs[@]}"; do
        files="${etc_dirs[$subdir]}"
        count=$(echo "$files" | wc -l)
        
        echo -e "${BOLD}${CYAN}▶ $subdir/ (${count} files)${NC}"
        echo "$files" | while read -r file; do
            pkg=$(dpkg -S "$file" 2>/dev/null | cut -d: -f1 || echo "unknown")
            echo -e "  ${RED}✗${NC} $file ${YELLOW}($pkg)${NC}"
            
            if [ "$VERBOSE" = true ] && [ -f "$file" ]; then
                mtime=$(stat -c "%y" "$file" 2>/dev/null | cut -d. -f1)
                size=$(stat -c "%s" "$file" 2>/dev/null)
                owner=$(stat -c "%U:%G" "$file" 2>/dev/null)
                perms=$(stat -c "%a" "$file" 2>/dev/null)
                echo -e "      ${YELLOW}Modified:${NC} $mtime"
                echo -e "      ${YELLOW}Size:${NC} $size bytes  ${YELLOW}Owner:${NC} $owner  ${YELLOW}Perms:${NC} $perms"
            fi
        done
        echo ""
    done
else
    echo -e "${GREEN}✓ All ${BLUE}$etc_files${NC} /etc files match their checksums!${NC}"
    echo ""
fi

# Summary
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${YELLOW}SUMMARY${NC}"
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CYAN}Total /etc Files:${NC} ${BLUE}$etc_files${NC}"
echo -e "${CYAN}Packages Checked:${NC} ${BLUE}$pkg_count${NC}"
echo -e "${CYAN}Modified Files:${NC} ${YELLOW}$modified_count${NC}"
echo -e "${CYAN}Scan Time:${NC} ${BLUE}$(($SECONDS))s${NC}"
echo ""

if [ $modified_count -gt 0 ]; then
    echo -e "${BOLD}${CYAN}💡 RECOMMENDATIONS:${NC}"
    echo -e "${CYAN}• Review each modified file to determine if changes are intentional${NC}"
    echo -e "${CYAN}• Track important customizations: ${YELLOW}system-track add <file>${NC}"
    echo -e "${CYAN}• Consider adding to overlay system if part of 3DP setup${NC}"
    echo ""
fi

# Save if requested
if [ -n "$OUTPUT_FILE" ]; then
    {
        echo "Modified /etc Files Report"
        echo "Generated: $(date)"
        echo "Total /etc Files: $etc_files"
        echo "Packages Checked: $pkg_count"
        echo "Modified: $modified_count"
        echo "Scan Time: $(($SECONDS))s"
        echo "========================================"
        echo ""
        cat "$RESULTS"
    } > "$OUTPUT_FILE"
    echo -e "${GREEN}✓ Report saved to: ${YELLOW}$OUTPUT_FILE${NC}"
    echo ""
fi

# Cross-reference with system-tracker
if [ -f /home/pi/.user-scripts/system-tracker ] && [ $modified_count -gt 0 ]; then
    if [ -f /home/pi/3dp-mods/.system-track-list ]; then
        tracked=0
        untracked=0
        
        while read -r file; do
            if grep -q "^$file$" /home/pi/3dp-mods/.system-track-list 2>/dev/null; then
                ((tracked++))
            else
                ((untracked++))
            fi
        done < "$RESULTS"
        
        echo -e "${BOLD}${BLUE}🔍 System-Tracker Status:${NC}"
        echo -e "${GREEN}  ✓${NC} Tracked: ${YELLOW}$tracked${NC} files"
        echo -e "${RED}  ✗${NC} Untracked: ${YELLOW}$untracked${NC} files"
        echo ""
    fi
fi

echo -e "${BOLD}${GREEN}✅ Scan Complete!${NC}"

